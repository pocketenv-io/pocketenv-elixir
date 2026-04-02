defmodule Pocketenv.API do
  @moduledoc false
  # Internal HTTP layer. Consumers should use the `Pocketenv` module and
  # pipe on `%Sandbox{}` structs. This module is not part of the public API.

  alias Pocketenv.Client
  alias Pocketenv.Crypto
  alias Sandbox.Types.{ExecResult, Port, Profile, Secret, SshKey, TailscaleAuthKey}

  @default_base "at://did:plc:aturpi2ls3yvsmhc6wybomun/io.pocketenv.sandbox/openclaw"

  # ---------------------------------------------------------------------------
  # Sandbox CRUD
  # ---------------------------------------------------------------------------

  def create_sandbox(name, opts \\ []) do
    body =
      %{
        "name" => name,
        "base" => Keyword.get(opts, :base, @default_base),
        "provider" => opts |> Keyword.get(:provider, :cloudflare) |> to_string()
      }
      |> maybe_put("repo", Keyword.get(opts, :repo))
      |> maybe_put("keepAlive", Keyword.get(opts, :keep_alive))

    case Client.post("/xrpc/io.pocketenv.sandbox.createSandbox", body, take_token(opts)) do
      {:ok, data} -> {:ok, Sandbox.from_map(data)}
      {:error, _} = err -> err
    end
  end

  def start_sandbox(id, opts \\ []) do
    body =
      %{}
      |> maybe_put("repo", Keyword.get(opts, :repo))
      |> maybe_put("keepAlive", Keyword.get(opts, :keep_alive))

    Client.post(
      "/xrpc/io.pocketenv.sandbox.startSandbox",
      body,
      take_token(opts) ++ [params: %{"id" => id}]
    )
  end

  def stop_sandbox(id, opts \\ []) do
    Client.post(
      "/xrpc/io.pocketenv.sandbox.stopSandbox",
      nil,
      take_token(opts) ++ [params: %{"id" => id}]
    )
  end

  def delete_sandbox(id, opts \\ []) do
    Client.post(
      "/xrpc/io.pocketenv.sandbox.deleteSandbox",
      nil,
      take_token(opts) ++ [params: %{"id" => id}]
    )
  end

  # ---------------------------------------------------------------------------
  # Sandbox queries
  # ---------------------------------------------------------------------------

  def get_sandbox(id, opts \\ []) do
    case Client.get(
           "/xrpc/io.pocketenv.sandbox.getSandbox",
           take_token(opts) ++ [params: %{"id" => id}]
         ) do
      {:ok, %{"sandbox" => nil}} -> {:ok, nil}
      {:ok, %{"sandbox" => data}} -> {:ok, Sandbox.from_map(data)}
      {:ok, data} when is_map(data) -> {:ok, Sandbox.from_map(data)}
      {:error, _} = err -> err
    end
  end

  def list_sandboxes(opts \\ []) do
    params = %{
      "limit" => Keyword.get(opts, :limit, 30),
      "offset" => Keyword.get(opts, :offset, 0)
    }

    case Client.get(
           "/xrpc/io.pocketenv.sandbox.getSandboxes",
           take_token(opts) ++ [params: params]
         ) do
      {:ok, %{"sandboxes" => items, "total" => total}} ->
        {:ok, {Enum.map(items, &Sandbox.from_map/1), total}}

      {:error, _} = err ->
        err
    end
  end

  def list_sandboxes_by_actor(did, opts \\ []) do
    params = %{
      "did" => did,
      "limit" => Keyword.get(opts, :limit, 30),
      "offset" => Keyword.get(opts, :offset, 0)
    }

    case Client.get(
           "/xrpc/io.pocketenv.actor.getActorSandboxes",
           take_token(opts) ++ [params: params]
         ) do
      {:ok, %{"sandboxes" => items, "total" => total}} ->
        {:ok, {Enum.map(items, &Sandbox.from_map/1), total}}

      {:error, _} = err ->
        err
    end
  end

  def wait_until_running(id, opts \\ []) do
    timeout_ms = Keyword.get(opts, :timeout_ms, 60_000)
    interval_ms = Keyword.get(opts, :interval_ms, 2_000)
    deadline = System.monotonic_time(:millisecond) + timeout_ms
    do_wait(id, opts, deadline, interval_ms)
  end

  # ---------------------------------------------------------------------------
  # Exec
  # ---------------------------------------------------------------------------

  def exec(id, cmd, args \\ [], opts \\ []) do
    command = Enum.join([cmd | args], " ")

    case Client.post(
           "/xrpc/io.pocketenv.sandbox.exec",
           %{"command" => command},
           take_token(opts) ++ [params: %{"id" => id}]
         ) do
      {:ok, data} -> {:ok, ExecResult.from_map(data)}
      {:error, _} = err -> err
    end
  end

  # ---------------------------------------------------------------------------
  # Ports
  # ---------------------------------------------------------------------------

  def expose_port(id, port, opts \\ []) do
    body =
      %{"port" => port}
      |> maybe_put("description", Keyword.get(opts, :description))

    case Client.post(
           "/xrpc/io.pocketenv.sandbox.exposePort",
           body,
           take_token(opts) ++ [params: %{"id" => id}]
         ) do
      {:ok, %{"previewUrl" => url}} -> {:ok, url}
      {:ok, _} -> {:ok, nil}
      {:error, _} = err -> err
    end
  end

  def unexpose_port(id, port, opts \\ []) do
    Client.post(
      "/xrpc/io.pocketenv.sandbox.unexposePort",
      %{"port" => port},
      take_token(opts) ++ [params: %{"id" => id}]
    )
  end

  def list_ports(id, opts \\ []) do
    case Client.get(
           "/xrpc/io.pocketenv.sandbox.getExposedPorts",
           take_token(opts) ++ [params: %{"id" => id}]
         ) do
      {:ok, %{"ports" => ports}} -> {:ok, Enum.map(ports, &Port.from_map/1)}
      {:error, _} = err -> err
    end
  end

  # ---------------------------------------------------------------------------
  # VS Code
  # ---------------------------------------------------------------------------

  def expose_vscode(id, opts \\ []) do
    case Client.post(
           "/xrpc/io.pocketenv.sandbox.exposeVscode",
           nil,
           take_token(opts) ++ [params: %{"id" => id}]
         ) do
      {:ok, %{"previewUrl" => url}} -> {:ok, url}
      {:ok, _} -> {:ok, nil}
      {:error, _} = err -> err
    end
  end

  # ---------------------------------------------------------------------------
  # Actor / profile
  # ---------------------------------------------------------------------------

  def me(opts \\ []) do
    case Client.get("/xrpc/io.pocketenv.actor.getProfile", take_token(opts)) do
      {:ok, data} -> {:ok, Profile.from_map(data)}
      {:error, _} = err -> err
    end
  end

  def get_profile(did, opts \\ []) do
    case Client.get(
           "/xrpc/io.pocketenv.actor.getProfile",
           take_token(opts) ++ [params: %{"did" => did}]
         ) do
      {:ok, data} -> {:ok, Profile.from_map(data)}
      {:error, _} = err -> err
    end
  end

  # ---------------------------------------------------------------------------
  # Secrets
  # ---------------------------------------------------------------------------

  def list_secrets(sandbox_id, opts \\ []) do
    params = %{
      "sandboxId" => sandbox_id,
      "offset" => Keyword.get(opts, :offset, 0),
      "limit" => Keyword.get(opts, :limit, 100)
    }

    case Client.get(
           "/xrpc/io.pocketenv.secret.getSecrets",
           take_token(opts) ++ [params: params]
         ) do
      {:ok, %{"secrets" => items}} -> {:ok, Enum.map(items, &Secret.from_map/1)}
      {:error, _} = err -> err
    end
  end

  def add_secret(sandbox_id, name, value, opts \\ []) do
    {:ok, encrypted} = Crypto.encrypt(value)

    Client.post(
      "/xrpc/io.pocketenv.secret.addSecret",
      %{"secret" => %{"sandboxId" => sandbox_id, "name" => name, "value" => encrypted}},
      take_token(opts)
    )
  end

  def delete_secret(id, opts \\ []) do
    Client.post(
      "/xrpc/io.pocketenv.secret.deleteSecret",
      nil,
      take_token(opts) ++ [params: %{"id" => id}]
    )
  end

  # ---------------------------------------------------------------------------
  # SSH Keys
  # ---------------------------------------------------------------------------

  def get_ssh_keys(sandbox_id, opts \\ []) do
    case Client.get(
           "/xrpc/io.pocketenv.sandbox.getSshKeys",
           take_token(opts) ++ [params: %{"id" => sandbox_id}]
         ) do
      {:ok, data} -> {:ok, SshKey.from_map(data)}
      {:error, _} = err -> err
    end
  end

  def put_ssh_keys(sandbox_id, private_key, public_key, opts \\ []) do
    {:ok, encrypted_private_key} = Crypto.encrypt(private_key)
    redacted = redact_ssh_private_key(private_key)

    Client.post(
      "/xrpc/io.pocketenv.sandbox.putSshKeys",
      %{
        "id" => sandbox_id,
        "privateKey" => encrypted_private_key,
        "publicKey" => public_key,
        "redacted" => redacted
      },
      take_token(opts)
    )
  end

  # ---------------------------------------------------------------------------
  # Tailscale
  # ---------------------------------------------------------------------------

  def get_tailscale_auth_key(sandbox_id, opts \\ []) do
    case Client.get(
           "/xrpc/io.pocketenv.sandbox.getTailscaleAuthKey",
           take_token(opts) ++ [params: %{"id" => sandbox_id}]
         ) do
      {:ok, data} -> {:ok, TailscaleAuthKey.from_map(data)}
      {:error, _} = err -> err
    end
  end

  def put_tailscale_auth_key(sandbox_id, auth_key, opts \\ []) do
    unless String.starts_with?(auth_key, "tskey-auth-") do
      raise ArgumentError, "Tailscale auth key must start with \"tskey-auth-\""
    end

    {:ok, encrypted} = Crypto.encrypt(auth_key)
    redacted = redact_tailscale_key(auth_key)

    Client.post(
      "/xrpc/io.pocketenv.sandbox.putTailscaleAuthKey",
      %{"id" => sandbox_id, "authKey" => encrypted, "redacted" => redacted},
      take_token(opts)
    )
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp redact_ssh_private_key(private_key) do
    header = "-----BEGIN OPENSSH PRIVATE KEY-----"
    footer = "-----END OPENSSH PRIVATE KEY-----"

    case {String.contains?(private_key, header), String.contains?(private_key, footer)} do
      {true, true} ->
        header_end = :binary.match(private_key, header) |> elem(0)
        body_start = header_end + byte_size(header)
        footer_start = :binary.match(private_key, footer) |> elem(0)
        body = binary_part(private_key, body_start, footer_start - body_start)

        chars = String.graphemes(body)

        non_newline_indices =
          chars
          |> Enum.with_index()
          |> Enum.filter(fn {c, _i} -> c != "\n" end)
          |> Enum.map(fn {_c, i} -> i end)

        masked_chars =
          if length(non_newline_indices) > 15 do
            middle_indices = Enum.slice(non_newline_indices, 10, length(non_newline_indices) - 15)
            mask_set = MapSet.new(middle_indices)

            chars
            |> Enum.with_index()
            |> Enum.map(fn {c, i} -> if MapSet.member?(mask_set, i), do: "*", else: c end)
          else
            chars
          end

        masked_body = Enum.join(masked_chars)

        "#{header}#{masked_body}#{footer}"
        |> String.replace("\n", "\\n")

      _ ->
        String.replace(private_key, "\n", "\\n")
    end
  end

  defp redact_tailscale_key(auth_key) when byte_size(auth_key) > 14 do
    String.slice(auth_key, 0, 11) <>
      String.duplicate("*", byte_size(auth_key) - 14) <>
      String.slice(auth_key, -3, 3)
  end

  defp redact_tailscale_key(auth_key), do: auth_key

  defp do_wait(id, opts, deadline, interval_ms) do
    if System.monotonic_time(:millisecond) >= deadline do
      {:error, :timeout}
    else
      case get_sandbox(id, opts) do
        {:ok, %Sandbox{status: :running} = sandbox} ->
          {:ok, sandbox}

        {:ok, _} ->
          Process.sleep(interval_ms)
          do_wait(id, opts, deadline, interval_ms)

        {:error, _} = err ->
          err
      end
    end
  end

  defp take_token(opts) do
    case Keyword.fetch(opts, :token) do
      {:ok, token} -> [token: token]
      :error -> []
    end
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
