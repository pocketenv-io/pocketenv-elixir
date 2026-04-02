defmodule Pocketenv.API do
  @moduledoc false
  # Internal HTTP layer. Consumers should use the `Pocketenv` module and
  # pipe on `%Sandbox{}` structs. This module is not part of the public API.

  alias Pocketenv.Client
  alias Sandbox.Types.{ExecResult, Port, Profile}

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
  # Private helpers
  # ---------------------------------------------------------------------------

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
