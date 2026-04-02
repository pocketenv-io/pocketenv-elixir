defmodule Pocketenv do
  @moduledoc """
  Elixir SDK for the [Pocketenv](https://pocketenv.io) sandbox platform.

  `Pocketenv` is the single entry point for the SDK. It returns `%Sandbox{}`
  structs that you pipe operations on:

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

  ## Configuration

  ### `config/config.exs`

      import Config

      config :pocketenv,
        token: "your-token",
        api_url: "https://api.pocketenv.io"   # optional

  ### Environment variables

      export POCKETENV_TOKEN="your-token"
      export POCKETENV_API_URL="https://api.pocketenv.io"   # optional

  Application config takes precedence over environment variables.
  """

  alias Pocketenv.API

  # ---------------------------------------------------------------------------
  # Sandboxes
  # ---------------------------------------------------------------------------

  @doc """
  Creates a new sandbox and returns a `%Sandbox{}`.

  ## Options

    - `:base`       — AT-URI of the base sandbox image (default: `openclaw`).
    - `:provider`   — `:cloudflare` (default), `:daytona`, `:deno`,
                      `:vercel`, or `:sprites`.
    - `:repo`       — GitHub repo URL to clone into the sandbox on start.
    - `:keep_alive` — keep the sandbox alive after the session ends.
    - `:token`      — bearer token override.

  ## Example

      {:ok, sandbox} = Pocketenv.create_sandbox("my-sandbox")
      {:ok, sandbox} = Pocketenv.create_sandbox("ml-box", repo: "github.com/me/repo")
  """
  @spec create_sandbox(String.t(), keyword()) :: {:ok, Sandbox.t()} | {:error, term()}
  defdelegate create_sandbox(name, opts \\ []), to: API

  @doc """
  Fetches a single sandbox by id or name.

  ## Example

      {:ok, sandbox} = Pocketenv.get_sandbox("my-sandbox")
      {:ok, nil}     = Pocketenv.get_sandbox("nonexistent")
  """
  @spec get_sandbox(String.t(), keyword()) :: {:ok, Sandbox.t() | nil} | {:error, term()}
  defdelegate get_sandbox(id, opts \\ []), to: API

  @doc """
  Lists the official public sandbox catalog.

  Returns `{:ok, {[%Sandbox{}], total}}`.

  ## Options

    - `:limit`  — max results (default: `30`).
    - `:offset` — pagination offset (default: `0`).
    - `:token`  — bearer token override.

  ## Example

      {:ok, {sandboxes, total}} = Pocketenv.list_sandboxes()
  """
  @spec list_sandboxes(keyword()) ::
          {:ok, {[Sandbox.t()], non_neg_integer()}} | {:error, term()}
  defdelegate list_sandboxes(opts \\ []), to: API

  @doc """
  Lists all sandboxes belonging to a specific actor (user).

  Returns `{:ok, {[%Sandbox{}], total}}`.

  ## Parameters

    - `did` — the actor's DID (`"did:plc:..."`) or handle
              (`"alice.bsky.social"`).

  ## Options

    - `:limit`  — max results (default: `30`).
    - `:offset` — pagination offset (default: `0`).
    - `:token`  — bearer token override.

  ## Example

      {:ok, {sandboxes, total}} = Pocketenv.list_sandboxes_by_actor("alice.bsky.social")
  """
  @spec list_sandboxes_by_actor(String.t(), keyword()) ::
          {:ok, {[Sandbox.t()], non_neg_integer()}} | {:error, term()}
  defdelegate list_sandboxes_by_actor(did, opts \\ []), to: API

  # ---------------------------------------------------------------------------
  # Actor / profile
  # ---------------------------------------------------------------------------

  @doc """
  Fetches the profile of the currently authenticated user.

  ## Example

      {:ok, me} = Pocketenv.me()
      IO.puts("Logged in as @\#{me.handle}")
  """
  @spec me(keyword()) :: {:ok, Sandbox.Types.Profile.t()} | {:error, term()}
  defdelegate me(opts \\ []), to: API

  @doc """
  Fetches the profile of any actor by DID or handle.

  ## Example

      {:ok, profile} = Pocketenv.get_profile("alice.bsky.social")
      {:ok, profile} = Pocketenv.get_profile("did:plc:abc123")
  """
  @spec get_profile(String.t(), keyword()) ::
          {:ok, Sandbox.Types.Profile.t()} | {:error, term()}
  defdelegate get_profile(did, opts \\ []), to: API

  # ---------------------------------------------------------------------------
  # Secrets
  # ---------------------------------------------------------------------------

  @doc """
  Lists all secrets for a sandbox.

  ## Options

    - `:limit`  — max results (default: `100`).
    - `:offset` — pagination offset (default: `0`).
    - `:token`  — bearer token override.

  ## Example

      {:ok, secrets} = Pocketenv.list_secrets(sandbox.id)
  """
  @spec list_secrets(String.t(), keyword()) ::
          {:ok, [Sandbox.Types.Secret.t()]} | {:error, term()}
  defdelegate list_secrets(sandbox_id, opts \\ []), to: API

  @doc """
  Adds an encrypted secret to a sandbox.

  The `value` is encrypted client-side using the server's public key
  (configured via `:public_key` app config or `POCKETENV_PUBLIC_KEY` env var)
  before being sent to the API.

  ## Example

      {:ok, _} = Pocketenv.add_secret(sandbox.id, "DATABASE_URL", "postgres://...")
  """
  @spec add_secret(String.t(), String.t(), String.t(), keyword()) ::
          {:ok, map()} | {:error, term()}
  defdelegate add_secret(sandbox_id, name, value, opts \\ []), to: API

  @doc """
  Deletes a secret by its id.

  ## Example

      {:ok, _} = Pocketenv.delete_secret("secret-id")
  """
  @spec delete_secret(String.t(), keyword()) :: {:ok, map()} | {:error, term()}
  defdelegate delete_secret(id, opts \\ []), to: API

  # ---------------------------------------------------------------------------
  # SSH Keys
  # ---------------------------------------------------------------------------

  @doc """
  Fetches the SSH key pair for a sandbox.

  The returned `private_key` field contains the redacted (server-side) value.

  ## Example

      {:ok, ssh_key} = Pocketenv.get_ssh_keys(sandbox.id)
      IO.puts(ssh_key.public_key)
  """
  @spec get_ssh_keys(String.t(), keyword()) ::
          {:ok, Sandbox.Types.SshKey.t()} | {:error, term()}
  defdelegate get_ssh_keys(sandbox_id, opts \\ []), to: API

  @doc """
  Stores an SSH key pair for a sandbox.

  The `private_key` is encrypted client-side using the server's public key
  before transmission. A redacted version is stored alongside it.

  ## Parameters

    - `sandbox_id`  — sandbox ID.
    - `private_key` — PEM-encoded OpenSSH private key string.
    - `public_key`  — OpenSSH public key string (`ssh-ed25519 AAAA...`).

  ## Example

      {:ok, _} = Pocketenv.put_ssh_keys(sandbox.id, private_pem, public_key)
  """
  @spec put_ssh_keys(String.t(), String.t(), String.t(), keyword()) ::
          {:ok, map()} | {:error, term()}
  defdelegate put_ssh_keys(sandbox_id, private_key, public_key, opts \\ []), to: API

  # ---------------------------------------------------------------------------
  # Tailscale
  # ---------------------------------------------------------------------------

  @doc """
  Fetches the Tailscale auth key for a sandbox.

  The returned `auth_key` is the redacted value stored on the server.

  ## Example

      {:ok, ts} = Pocketenv.get_tailscale_auth_key(sandbox.id)
      IO.puts(ts.auth_key)
  """
  @spec get_tailscale_auth_key(String.t(), keyword()) ::
          {:ok, Sandbox.Types.TailscaleAuthKey.t()} | {:error, term()}
  defdelegate get_tailscale_auth_key(sandbox_id, opts \\ []), to: API

  @doc """
  Stores a Tailscale auth key for a sandbox.

  The `auth_key` must start with `"tskey-auth-"`. It is encrypted client-side
  using the server's public key before transmission.

  ## Example

      {:ok, _} = Pocketenv.put_tailscale_auth_key(sandbox.id, "tskey-auth-xxxx")
  """
  @spec put_tailscale_auth_key(String.t(), String.t(), keyword()) ::
          {:ok, map()} | {:error, term()}
  defdelegate put_tailscale_auth_key(sandbox_id, auth_key, opts \\ []), to: API
end
