defmodule Sandbox do
  @moduledoc """
  Represents a Pocketenv sandbox environment.

  `%Sandbox{}` is the central type of the SDK. You get one back from
  `Pocketenv.create_sandbox/2` or `Pocketenv.get_sandbox/2`, and then
  pipe operations directly on it:

      {:ok, sandbox} =
        Pocketenv.create_sandbox("my-sandbox")
        |> Sandbox.start()
        |> Sandbox.wait_until_running()

      {:ok, result} = sandbox |> Sandbox.exec("mix", ["test"])
      IO.puts(result.stdout)

      {:ok, url} = sandbox |> Sandbox.expose(3000)

      sandbox
      |> Sandbox.stop()
      |> Sandbox.delete()

  ## Pipe safety

  Every function accepts either a bare `%Sandbox{}` **or** an
  `{:ok, %Sandbox{}}` tuple as its first argument, so you can pipe from
  any previous step without manually unwrapping the result.

  An `{:error, reason}` value is never silently swallowed — passing one
  raises `FunctionClauseError`, keeping error handling explicit.
  """

  alias Pocketenv.API
  alias Sandbox.Types.{ExecResult, Port, Profile, Secret, SshKey, TailscaleAuthKey}

  @type status :: :running | :stopped | :unknown

  @type t :: %__MODULE__{
          id: String.t() | nil,
          name: String.t() | nil,
          provider: String.t() | nil,
          base_sandbox: String.t() | nil,
          display_name: String.t() | nil,
          uri: String.t() | nil,
          description: String.t() | nil,
          topics: [String.t()] | nil,
          logo: String.t() | nil,
          readme: String.t() | nil,
          repo: String.t() | nil,
          vcpus: integer() | nil,
          memory: integer() | nil,
          disk: integer() | nil,
          installs: integer(),
          status: status(),
          started_at: String.t() | nil,
          created_at: String.t() | nil,
          owner: Profile.t() | nil
        }

  defstruct [
    :id,
    :name,
    :provider,
    :base_sandbox,
    :display_name,
    :uri,
    :description,
    :topics,
    :logo,
    :readme,
    :repo,
    :vcpus,
    :memory,
    :disk,
    :installs,
    :status,
    :started_at,
    :created_at,
    :owner
  ]

  @doc false
  @spec from_map(map()) :: t()
  def from_map(map) when is_map(map) do
    %__MODULE__{
      id: map["id"],
      name: map["name"],
      provider: map["provider"],
      base_sandbox: map["baseSandbox"],
      display_name: map["displayName"],
      uri: map["uri"],
      description: map["description"],
      topics: map["topics"],
      logo: map["logo"],
      readme: map["readme"],
      repo: map["repo"],
      vcpus: map["vcpus"],
      memory: map["memory"],
      disk: map["disk"],
      installs: map["installs"] || 0,
      status: parse_status(map["status"]),
      started_at: map["startedAt"],
      created_at: map["createdAt"],
      owner: map["owner"] && Profile.from_map(map["owner"])
    }
  end

  # ---------------------------------------------------------------------------
  # Lifecycle
  # ---------------------------------------------------------------------------

  @doc """
  Starts the sandbox.

  Re-fetches the sandbox after the API call so the returned struct always
  reflects the latest state.

  ## Options

    - `:repo`       — clone a GitHub repo into the sandbox on start.
    - `:keep_alive` — keep the sandbox alive after the session ends.
    - `:token`      — bearer token override.

  ## Example

      sandbox |> Sandbox.start()
      sandbox |> Sandbox.start(repo: "github.com/me/app")
      Pocketenv.get_sandbox("my-sandbox") |> Sandbox.start()
  """
  @spec start(t() | {:ok, t()}, keyword()) :: {:ok, t()} | {:error, term()}
  def start(sandbox_or_result, opts \\ [])
  def start({:ok, %__MODULE__{} = sandbox}, opts), do: start(sandbox, opts)

  def start(%__MODULE__{} = sandbox, opts) do
    with {:ok, _} <- API.start_sandbox(sandbox.name, opts) do
      API.get_sandbox(sandbox.name, opts)
    end
  end

  @doc """
  Stops the sandbox.

  Re-fetches the sandbox after the API call so the returned struct always
  reflects the latest state.

  ## Options

    - `:token` — bearer token override.

  ## Example

      sandbox |> Sandbox.stop()
      Pocketenv.get_sandbox("my-sandbox") |> Sandbox.stop()
  """
  @spec stop(t() | {:ok, t()}, keyword()) :: {:ok, t()} | {:error, term()}
  def stop(sandbox_or_result, opts \\ [])
  def stop({:ok, %__MODULE__{} = sandbox}, opts), do: stop(sandbox, opts)

  def stop(%__MODULE__{} = sandbox, opts) do
    with {:ok, _} <- API.stop_sandbox(sandbox.name, opts) do
      API.get_sandbox(sandbox.name, opts)
    end
  end

  @doc """
  Deletes the sandbox permanently.

  Returns `{:ok, %Sandbox{}}` with the last known state — the sandbox
  will no longer be fetchable after this call.

  ## Options

    - `:token` — bearer token override.

  ## Example

      sandbox |> Sandbox.delete()
      sandbox |> Sandbox.stop() |> Sandbox.delete()
  """
  @spec delete(t() | {:ok, t()}, keyword()) :: {:ok, t()} | {:error, term()}
  def delete(sandbox_or_result, opts \\ [])
  def delete({:ok, %__MODULE__{} = sandbox}, opts), do: delete(sandbox, opts)

  def delete(%__MODULE__{} = sandbox, opts) do
    with {:ok, _} <- API.delete_sandbox(sandbox.name, opts) do
      {:ok, sandbox}
    end
  end

  @doc """
  Polls until the sandbox status becomes `:running`, then returns the
  refreshed `%Sandbox{}`.

  Useful after `start/2` when you need the sandbox to be fully ready
  before running commands.

  ## Options

    - `:timeout_ms`  — total wait time in ms (default: `60_000`).
    - `:interval_ms` — polling interval in ms (default: `2_000`).
    - `:token`       — bearer token override.

  ## Returns

    - `{:ok, %Sandbox{status: :running}}` on success.
    - `{:error, :timeout}` if the deadline is exceeded.

  ## Example

      sandbox
      |> Sandbox.start()
      |> Sandbox.wait_until_running()
      |> Sandbox.exec("mix", ["test"])
  """
  @spec wait_until_running(t() | {:ok, t()}, keyword()) ::
          {:ok, t()} | {:error, :timeout | term()}
  def wait_until_running(sandbox_or_result, opts \\ [])

  def wait_until_running({:ok, %__MODULE__{} = sandbox}, opts),
    do: wait_until_running(sandbox, opts)

  def wait_until_running(%__MODULE__{} = sandbox, opts) do
    API.wait_until_running(sandbox.name, opts)
  end

  # ---------------------------------------------------------------------------
  # Commands
  # ---------------------------------------------------------------------------

  @doc """
  Executes a shell command inside the sandbox.

  ## Parameters

    - `cmd`  — the executable (e.g. `"mix"`, `"echo"`).
    - `args` — list of string arguments (default: `[]`).

  ## Options

    - `:token` — bearer token override.

  ## Returns

    `{:ok, %Sandbox.Types.ExecResult{stdout, stderr, exit_code}}`

  ## Example

      sandbox |> Sandbox.exec("echo", ["hello"])
      sandbox |> Sandbox.exec("mix", ["test", "--trace"])
  """
  @spec exec(t() | {:ok, t()}, String.t(), [String.t()], keyword()) ::
          {:ok, ExecResult.t()} | {:error, term()}
  def exec(sandbox_or_result, cmd, args \\ [], opts \\ [])
  def exec({:ok, %__MODULE__{} = sandbox}, cmd, args, opts), do: exec(sandbox, cmd, args, opts)

  def exec(%__MODULE__{} = sandbox, cmd, args, opts) do
    API.exec(sandbox.name, cmd, args, opts)
  end

  # ---------------------------------------------------------------------------
  # Ports
  # ---------------------------------------------------------------------------

  @doc """
  Exposes a port on the sandbox so it is publicly accessible.

  ## Options

    - `:description` — a human-readable label for the port.
    - `:token`       — bearer token override.

  ## Returns

    `{:ok, preview_url}` — `preview_url` is `nil` when the provider does
    not return one.

  ## Example

      sandbox |> Sandbox.expose(3000)
      sandbox |> Sandbox.expose(8080, description: "API server")
  """
  @spec expose(t() | {:ok, t()}, pos_integer(), keyword()) ::
          {:ok, String.t() | nil} | {:error, term()}
  def expose(sandbox_or_result, port, opts \\ [])
  def expose({:ok, %__MODULE__{} = sandbox}, port, opts), do: expose(sandbox, port, opts)

  def expose(%__MODULE__{} = sandbox, port, opts) do
    API.expose_port(sandbox.name, port, opts)
  end

  @doc """
  Removes an exposed port from the sandbox.

  Returns `{:ok, %Sandbox{}}` (same struct passed in) so the pipe can
  continue.

  ## Options

    - `:token` — bearer token override.

  ## Example

      sandbox |> Sandbox.unexpose(3000)
  """
  @spec unexpose(t() | {:ok, t()}, pos_integer(), keyword()) ::
          {:ok, t()} | {:error, term()}
  def unexpose(sandbox_or_result, port, opts \\ [])
  def unexpose({:ok, %__MODULE__{} = sandbox}, port, opts), do: unexpose(sandbox, port, opts)

  def unexpose(%__MODULE__{} = sandbox, port, opts) do
    with {:ok, _} <- API.unexpose_port(sandbox.name, port, opts) do
      {:ok, sandbox}
    end
  end

  @doc """
  Lists all currently exposed ports on the sandbox.

  ## Options

    - `:token` — bearer token override.

  ## Returns

    `{:ok, [%Sandbox.Types.Port{port, description, preview_url}]}`

  ## Example

      sandbox |> Sandbox.list_ports()
  """
  @spec list_ports(t() | {:ok, t()}, keyword()) ::
          {:ok, [Port.t()]} | {:error, term()}
  def list_ports(sandbox_or_result, opts \\ [])
  def list_ports({:ok, %__MODULE__{} = sandbox}, opts), do: list_ports(sandbox, opts)

  def list_ports(%__MODULE__{} = sandbox, opts) do
    API.list_ports(sandbox.name, opts)
  end

  # ---------------------------------------------------------------------------
  # VS Code
  # ---------------------------------------------------------------------------

  @doc """
  Exposes a VS Code Server instance for the sandbox and returns its URL.

  If VS Code is already exposed the existing URL is returned immediately
  without re-provisioning.

  ## Options

    - `:token` — bearer token override.

  ## Returns

    `{:ok, preview_url}` — `preview_url` is `nil` when the provider does
    not return one.

  ## Example

      {:ok, url} = sandbox |> Sandbox.vscode()
      IO.puts("Open VS Code at: \#{url}")
  """
  @spec vscode(t() | {:ok, t()}, keyword()) :: {:ok, String.t() | nil} | {:error, term()}
  def vscode(sandbox_or_result, opts \\ [])
  def vscode({:ok, %__MODULE__{} = sandbox}, opts), do: vscode(sandbox, opts)

  def vscode(%__MODULE__{} = sandbox, opts) do
    API.expose_vscode(sandbox.name, opts)
  end

  # ---------------------------------------------------------------------------
  # Secrets
  # ---------------------------------------------------------------------------

  @doc """
  Lists all secrets for the sandbox.

  ## Options

    - `:limit`  — max results (default: `100`).
    - `:offset` — pagination offset (default: `0`).
    - `:token`  — bearer token override.

  ## Example

      {:ok, secrets} = sandbox |> Sandbox.list_secrets()
  """
  @spec list_secrets(t() | {:ok, t()}, keyword()) ::
          {:ok, [Secret.t()]} | {:error, term()}
  def list_secrets(sandbox_or_result, opts \\ [])
  def list_secrets({:ok, %__MODULE__{} = sandbox}, opts), do: list_secrets(sandbox, opts)

  def list_secrets(%__MODULE__{} = sandbox, opts) do
    API.list_secrets(sandbox.id, opts)
  end

  @doc """
  Adds an encrypted secret to the sandbox.

  ## Example

      sandbox |> Sandbox.set_secret("DATABASE_URL", "postgres://...")
  """
  @spec set_secret(t() | {:ok, t()}, String.t(), String.t(), keyword()) ::
          {:ok, map()} | {:error, term()}
  def set_secret(sandbox_or_result, name, value, opts \\ [])

  def set_secret({:ok, %__MODULE__{} = sandbox}, name, value, opts),
    do: set_secret(sandbox, name, value, opts)

  def set_secret(%__MODULE__{} = sandbox, name, value, opts) do
    API.add_secret(sandbox.id, name, value, opts)
  end

  @doc """
  Deletes a secret by its id.

  ## Example

      sandbox |> Sandbox.delete_secret("secret-id")
  """
  @spec delete_secret(t() | {:ok, t()}, String.t(), keyword()) ::
          {:ok, map()} | {:error, term()}
  def delete_secret(sandbox_or_result, id, opts \\ [])

  def delete_secret({:ok, %__MODULE__{} = sandbox}, id, opts),
    do: delete_secret(sandbox, id, opts)

  def delete_secret(%__MODULE__{}, id, opts) do
    API.delete_secret(id, opts)
  end

  # ---------------------------------------------------------------------------
  # SSH Keys
  # ---------------------------------------------------------------------------

  @doc """
  Fetches the SSH key pair for the sandbox.

  ## Example

      {:ok, ssh_key} = sandbox |> Sandbox.get_ssh_keys()
      IO.puts(ssh_key.public_key)
  """
  @spec get_ssh_keys(t() | {:ok, t()}, keyword()) ::
          {:ok, SshKey.t()} | {:error, term()}
  def get_ssh_keys(sandbox_or_result, opts \\ [])
  def get_ssh_keys({:ok, %__MODULE__{} = sandbox}, opts), do: get_ssh_keys(sandbox, opts)

  def get_ssh_keys(%__MODULE__{} = sandbox, opts) do
    API.get_ssh_keys(sandbox.id, opts)
  end

  @doc """
  Stores an SSH key pair for the sandbox. The private key is encrypted
  client-side before transmission.

  ## Example

      sandbox |> Sandbox.set_ssh_keys(private_pem, public_key)
  """
  @spec set_ssh_keys(t() | {:ok, t()}, String.t(), String.t(), keyword()) ::
          {:ok, map()} | {:error, term()}
  def set_ssh_keys(sandbox_or_result, private_key, public_key, opts \\ [])

  def set_ssh_keys({:ok, %__MODULE__{} = sandbox}, private_key, public_key, opts),
    do: set_ssh_keys(sandbox, private_key, public_key, opts)

  def set_ssh_keys(%__MODULE__{} = sandbox, private_key, public_key, opts) do
    API.put_ssh_keys(sandbox.id, private_key, public_key, opts)
  end

  # ---------------------------------------------------------------------------
  # Tailscale
  # ---------------------------------------------------------------------------

  @doc """
  Fetches the Tailscale auth key for the sandbox.

  ## Example

      {:ok, ts} = sandbox |> Sandbox.get_tailscale_auth_key()
  """
  @spec get_tailscale_auth_key(t() | {:ok, t()}, keyword()) ::
          {:ok, TailscaleAuthKey.t()} | {:error, term()}
  def get_tailscale_auth_key(sandbox_or_result, opts \\ [])

  def get_tailscale_auth_key({:ok, %__MODULE__{} = sandbox}, opts),
    do: get_tailscale_auth_key(sandbox, opts)

  def get_tailscale_auth_key(%__MODULE__{} = sandbox, opts) do
    API.get_tailscale_auth_key(sandbox.id, opts)
  end

  @doc """
  Stores a Tailscale auth key for the sandbox. The key is encrypted
  client-side before transmission and must start with `"tskey-auth-"`.

  ## Example

      sandbox |> Sandbox.set_tailscale_auth_key("tskey-auth-xxxx")
  """
  @spec set_tailscale_auth_key(t() | {:ok, t()}, String.t(), keyword()) ::
          {:ok, map()} | {:error, term()}
  def set_tailscale_auth_key(sandbox_or_result, auth_key, opts \\ [])

  def set_tailscale_auth_key({:ok, %__MODULE__{} = sandbox}, auth_key, opts),
    do: set_tailscale_auth_key(sandbox, auth_key, opts)

  def set_tailscale_auth_key(%__MODULE__{} = sandbox, auth_key, opts) do
    API.put_tailscale_auth_key(sandbox.id, auth_key, opts)
  end

  # ---------------------------------------------------------------------------
  # Private
  # ---------------------------------------------------------------------------

  defp parse_status("RUNNING"), do: :running
  defp parse_status("STOPPED"), do: :stopped
  defp parse_status(_), do: :unknown
end
