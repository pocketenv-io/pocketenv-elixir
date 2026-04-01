defmodule Pocketenv.Client do
  @moduledoc """
  Low-level HTTP client for the Pocketenv XRPC API.

  Wraps `Req` to provide authenticated requests to the
  `https://api.pocketenv.io` base URL (configurable via the
  `:pocketenv` application environment or the `POCKETENV_API_URL`
  environment variable).

  ## Configuration

  You can configure the API URL and token in `config/config.exs`:

      config :pocketenv,
        api_url: "https://api.pocketenv.io",
        token: "your-token-here"

  Or set the `POCKETENV_API_URL` / `POCKETENV_TOKEN` environment
  variables at runtime.

  ## Usage

      iex> Pocketenv.Client.get("/xrpc/io.pocketenv.actor.getProfile", token: "...", params: %{did: "did:plc:..."})
      {:ok, %{"did" => "did:plc:...", ...}}
  """

  @default_api_url "https://api.pocketenv.io"

  @doc """
  Returns the base URL for the API, resolved in order from:

  1. The `:api_url` key in the `:pocketenv` application environment.
  2. The `POCKETENV_API_URL` environment variable.
  3. The hardcoded default `https://api.pocketenv.io`.
  """
  @spec base_url() :: String.t()
  def base_url do
    Application.get_env(:pocketenv, :api_url) ||
      System.get_env("POCKETENV_API_URL") ||
      @default_api_url
  end

  @doc """
  Returns the bearer token, resolved in order from:

  1. The `:token` key in the `:pocketenv` application environment.
  2. The `POCKETENV_TOKEN` environment variable.
  3. `nil` (unauthenticated requests are allowed for some endpoints).
  """
  @spec token() :: {:ok, String.t()} | {:error, :not_logged_in}
  def token do
    case Application.get_env(:pocketenv, :token) ||
           System.get_env("POCKETENV_TOKEN") ||
           read_token_file() do
      nil -> {:error, :not_logged_in}
      token -> {:ok, token}
    end
  end

  defp read_token_file do
    path = Path.join([System.user_home!(), ".pocketenv", "token.json"])

    with {:ok, contents} <- File.read(path),
         {:ok, %{"token" => token}} when is_binary(token) <- Jason.decode(contents) do
      token
    else
      _ -> nil
    end
  end

  @doc """
  Perform an HTTP GET request against the Pocketenv API.

  ## Options

    * `:token`  – bearer token; defaults to `token/0`.
    * `:params` – query-string parameters as a map.

  Returns `{:ok, body}` on a 2xx response, or `{:error, reason}`.
  """
  @spec get(String.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def get(path, opts \\ []) do
    request(:get, path, nil, opts)
  end

  @doc """
  Perform an HTTP POST request against the Pocketenv API.

  ## Options

    * `:token`  – bearer token; defaults to `token/0`.
    * `:params` – query-string parameters as a map.

  Returns `{:ok, body}` on a 2xx response, or `{:error, reason}`.
  """
  @spec post(String.t(), map() | nil, keyword()) :: {:ok, map()} | {:error, term()}
  def post(path, body \\ nil, opts \\ []) do
    request(:post, path, body, opts)
  end

  @doc """
  Perform an HTTP DELETE request against the Pocketenv API.

  ## Options

    * `:token`  – bearer token; defaults to `token/0`.
    * `:params` – query-string parameters as a map.

  Returns `{:ok, body}` on a 2xx response, or `{:error, reason}`.
  """
  @spec delete(String.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def delete(path, opts \\ []) do
    request(:delete, path, nil, opts)
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp request(method, path, body, opts) do
    bearer =
      case Keyword.fetch(opts, :token) do
        {:ok, t} -> {:ok, t}
        :error -> token()
      end

    case bearer do
      {:error, :not_logged_in} ->
        {:error, :not_logged_in}

      {:ok, t} ->
        params = Keyword.get(opts, :params, %{})

        req_opts =
          [
            method: method,
            url: base_url() <> path,
            headers: build_headers(t),
            params: params
          ]
          |> maybe_put_json_body(body)

        case Req.request(req_opts) do
          {:ok, %Req.Response{status: status, body: body}} when status in 200..299 ->
            {:ok, body}

          {:ok, %Req.Response{status: status, body: body}} ->
            {:error, %{status: status, body: body}}

          {:error, reason} ->
            {:error, reason}
        end
    end
  end

  defp build_headers(token) do
    [
      {"content-type", "application/json"},
      {"authorization", "Bearer #{token}"}
    ]
  end

  defp maybe_put_json_body(req_opts, nil), do: req_opts
  defp maybe_put_json_body(req_opts, body), do: Keyword.put(req_opts, :json, body)
end
