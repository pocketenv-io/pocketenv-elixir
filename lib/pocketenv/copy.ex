defmodule Pocketenv.Copy do
  @moduledoc false
  # Handles file and directory transfers between local paths and sandboxes,
  # and between sandboxes. Not part of the public API — use Sandbox.upload/4,
  # Sandbox.download/4, and Sandbox.copy_to/5 instead.

  alias Pocketenv.{API, Client}

  @default_storage_url "https://sandbox.pocketenv.io"

  def storage_url do
    Application.get_env(:pocketenv_ex, :storage_url) ||
      System.get_env("POCKETENV_STORAGE_URL") ||
      @default_storage_url
  end

  # ---------------------------------------------------------------------------
  # Public operations
  # ---------------------------------------------------------------------------

  @doc """
  Compress `local_path` and upload it to `sandbox_path` inside the sandbox.
  """
  def upload(sandbox_id, local_path, sandbox_path, opts \\ []) do
    case compress(local_path) do
      {:ok, archive} ->
        result =
          with {:ok, uuid} <- upload_to_storage(archive, opts),
               {:ok, _} <- API.pull_directory(sandbox_id, uuid, sandbox_path, opts) do
            :ok
          end

        File.rm(archive)
        result

      {:error, _} = err ->
        err
    end
  end

  @doc """
  Push `sandbox_path` from the sandbox to storage, download it, and extract to
  `local_path`.
  """
  def download(sandbox_id, sandbox_path, local_path, opts \\ []) do
    archive = temp_path()

    result =
      with {:ok, uuid} <- API.push_directory(sandbox_id, sandbox_path, opts),
           :ok <- download_from_storage(uuid, archive, opts),
           :ok <- decompress(archive, local_path) do
        :ok
      end

    File.rm(archive)
    result
  end

  @doc """
  Push `src_path` from `src_sandbox_id` to storage, then pull it into
  `dest_path` inside `dest_sandbox_id`. No local I/O involved.
  """
  def to(src_sandbox_id, dest_sandbox_id, src_path, dest_path, opts \\ []) do
    with {:ok, uuid} <- API.push_directory(src_sandbox_id, src_path, opts),
         {:ok, _} <- API.pull_directory(dest_sandbox_id, uuid, dest_path, opts) do
      :ok
    end
  end

  # ---------------------------------------------------------------------------
  # Compression helpers
  # ---------------------------------------------------------------------------

  defp compress(source) do
    hash = :crypto.hash(:sha256, source) |> Base.encode16(case: :lower)
    archive = Path.join(System.tmp_dir!(), "#{hash}.tar.gz")

    entries =
      case File.lstat!(source) do
        %{type: :regular} ->
          [{String.to_charlist(Path.basename(source)), File.read!(source)}]

        %{type: :directory} ->
          contexts = Pocketenv.Ignore.load(source)

          walk_dir(source, "")
          |> Enum.reject(fn rel -> Pocketenv.Ignore.ignored?(contexts, rel) end)
          |> Enum.map(fn rel ->
            {String.to_charlist(rel), File.read!(Path.join(source, rel))}
          end)
      end

    case :erl_tar.create(String.to_charlist(archive), entries, [:compressed]) do
      :ok -> {:ok, archive}
      {:error, reason} -> {:error, reason}
    end
  end

  # Recursively lists all regular files under `base`, returning paths relative
  # to `base`. Symbolic links and other special files are skipped.
  defp walk_dir(base, prefix) do
    dir = if prefix == "", do: base, else: Path.join(base, prefix)

    dir
    |> File.ls!()
    |> Enum.flat_map(fn entry ->
      rel = if prefix == "", do: entry, else: Path.join(prefix, entry)
      full = Path.join(base, rel)

      case File.lstat!(full).type do
        :regular -> [rel]
        :directory -> walk_dir(base, rel)
        _ -> []
      end
    end)
  end

  defp decompress(archive, dest) do
    File.mkdir_p!(dest)

    case :erl_tar.extract(String.to_charlist(archive), [
           :compressed,
           {:cwd, String.to_charlist(dest)}
         ]) do
      :ok -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  defp temp_path do
    hex = :crypto.strong_rand_bytes(16) |> Base.encode16(case: :lower)
    Path.join(System.tmp_dir!(), "#{hex}.tar.gz")
  end

  # ---------------------------------------------------------------------------
  # Storage HTTP helpers
  # ---------------------------------------------------------------------------

  defp upload_to_storage(file_path, opts) do
    with {:ok, token} <- resolve_token(opts),
         {:ok, binary} <- File.read(file_path) do
      {body, content_type} = build_multipart("file", binary, "archive.tar.gz", "application/gzip")
      url = storage_url() <> "/cp"

      case Req.post(url,
             body: body,
             headers: [
               {"authorization", "Bearer #{token}"},
               {"content-type", content_type}
             ]
           ) do
        {:ok, %{status: status, body: %{"uuid" => uuid}}} when status in 200..299 ->
          {:ok, uuid}

        {:ok, %{status: status, body: body}} ->
          {:error, %{status: status, body: body}}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  defp download_from_storage(uuid, dest_file, opts) do
    with {:ok, token} <- resolve_token(opts) do
      url = storage_url() <> "/cp/#{uuid}"

      case Req.get(url,
             decode_body: false,
             headers: [{"authorization", "Bearer #{token}"}]
           ) do
        {:ok, %{status: status, body: body}} when status in 200..299 ->
          File.write(dest_file, body)

        {:ok, %{status: status, body: body}} ->
          {:error, %{status: status, body: body}}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  defp resolve_token(opts) do
    case Keyword.fetch(opts, :token) do
      {:ok, token} -> {:ok, token}
      :error -> Client.token()
    end
  end

  defp build_multipart(name, binary, filename, content_type) do
    boundary = "FormBoundary" <> Base.encode16(:crypto.strong_rand_bytes(8))

    body =
      IO.iodata_to_binary([
        "--",
        boundary,
        "\r\n",
        "Content-Disposition: form-data; name=\"",
        name,
        "\"; filename=\"",
        filename,
        "\"\r\n",
        "Content-Type: ",
        content_type,
        "\r\n",
        "\r\n",
        binary,
        "\r\n",
        "--",
        boundary,
        "--\r\n"
      ])

    {body, "multipart/form-data; boundary=#{boundary}"}
  end
end
