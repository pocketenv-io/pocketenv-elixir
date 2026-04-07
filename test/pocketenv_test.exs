defmodule PocketenvTest do
  use ExUnit.Case

  # ---------------------------------------------------------------------------
  # Pocketenv.Client
  # ---------------------------------------------------------------------------

  describe "Pocketenv.Client.base_url/0" do
    test "returns the default API URL when no config is present" do
      prev = Application.get_env(:pocketenv, :api_url)
      Application.delete_env(:pocketenv, :api_url)
      System.delete_env("POCKETENV_API_URL")
      on_exit(fn -> if prev, do: Application.put_env(:pocketenv, :api_url, prev) end)

      assert Pocketenv.Client.base_url() == "https://api.pocketenv.io"
    end

    test "respects the POCKETENV_API_URL environment variable" do
      prev = Application.get_env(:pocketenv, :api_url)
      Application.delete_env(:pocketenv, :api_url)
      on_exit(fn -> if prev, do: Application.put_env(:pocketenv, :api_url, prev) end)

      System.put_env("POCKETENV_API_URL", "https://custom.api.example.com")
      on_exit(fn -> System.delete_env("POCKETENV_API_URL") end)

      assert Pocketenv.Client.base_url() == "https://custom.api.example.com"
    end

    test "application config takes precedence over environment variable" do
      System.put_env("POCKETENV_API_URL", "https://config.example.com")
      on_exit(fn -> System.delete_env("POCKETENV_API_URL") end)

      Application.put_env(:pocketenv, :api_url, "https://config.example.com")
      on_exit(fn -> Application.delete_env(:pocketenv, :api_url) end)

      assert Pocketenv.Client.base_url() == "https://config.example.com"
    end
  end

  describe "Pocketenv.Client.token/0" do
    test "returns {:error, :not_logged_in} when no token source is available" do
      prev_app = Application.get_env(:pocketenv, :token)
      prev_env = System.get_env("POCKETENV_TOKEN")

      Application.delete_env(:pocketenv, :token)
      System.delete_env("POCKETENV_TOKEN")

      on_exit(fn ->
        if prev_app, do: Application.put_env(:pocketenv, :token, prev_app)
        if prev_env, do: System.put_env("POCKETENV_TOKEN", prev_env)
      end)

      token_path = Path.join([System.user_home!(), ".pocketenv", "token.json"])

      if File.exists?(token_path) do
        # Token file is present (developer machine after pocketenv login)
        assert {:ok, t} = Pocketenv.Client.token()
        assert is_binary(t)
      else
        assert Pocketenv.Client.token() == {:error, :not_logged_in}
      end
    end

    test "returns {:ok, token} from the POCKETENV_TOKEN environment variable" do
      prev_app = Application.get_env(:pocketenv, :token)
      Application.delete_env(:pocketenv, :token)
      on_exit(fn -> if prev_app, do: Application.put_env(:pocketenv, :token, prev_app) end)

      System.put_env("POCKETENV_TOKEN", "env-token-abc")
      on_exit(fn -> System.delete_env("POCKETENV_TOKEN") end)

      assert Pocketenv.Client.token() == {:ok, "env-token-abc"}
    end

    test "application config takes precedence over environment variable" do
      System.put_env("POCKETENV_TOKEN", "config-token")
      on_exit(fn -> System.delete_env("POCKETENV_TOKEN") end)

      Application.put_env(:pocketenv, :token, "config-token")
      on_exit(fn -> Application.delete_env(:pocketenv, :token) end)

      assert Pocketenv.Client.token() == {:ok, "config-token"}
    end
  end

  # ---------------------------------------------------------------------------
  # Sandbox.Types.Profile
  # ---------------------------------------------------------------------------

  describe "Sandbox.Types.Profile.from_map/1" do
    test "parses a full profile map" do
      raw = %{
        "id" => "user-1",
        "did" => "did:plc:abc123",
        "handle" => "alice.bsky.social",
        "displayName" => "Alice",
        "avatar" => "https://cdn.bsky.app/img/avatar/plain/did:plc:abc123/bafkreig@jpeg",
        "createdAt" => "2024-01-01T00:00:00Z",
        "updatedAt" => "2024-06-01T00:00:00Z"
      }

      profile = Sandbox.Types.Profile.from_map(raw)

      assert profile.id == "user-1"
      assert profile.did == "did:plc:abc123"
      assert profile.handle == "alice.bsky.social"
      assert profile.display_name == "Alice"
      assert profile.avatar =~ "cdn.bsky.app"
      assert profile.created_at == "2024-01-01T00:00:00Z"
      assert profile.updated_at == "2024-06-01T00:00:00Z"
    end

    test "handles missing optional fields gracefully" do
      raw = %{"did" => "did:plc:xyz", "handle" => "bob.bsky.social"}
      profile = Sandbox.Types.Profile.from_map(raw)

      assert profile.did == "did:plc:xyz"
      assert profile.handle == "bob.bsky.social"
      assert profile.display_name == nil
      assert profile.avatar == nil
    end
  end

  # ---------------------------------------------------------------------------
  # %Sandbox{} struct
  # ---------------------------------------------------------------------------

  describe "Sandbox.from_map/1" do
    test "parses a running sandbox" do
      raw = %{
        "id" => "sbx-001",
        "name" => "my-sandbox",
        "provider" => "cloudflare",
        "baseSandbox" => "openclaw",
        "displayName" => "My Sandbox",
        "uri" => "at://did:plc:abc/io.pocketenv.sandbox/openclaw",
        "status" => "RUNNING",
        "installs" => 42,
        "createdAt" => "2024-01-01T00:00:00Z",
        "startedAt" => "2024-06-01T12:00:00Z"
      }

      sandbox = Sandbox.from_map(raw)

      assert sandbox.id == "sbx-001"
      assert sandbox.name == "my-sandbox"
      assert sandbox.provider == "cloudflare"
      assert sandbox.base_sandbox == "openclaw"
      assert sandbox.display_name == "My Sandbox"
      assert sandbox.status == :running
      assert sandbox.installs == 42
      assert sandbox.created_at == "2024-01-01T00:00:00Z"
      assert sandbox.started_at == "2024-06-01T12:00:00Z"
    end

    test "parses a stopped sandbox" do
      raw = %{"id" => "sbx-002", "name" => "idle", "status" => "STOPPED", "installs" => 0}
      sandbox = Sandbox.from_map(raw)
      assert sandbox.status == :stopped
    end

    test "treats unknown status values as :unknown" do
      raw = %{"id" => "sbx-003", "name" => "weird", "status" => "PENDING", "installs" => 0}
      sandbox = Sandbox.from_map(raw)
      assert sandbox.status == :unknown
    end

    test "defaults installs to 0 when absent" do
      raw = %{"id" => "sbx-004", "name" => "fresh", "status" => "STOPPED"}
      sandbox = Sandbox.from_map(raw)
      assert sandbox.installs == 0
    end

    test "parses nested owner profile" do
      raw = %{
        "id" => "sbx-005",
        "name" => "owned",
        "status" => "STOPPED",
        "installs" => 1,
        "owner" => %{
          "id" => "user-99",
          "did" => "did:plc:owner",
          "handle" => "owner.bsky.social"
        }
      }

      sandbox = Sandbox.from_map(raw)
      assert %Sandbox.Types.Profile{handle: "owner.bsky.social"} = sandbox.owner
    end

    test "owner is nil when not present in payload" do
      raw = %{"id" => "sbx-006", "name" => "no-owner", "status" => "STOPPED", "installs" => 0}
      sandbox = Sandbox.from_map(raw)
      assert sandbox.owner == nil
    end
  end

  # ---------------------------------------------------------------------------
  # Sandbox.Types.Port
  # ---------------------------------------------------------------------------

  describe "Sandbox.Types.Port.from_map/1" do
    test "parses a port with all fields" do
      raw = %{
        "port" => 3000,
        "description" => "web server",
        "previewUrl" => "https://3000-my-sandbox.sbx.pocketenv.io"
      }

      port = Sandbox.Types.Port.from_map(raw)

      assert port.port == 3000
      assert port.description == "web server"
      assert port.preview_url == "https://3000-my-sandbox.sbx.pocketenv.io"
    end

    test "handles missing optional fields" do
      raw = %{"port" => 8080}
      port = Sandbox.Types.Port.from_map(raw)

      assert port.port == 8080
      assert port.description == nil
      assert port.preview_url == nil
    end
  end

  # ---------------------------------------------------------------------------
  # Sandbox.Types.ExecResult
  # ---------------------------------------------------------------------------

  describe "Sandbox.Types.ExecResult.from_map/1" do
    test "parses a successful exec result" do
      raw = %{"stdout" => "hello\n", "stderr" => "", "exitCode" => 0}
      result = Sandbox.Types.ExecResult.from_map(raw)

      assert result.stdout == "hello\n"
      assert result.stderr == ""
      assert result.exit_code == 0
    end

    test "parses a failed exec result" do
      raw = %{"stdout" => "", "stderr" => "command not found\n", "exitCode" => 127}
      result = Sandbox.Types.ExecResult.from_map(raw)

      assert result.stdout == ""
      assert result.stderr == "command not found\n"
      assert result.exit_code == 127
    end

    test "defaults stdout and stderr to empty strings when absent" do
      raw = %{"exitCode" => 0}
      result = Sandbox.Types.ExecResult.from_map(raw)

      assert result.stdout == ""
      assert result.stderr == ""
    end

    test "defaults exit_code to 0 when absent" do
      raw = %{"stdout" => "ok"}
      result = Sandbox.Types.ExecResult.from_map(raw)

      assert result.exit_code == 0
    end
  end

  # ---------------------------------------------------------------------------
  # Sandbox pipe methods — {:ok, struct} passthrough
  # ---------------------------------------------------------------------------

  describe "Sandbox pipe methods – {:ok, struct} passthrough" do
    setup do
      fns = Sandbox.__info__(:functions)
      {:ok, fns: fns}
    end

    test "start/2 is defined", %{fns: fns} do
      assert {:start, 1} in fns
      assert {:start, 2} in fns
    end

    test "stop/2 is defined", %{fns: fns} do
      assert {:stop, 1} in fns
      assert {:stop, 2} in fns
    end

    test "delete/2 is defined", %{fns: fns} do
      assert {:delete, 1} in fns
      assert {:delete, 2} in fns
    end

    test "wait_until_running/2 is defined", %{fns: fns} do
      assert {:wait_until_running, 1} in fns
      assert {:wait_until_running, 2} in fns
    end

    test "exec/4 is defined", %{fns: fns} do
      assert {:exec, 2} in fns
      assert {:exec, 3} in fns
      assert {:exec, 4} in fns
    end

    test "expose/3 is defined", %{fns: fns} do
      assert {:expose, 2} in fns
      assert {:expose, 3} in fns
    end

    test "unexpose/3 is defined", %{fns: fns} do
      assert {:unexpose, 2} in fns
      assert {:unexpose, 3} in fns
    end

    test "list_ports/2 is defined", %{fns: fns} do
      assert {:list_ports, 1} in fns
      assert {:list_ports, 2} in fns
    end

    test "vscode/2 is defined", %{fns: fns} do
      assert {:vscode, 1} in fns
      assert {:vscode, 2} in fns
    end
  end

  describe "Sandbox pipe methods – error propagation" do
    test "passing {:error, reason} to start/2 raises FunctionClauseError" do
      assert_raise FunctionClauseError, fn ->
        Sandbox.start({:error, :not_found})
      end
    end

    test "passing {:error, reason} to stop/2 raises FunctionClauseError" do
      assert_raise FunctionClauseError, fn ->
        Sandbox.stop({:error, :not_found})
      end
    end

    test "passing {:error, reason} to exec/4 raises FunctionClauseError" do
      assert_raise FunctionClauseError, fn ->
        Sandbox.exec({:error, :not_found}, "echo", [])
      end
    end

    test "passing {:error, reason} to expose/3 raises FunctionClauseError" do
      assert_raise FunctionClauseError, fn ->
        Sandbox.expose({:error, :not_found}, 3000)
      end
    end

    test "passing {:error, reason} to vscode/2 raises FunctionClauseError" do
      assert_raise FunctionClauseError, fn ->
        Sandbox.vscode({:error, :not_found})
      end
    end
  end

  describe "Sandbox pipe methods – delete/2 returns last known state" do
    test "delete/2 returns the struct that was passed in on success" do
      sandbox = %Sandbox{id: "sbx-del", name: "to-delete", status: :stopped, installs: 0}
      assert is_struct(sandbox, Sandbox)

      fns = Sandbox.__info__(:functions)
      assert {:delete, 1} in fns
      assert {:delete, 2} in fns
    end
  end

  describe "Sandbox pipe methods – unexpose/3 returns sandbox" do
    test "unexpose/3 is exported with correct arities" do
      sandbox = %Sandbox{id: "sbx-unexp", name: "test-sandbox", status: :running, installs: 1}
      assert is_struct(sandbox, Sandbox)

      fns = Sandbox.__info__(:functions)
      assert {:unexpose, 2} in fns
      assert {:unexpose, 3} in fns
    end
  end

  # ---------------------------------------------------------------------------
  # Pocketenv.Ignore
  # ---------------------------------------------------------------------------

  describe "Pocketenv.Ignore.ignored?/2 – simple name patterns" do
    test "ignores an exact filename match" do
      ctx = build_contexts("", ".DS_Store")
      assert Pocketenv.Ignore.ignored?(ctx, ".DS_Store")
    end

    test "ignores the filename at any depth" do
      ctx = build_contexts("", ".DS_Store")
      assert Pocketenv.Ignore.ignored?(ctx, "a/b/.DS_Store")
    end

    test "does not ignore a non-matching file" do
      ctx = build_contexts("", ".DS_Store")
      refute Pocketenv.Ignore.ignored?(ctx, "README.md")
    end
  end

  describe "Pocketenv.Ignore.ignored?/2 – glob patterns" do
    test "*.log matches a log file at root" do
      ctx = build_contexts("", "*.log")
      assert Pocketenv.Ignore.ignored?(ctx, "debug.log")
    end

    test "*.log matches a log file at any depth via suffix check" do
      ctx = build_contexts("", "*.log")
      assert Pocketenv.Ignore.ignored?(ctx, "logs/debug.log")
      assert Pocketenv.Ignore.ignored?(ctx, "a/b/c/server.log")
    end

    test "*.log does not match unrelated extensions" do
      ctx = build_contexts("", "*.log")
      refute Pocketenv.Ignore.ignored?(ctx, "app.ex")
      refute Pocketenv.Ignore.ignored?(ctx, "logs/README.md")
    end

    test "? matches exactly one non-slash character" do
      ctx = build_contexts("", "foo?.txt")
      assert Pocketenv.Ignore.ignored?(ctx, "fooa.txt")
      refute Pocketenv.Ignore.ignored?(ctx, "foo.txt")
      refute Pocketenv.Ignore.ignored?(ctx, "fooab.txt")
    end
  end

  describe "Pocketenv.Ignore.ignored?/2 – directory patterns" do
    test "directory name ignores the directory itself" do
      ctx = build_contexts("", "node_modules")
      assert Pocketenv.Ignore.ignored?(ctx, "node_modules")
    end

    test "directory name ignores all contents" do
      ctx = build_contexts("", "node_modules")
      assert Pocketenv.Ignore.ignored?(ctx, "node_modules/index.js")
      assert Pocketenv.Ignore.ignored?(ctx, "node_modules/lodash/index.js")
    end

    test "directory name with trailing slash ignores all contents" do
      ctx = build_contexts("", "dist/")
      assert Pocketenv.Ignore.ignored?(ctx, "dist/bundle.js")
      assert Pocketenv.Ignore.ignored?(ctx, "dist/a/b.js")
    end

    test "directory pattern does not match unrelated names" do
      ctx = build_contexts("", "node_modules")
      refute Pocketenv.Ignore.ignored?(ctx, "src/index.js")
      refute Pocketenv.Ignore.ignored?(ctx, "not_node_modules/foo.js")
    end
  end

  describe "Pocketenv.Ignore.ignored?/2 – double-star patterns" do
    test "**/.DS_Store matches at any depth" do
      ctx = build_contexts("", "**/.DS_Store")
      assert Pocketenv.Ignore.ignored?(ctx, ".DS_Store")
      assert Pocketenv.Ignore.ignored?(ctx, "a/.DS_Store")
      assert Pocketenv.Ignore.ignored?(ctx, "a/b/c/.DS_Store")
    end

    test "build/** ignores everything under build/" do
      ctx = build_contexts("", "build/**")
      assert Pocketenv.Ignore.ignored?(ctx, "build/app.js")
      assert Pocketenv.Ignore.ignored?(ctx, "build/nested/app.js")
    end

    test "build/** does not match sibling directories" do
      ctx = build_contexts("", "build/**")
      refute Pocketenv.Ignore.ignored?(ctx, "src/app.js")
    end
  end

  describe "Pocketenv.Ignore.ignored?/2 – negation" do
    test "! un-ignores a previously matched path" do
      ctx = build_contexts("", "*.log\n!important.log")
      assert Pocketenv.Ignore.ignored?(ctx, "debug.log")
      refute Pocketenv.Ignore.ignored?(ctx, "important.log")
    end

    test "last matching pattern wins" do
      # ignore all, then keep .env, then ignore .env again
      ctx = build_contexts("", "*.env\n!.env\n.env")
      assert Pocketenv.Ignore.ignored?(ctx, ".env")
    end
  end

  describe "Pocketenv.Ignore.ignored?/2 – sub-directory context" do
    test "a context scoped to a subdirectory only applies within that directory" do
      ctx = build_contexts("src", "*.log")
      assert Pocketenv.Ignore.ignored?(ctx, "src/debug.log")
      refute Pocketenv.Ignore.ignored?(ctx, "lib/debug.log")
    end
  end

  describe "Pocketenv.Ignore.ignored?/2 – comments and blank lines" do
    test "lines starting with # are ignored" do
      ctx = build_contexts("", "# this is a comment\n*.log")
      assert Pocketenv.Ignore.ignored?(ctx, "app.log")
    end

    test "blank lines are ignored" do
      ctx = build_contexts("", "\n\n*.log\n\n")
      assert Pocketenv.Ignore.ignored?(ctx, "app.log")
    end
  end

  describe "Pocketenv.Ignore.load/1" do
    test "loads patterns from .gitignore in a temp directory" do
      dir =
        System.tmp_dir!()
        |> Path.join("pocketenv_ignore_test_#{System.unique_integer([:positive])}")

      File.mkdir_p!(dir)
      File.write!(Path.join(dir, ".gitignore"), "node_modules\n*.log\n")
      on_exit(fn -> File.rm_rf(dir) end)

      contexts = Pocketenv.Ignore.load(dir)
      assert length(contexts) == 1

      assert Pocketenv.Ignore.ignored?(contexts, "node_modules/index.js")
      assert Pocketenv.Ignore.ignored?(contexts, "app.log")
      refute Pocketenv.Ignore.ignored?(contexts, "src/app.ex")
    end

    test "loads patterns from nested ignore files with correct scope" do
      dir =
        System.tmp_dir!()
        |> Path.join("pocketenv_ignore_nested_#{System.unique_integer([:positive])}")

      sub = Path.join(dir, "packages/ui")
      File.mkdir_p!(sub)
      File.write!(Path.join(dir, ".gitignore"), "*.log\n")
      File.write!(Path.join(sub, ".gitignore"), "dist\n")
      on_exit(fn -> File.rm_rf(dir) end)

      contexts = Pocketenv.Ignore.load(dir)
      assert length(contexts) == 2

      # Root .gitignore applies everywhere
      assert Pocketenv.Ignore.ignored?(contexts, "app.log")
      assert Pocketenv.Ignore.ignored?(contexts, "packages/ui/app.log")

      # Nested .gitignore only applies within its directory
      assert Pocketenv.Ignore.ignored?(contexts, "packages/ui/dist/bundle.js")
      refute Pocketenv.Ignore.ignored?(contexts, "dist/bundle.js")
    end

    test "returns empty list for a directory with no ignore files" do
      dir =
        System.tmp_dir!()
        |> Path.join("pocketenv_no_ignore_#{System.unique_integer([:positive])}")

      File.mkdir_p!(dir)
      File.write!(Path.join(dir, "README.md"), "hello")
      on_exit(fn -> File.rm_rf(dir) end)

      assert Pocketenv.Ignore.load(dir) == []
    end

    test "skips unreadable ignore files gracefully" do
      # An empty context list is acceptable when no files can be read
      contexts = Pocketenv.Ignore.load("/nonexistent/path")
      assert contexts == []
    end
  end

  # Builds a single ignore context directly from a pattern string,
  # bypassing filesystem access.
  defp build_contexts(dir, pattern_content) do
    contexts = Pocketenv.Ignore.load_from_string(dir, pattern_content)
    contexts
  end

  # ---------------------------------------------------------------------------
  # Pocketenv.Copy.storage_url/0
  # ---------------------------------------------------------------------------

  describe "Pocketenv.Copy.storage_url/0" do
    test "returns the default storage URL when no config is present" do
      prev = Application.get_env(:pocketenv_ex, :storage_url)
      Application.delete_env(:pocketenv_ex, :storage_url)
      System.delete_env("POCKETENV_STORAGE_URL")
      on_exit(fn -> if prev, do: Application.put_env(:pocketenv_ex, :storage_url, prev) end)

      assert Pocketenv.Copy.storage_url() == "https://sandbox.pocketenv.io"
    end

    test "respects the POCKETENV_STORAGE_URL environment variable" do
      prev = Application.get_env(:pocketenv_ex, :storage_url)
      Application.delete_env(:pocketenv_ex, :storage_url)
      on_exit(fn -> if prev, do: Application.put_env(:pocketenv_ex, :storage_url, prev) end)

      System.put_env("POCKETENV_STORAGE_URL", "https://custom.storage.example.com")
      on_exit(fn -> System.delete_env("POCKETENV_STORAGE_URL") end)

      assert Pocketenv.Copy.storage_url() == "https://custom.storage.example.com"
    end

    test "application config takes precedence over environment variable" do
      System.put_env("POCKETENV_STORAGE_URL", "https://env.storage.example.com")
      on_exit(fn -> System.delete_env("POCKETENV_STORAGE_URL") end)

      Application.put_env(:pocketenv_ex, :storage_url, "https://config.storage.example.com")
      on_exit(fn -> Application.delete_env(:pocketenv_ex, :storage_url) end)

      assert Pocketenv.Copy.storage_url() == "https://config.storage.example.com"
    end
  end

  # ---------------------------------------------------------------------------
  # Sandbox copy methods — API surface
  # ---------------------------------------------------------------------------

  describe "Sandbox copy methods – arities" do
    setup do
      fns = Sandbox.__info__(:functions)
      {:ok, fns: fns}
    end

    test "upload/4 is defined", %{fns: fns} do
      assert {:upload, 3} in fns
      assert {:upload, 4} in fns
    end

    test "download/4 is defined", %{fns: fns} do
      assert {:download, 3} in fns
      assert {:download, 4} in fns
    end

    test "copy_to/5 is defined", %{fns: fns} do
      assert {:copy_to, 4} in fns
      assert {:copy_to, 5} in fns
    end
  end

  describe "Sandbox copy methods – {:ok, struct} passthrough" do
    test "upload/4 accepts {:ok, %Sandbox{}} and does not raise FunctionClauseError" do
      sandbox = %Sandbox{id: "sbx-1", name: "test", status: :running, installs: 0}

      tmp =
        Path.join(
          System.tmp_dir!(),
          "pocketenv_test_upload_#{:erlang.unique_integer([:positive])}.txt"
        )

      File.write!(tmp, "hello")
      on_exit(fn -> File.rm(tmp) end)

      # {:ok, struct} must not raise FunctionClauseError; it will fail at the HTTP layer
      assert match?({:error, _}, Sandbox.upload({:ok, sandbox}, tmp, "/remote"))
    end

    test "download/4 accepts {:ok, %Sandbox{}} and does not raise FunctionClauseError" do
      sandbox = %Sandbox{id: "sbx-1", name: "test", status: :running, installs: 0}
      # Fails at HTTP layer (no token / no network), not at pattern match
      assert match?({:error, _}, Sandbox.download({:ok, sandbox}, "/remote", System.tmp_dir!()))
    end

    test "copy_to/5 accepts {:ok, %Sandbox{}} and does not raise FunctionClauseError" do
      sandbox = %Sandbox{id: "sbx-1", name: "test", status: :running, installs: 0}
      assert match?({:error, _}, Sandbox.copy_to({:ok, sandbox}, "sbx-2", "/src", "/dest"))
    end
  end

  describe "Sandbox copy methods – error propagation" do
    test "upload/4 raises FunctionClauseError on {:error, reason}" do
      assert_raise FunctionClauseError, fn ->
        Sandbox.upload({:error, :not_found}, "/local", "/remote")
      end
    end

    test "download/4 raises FunctionClauseError on {:error, reason}" do
      assert_raise FunctionClauseError, fn ->
        Sandbox.download({:error, :not_found}, "/remote", "/local")
      end
    end

    test "copy_to/5 raises FunctionClauseError on {:error, reason}" do
      assert_raise FunctionClauseError, fn ->
        Sandbox.copy_to({:error, :not_found}, "sbx-2", "/src", "/dest")
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Sandbox.Types.Backup
  # ---------------------------------------------------------------------------

  describe "Sandbox.Types.Backup.from_map/1" do
    test "parses a backup with all fields" do
      raw = %{
        "id" => "bkp-001",
        "directory" => "/workspace",
        "description" => "before migration",
        "expiresAt" => "2024-12-31T00:00:00Z",
        "createdAt" => "2024-06-01T00:00:00Z"
      }

      backup = Sandbox.Types.Backup.from_map(raw)

      assert backup.id == "bkp-001"
      assert backup.directory == "/workspace"
      assert backup.description == "before migration"
      assert backup.expires_at == "2024-12-31T00:00:00Z"
      assert backup.created_at == "2024-06-01T00:00:00Z"
    end

    test "handles missing optional fields gracefully" do
      raw = %{
        "id" => "bkp-002",
        "directory" => "/home/user",
        "createdAt" => "2024-01-01T00:00:00Z"
      }

      backup = Sandbox.Types.Backup.from_map(raw)

      assert backup.id == "bkp-002"
      assert backup.directory == "/home/user"
      assert backup.description == nil
      assert backup.expires_at == nil
      assert backup.created_at == "2024-01-01T00:00:00Z"
    end
  end

  # ---------------------------------------------------------------------------
  # Sandbox backup pipe methods — API surface
  # ---------------------------------------------------------------------------

  describe "Sandbox backup methods – arities" do
    setup do
      fns = Sandbox.__info__(:functions)
      {:ok, fns: fns}
    end

    test "create_backup/3 is defined", %{fns: fns} do
      assert {:create_backup, 2} in fns
      assert {:create_backup, 3} in fns
    end

    test "list_backups/2 is defined", %{fns: fns} do
      assert {:list_backups, 1} in fns
      assert {:list_backups, 2} in fns
    end

    test "restore_backup/3 is defined", %{fns: fns} do
      assert {:restore_backup, 2} in fns
      assert {:restore_backup, 3} in fns
    end
  end

  describe "Sandbox backup methods – {:ok, struct} passthrough" do
    test "create_backup/3 accepts {:ok, %Sandbox{}} and does not raise FunctionClauseError" do
      sandbox = %Sandbox{id: "sbx-1", name: "test", status: :running, installs: 0}
      assert match?({:error, _}, Sandbox.create_backup({:ok, sandbox}, "/workspace"))
    end

    test "list_backups/2 accepts {:ok, %Sandbox{}} and does not raise FunctionClauseError" do
      sandbox = %Sandbox{id: "sbx-1", name: "test", status: :running, installs: 0}
      assert match?({:error, _}, Sandbox.list_backups({:ok, sandbox}))
    end

    test "restore_backup/3 accepts {:ok, %Sandbox{}} and does not raise FunctionClauseError" do
      sandbox = %Sandbox{id: "sbx-1", name: "test", status: :running, installs: 0}
      assert match?({:error, _}, Sandbox.restore_backup({:ok, sandbox}, "bkp-001"))
    end
  end

  describe "Sandbox backup methods – error propagation" do
    test "create_backup/3 raises FunctionClauseError on {:error, reason}" do
      assert_raise FunctionClauseError, fn ->
        Sandbox.create_backup({:error, :not_found}, "/workspace")
      end
    end

    test "list_backups/2 raises FunctionClauseError on {:error, reason}" do
      assert_raise FunctionClauseError, fn ->
        Sandbox.list_backups({:error, :not_found})
      end
    end

    test "restore_backup/3 raises FunctionClauseError on {:error, reason}" do
      assert_raise FunctionClauseError, fn ->
        Sandbox.restore_backup({:error, :not_found}, "bkp-001")
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Pocketenv public API surface
  # ---------------------------------------------------------------------------

  describe "Pocketenv public API" do
    setup do
      fns = Pocketenv.__info__(:functions)
      {:ok, fns: fns}
    end

    test "create_sandbox/2 is exported", %{fns: fns} do
      assert {:create_sandbox, 1} in fns
      assert {:create_sandbox, 2} in fns
    end

    test "get_sandbox/2 is exported", %{fns: fns} do
      assert {:get_sandbox, 1} in fns
      assert {:get_sandbox, 2} in fns
    end

    test "list_sandboxes/1 is exported", %{fns: fns} do
      assert {:list_sandboxes, 0} in fns
      assert {:list_sandboxes, 1} in fns
    end

    test "list_sandboxes_by_actor/2 is exported", %{fns: fns} do
      assert {:list_sandboxes_by_actor, 1} in fns
      assert {:list_sandboxes_by_actor, 2} in fns
    end

    test "me/1 is exported", %{fns: fns} do
      assert {:me, 0} in fns
      assert {:me, 1} in fns
    end

    test "get_profile/2 is exported", %{fns: fns} do
      assert {:get_profile, 1} in fns
      assert {:get_profile, 2} in fns
    end

    test "old generic names (create, start, stop, delete, exec, list) are NOT exported",
         %{fns: fns} do
      refute {:create, 1} in fns
      refute {:create, 2} in fns
      refute {:start, 1} in fns
      refute {:stop, 1} in fns
      refute {:delete, 1} in fns
      refute {:exec, 2} in fns
      refute {:list, 0} in fns
      refute {:list, 1} in fns
    end
  end
end
