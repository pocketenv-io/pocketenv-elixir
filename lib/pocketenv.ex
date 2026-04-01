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
    - `:provider`   — `"cloudflare"` (default), `"daytona"`, `"deno"`,
                      `"vercel"`, or `"sprites"`.
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
end
