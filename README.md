# pocketenv-elixir

Elixir SDK for the [Pocketenv](https://pocketenv.io) sandbox platform.

Pocketenv lets you spin up isolated cloud sandbox environments on demand.
This library wraps the Pocketenv XRPC API so you can manage sandboxes
directly from your Elixir applications.

---

## Installation

Add `pocketenv_ex` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:pocketenv_ex, "~> 0.1"}
  ]
end
```

```sh
mix deps.get
```

---

## Configuration

### `config/config.exs`

```elixir
import Config

config :pocketenv_ex,
  token: "your-pocketenv-token",
  api_url: "https://api.pocketenv.io"   # optional — this is the default
```

### Environment variables

```sh
export POCKETENV_TOKEN="your-pocketenv-token"
export POCKETENV_API_URL="https://api.pocketenv.io"   # optional
```

Application config takes precedence over environment variables.

---

## Quick start

`Pocketenv` is the entry point. It returns `%Sandbox{}` structs that you
pipe operations on:

```elixir
{:ok, sandbox} =
  Pocketenv.create_sandbox("my-sandbox")
  |> Sandbox.start()
  |> Sandbox.wait_until_running()

{:ok, result} = sandbox |> Sandbox.exec("echo", ["hello"])
IO.puts(result.stdout)      # => "hello"

{:ok, url} = sandbox |> Sandbox.expose(3000)
IO.puts(url)                # => "https://3000-my-sandbox.sbx.pocketenv.io"

{:ok, vscode_url} = sandbox |> Sandbox.vscode()

sandbox
|> Sandbox.stop()
|> Sandbox.delete()
```

Every `Sandbox` function accepts either a bare `%Sandbox{}` **or** an
`{:ok, %Sandbox{}}` tuple as its first argument, so you can pipe from any
previous step without manually unwrapping.

---

## API reference

All functions return `{:ok, result}` on success and `{:error, reason}` on
failure. Every function accepts an optional `:token` keyword argument to
override the globally configured token for that single call.

---

### `Pocketenv` — entry point

#### Sandboxes

| Function | Returns | Description |
|---|---|---|
| `Pocketenv.create_sandbox(name, opts)` | `{:ok, %Sandbox{}}` | Create a new sandbox |
| `Pocketenv.get_sandbox(id, opts)` | `{:ok, %Sandbox{} \| nil}` | Fetch a sandbox by id or name |
| `Pocketenv.list_sandboxes(opts)` | `{:ok, {[%Sandbox{}], total}}` | List the public sandbox catalog |
| `Pocketenv.list_sandboxes_by_actor(did, opts)` | `{:ok, {[%Sandbox{}], total}}` | List all sandboxes for a user |

##### `create_sandbox/2` options

| Option | Type | Default | Description |
|---|---|---|---|
| `:base` | `string` | official `openclaw` image | AT-URI of the base sandbox image |
| `:provider` | `atom` | `:cloudflare` | `:cloudflare`, `:daytona`, `:deno`, `:vercel`, or `:sprites` |
| `:repo` | `string` | `nil` | GitHub repo URL to clone on start |
| `:keep_alive` | `boolean` | `nil` | Keep the sandbox alive after the session ends |
| `:token` | `string` | global config | Bearer token override |

##### `list_sandboxes/1` and `list_sandboxes_by_actor/2` options

| Option | Type | Default | Description |
|---|---|---|---|
| `:limit` | `integer` | `30` | Max results |
| `:offset` | `integer` | `0` | Pagination offset |
| `:token` | `string` | global config | Bearer token override |

#### Actor / profile

| Function | Returns | Description |
|---|---|---|
| `Pocketenv.me(opts)` | `{:ok, %Profile{}}` | Fetch the authenticated user's profile |
| `Pocketenv.get_profile(did, opts)` | `{:ok, %Profile{}}` | Fetch any user's profile by DID or handle |

```elixir
{:ok, me} = Pocketenv.me()
IO.puts("Logged in as @#{me.handle}")

{:ok, profile} = Pocketenv.get_profile("alice.bsky.social")
```

---

### `Sandbox` — operations on a sandbox

All functions take a `%Sandbox{}` or `{:ok, %Sandbox{}}` as their first
argument.

#### Lifecycle

| Function | Returns | Description |
|---|---|---|
| `Sandbox.start(sandbox, opts)` | `{:ok, %Sandbox{}}` | Start the sandbox, re-fetches state |
| `Sandbox.stop(sandbox, opts)` | `{:ok, %Sandbox{}}` | Stop the sandbox, re-fetches state |
| `Sandbox.delete(sandbox, opts)` | `{:ok, %Sandbox{}}` | Delete the sandbox permanently |
| `Sandbox.wait_until_running(sandbox, opts)` | `{:ok, %Sandbox{}}` | Poll until status is `:running` |

`start/2` and `stop/2` re-fetch the sandbox after the API call so the
returned struct always has the latest status. `delete/2` returns the last
known state.

##### `wait_until_running/2` options

| Option | Type | Default | Description |
|---|---|---|---|
| `:timeout_ms` | `integer` | `60_000` | Total wait time in ms |
| `:interval_ms` | `integer` | `2_000` | Polling interval in ms |
| `:token` | `string` | global config | Bearer token override |

#### Commands

```elixir
{:ok, result} = sandbox |> Sandbox.exec("mix", ["test", "--trace"])

IO.puts(result.stdout)
IO.puts(result.stderr)
IO.inspect(result.exit_code)
```

| Function | Returns | Description |
|---|---|---|
| `Sandbox.exec(sandbox, cmd, args \\ [], opts)` | `{:ok, %ExecResult{}}` | Run a shell command inside the sandbox |

#### Ports

```elixir
{:ok, url}   = sandbox |> Sandbox.expose(4000, description: "Phoenix")
{:ok, ports} = sandbox |> Sandbox.list_ports()
{:ok, _}     = sandbox |> Sandbox.unexpose(4000)
```

| Function | Returns | Description |
|---|---|---|
| `Sandbox.expose(sandbox, port, opts)` | `{:ok, url \| nil}` | Expose a port publicly |
| `Sandbox.unexpose(sandbox, port, opts)` | `{:ok, %Sandbox{}}` | Remove an exposed port |
| `Sandbox.list_ports(sandbox, opts)` | `{:ok, [%Port{}]}` | List all exposed ports |

#### VS Code

```elixir
{:ok, url} = sandbox |> Sandbox.vscode()
IO.puts("Open VS Code at: #{url}")
```

| Function | Returns | Description |
|---|---|---|
| `Sandbox.vscode(sandbox, opts)` | `{:ok, url \| nil}` | Expose VS Code Server and return its URL |

If VS Code is already exposed the existing URL is returned immediately.

---

## Types

### `%Sandbox{}`

The central type of the SDK. Returned by `Pocketenv.create_sandbox/2`,
`Pocketenv.get_sandbox/2`, and all `Sandbox.*` lifecycle functions.

```
%Sandbox{
  id:           String.t() | nil,
  name:         String.t() | nil,
  provider:     String.t() | nil,
  base_sandbox: String.t() | nil,
  display_name: String.t() | nil,
  uri:          String.t() | nil,
  description:  String.t() | nil,
  topics:       [String.t()] | nil,
  logo:         String.t() | nil,
  readme:       String.t() | nil,
  repo:         String.t() | nil,
  vcpus:        integer() | nil,
  memory:       integer() | nil,
  disk:         integer() | nil,
  installs:     integer(),
  status:       :running | :stopped | :unknown,
  started_at:   String.t() | nil,
  created_at:   String.t() | nil,
  owner:        %Sandbox.Types.Profile{} | nil
}
```

### `%Sandbox.Types.ExecResult{}`

Returned by `Sandbox.exec/4`.

```
%Sandbox.Types.ExecResult{
  stdout:    String.t(),
  stderr:    String.t(),
  exit_code: integer()
}
```

### `%Sandbox.Types.Port{}`

Returned in the list by `Sandbox.list_ports/2`.

```
%Sandbox.Types.Port{
  port:        integer(),
  description: String.t() | nil,
  preview_url: String.t() | nil
}
```

### `%Sandbox.Types.Profile{}`

Returned by `Pocketenv.me/1` and `Pocketenv.get_profile/2`.

```
%Sandbox.Types.Profile{
  id:           String.t() | nil,
  did:          String.t(),
  handle:       String.t(),
  display_name: String.t() | nil,
  avatar:       String.t() | nil,
  created_at:   String.t() | nil,
  updated_at:   String.t() | nil
}
```

---

## Low-level client

If you need to call an endpoint not yet covered by the high-level API,
use `Pocketenv.Client` directly:

```elixir
{:ok, body} = Pocketenv.Client.get(
  "/xrpc/io.pocketenv.sandbox.getSandbox",
  params: %{"id" => "my-sandbox"},
  token: "override-token"
)

{:ok, body} = Pocketenv.Client.post(
  "/xrpc/io.pocketenv.sandbox.startSandbox",
  %{"keepAlive" => true},
  params: %{"id" => "my-sandbox"}
)
```

---

## Running tests

```sh
mix test
```

The test suite does **not** make real HTTP calls. Integration tests that
exercise the live API require a valid `POCKETENV_TOKEN` and are not
included by default.

---

## License

MIT
