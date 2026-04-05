defmodule Pocketenv.Ignore do
  @moduledoc false
  # Gitignore-style file filtering for copy operations.
  #
  # Mirrors the TypeScript SDK's ignore.ts: loads `.pocketenvignore`,
  # `.gitignore`, `.npmignore`, and `.dockerignore` files found anywhere
  # under the source directory, then exposes `ignored?/2` to check whether
  # a relative path should be excluded from an archive.
  #
  # Matching semantics follow the gitignore spec subset that covers
  # real-world usage:
  #   - `*`  matches anything except `/`
  #   - `**` matches anything including `/`
  #   - `?`  matches any single character except `/`
  #   - `[abc]` character classes
  #   - Leading `/` anchors to the ignore file's directory
  #   - Trailing `/` means directory (also matches all contents)
  #   - `!` prefix negates (un-ignores) a previously matched path
  #   - Last matching pattern wins

  @ignore_filenames MapSet.new([
                      ".pocketenvignore",
                      ".gitignore",
                      ".npmignore",
                      ".dockerignore"
                    ])

  @type context :: {dir :: String.t(), patterns :: [pattern()]}
  @type pattern :: {:ignore | :keep, Regex.t(), Regex.t()}

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @doc """
  Scans `root` recursively for ignore files and returns a list of contexts,
  each binding a directory (relative to `root`) to its compiled patterns.
  """
  @spec load(String.t()) :: [context()]
  def load(root) do
    walk(root, "")
    |> Enum.filter(fn rel -> MapSet.member?(@ignore_filenames, Path.basename(rel)) end)
    |> Enum.flat_map(fn rel ->
      full = Path.join(root, rel)
      dir = case Path.dirname(rel) do
        "." -> ""
        d -> d
      end

      case File.read(full) do
        {:ok, content} -> [{dir, parse(content)}]
        {:error, _} -> []
      end
    end)
  end

  @doc false
  # Builds a context list directly from a pattern string. Used in tests to
  # avoid filesystem access.
  @spec load_from_string(String.t(), String.t()) :: [context()]
  def load_from_string(dir, content), do: [{dir, parse(content)}]

  @doc """
  Returns `true` if `path` (relative to the source root) should be excluded
  based on the given ignore `contexts`.

  Implements the same suffix-checking strategy as the TypeScript SDK:
  each sub-path suffix of `path` is tested so that un-anchored patterns
  (e.g. `*.log`, `node_modules`) match at any depth.
  """
  @spec ignored?([context()], String.t()) :: boolean()
  def ignored?(contexts, path) do
    Enum.any?(contexts, fn {dir, patterns} ->
      scoped =
        cond do
          dir == "" ->
            path

          String.starts_with?(path, dir <> "/") ->
            String.slice(path, byte_size(dir) + 1, byte_size(path))

          true ->
            nil
        end

      if scoped == nil do
        false
      else
        parts = String.split(scoped, "/")
        n = length(parts)

        Enum.any?(0..(n - 1), fn i ->
          sub = parts |> Enum.drop(i) |> Enum.join("/")
          match_any?(patterns, sub)
        end)
      end
    end)
  end

  # ---------------------------------------------------------------------------
  # Pattern parsing
  # ---------------------------------------------------------------------------

  defp parse(content) do
    content
    |> String.split(["\r\n", "\n"])
    |> Enum.map(&String.trim/1)
    |> Enum.reject(fn line -> line == "" or String.starts_with?(line, "#") end)
    |> Enum.map(&parse_line/1)
  end

  defp parse_line("!" <> rest) do
    {exact, prefix} = compile(rest)
    {:keep, exact, prefix}
  end

  defp parse_line(line) do
    {exact, prefix} = compile(line)
    {:ignore, exact, prefix}
  end

  # Compiles a single gitignore pattern into two regexes:
  #   - `exact`  — matches the path itself
  #   - `prefix` — matches anything *inside* a matching directory
  defp compile(pattern) do
    pattern = String.trim_trailing(pattern, "/")
    pattern = String.trim_leading(pattern, "/")
    rs = to_regex_str(pattern)
    exact = Regex.compile!("^#{rs}$")
    prefix = Regex.compile!("^#{rs}/")
    {exact, prefix}
  end

  # ---------------------------------------------------------------------------
  # Glob → regex conversion
  # ---------------------------------------------------------------------------

  defp to_regex_str(pattern), do: pattern |> do_to_regex([]) |> Enum.join()

  # Base case
  defp do_to_regex("", acc), do: Enum.reverse(acc)

  # `**/` — zero or more leading path components
  defp do_to_regex("**/" <> rest, acc),
    do: do_to_regex(rest, ["(?:.+/)?" | acc])

  # `**` — anything (including slashes)
  defp do_to_regex("**" <> rest, acc),
    do: do_to_regex(rest, [".*" | acc])

  # `*` — anything except `/`
  defp do_to_regex("*" <> rest, acc),
    do: do_to_regex(rest, ["[^/]*" | acc])

  # `?` — any single character except `/`
  defp do_to_regex("?" <> rest, acc),
    do: do_to_regex(rest, ["[^/]" | acc])

  # `[...]` character class — pass through verbatim
  defp do_to_regex("[" <> rest, acc) do
    case String.split(rest, "]", parts: 2) do
      [chars, remainder] -> do_to_regex(remainder, ["[#{chars}]" | acc])
      _ -> do_to_regex(rest, ["\\[" | acc])
    end
  end

  # Escape regex metacharacters that aren't glob specials
  defp do_to_regex(<<c, rest::binary>>, acc) when c in ~c[.+^${}()|\\] do
    do_to_regex(rest, ["\\#{<<c>>}" | acc])
  end

  # Literal character
  defp do_to_regex(<<c, rest::binary>>, acc),
    do: do_to_regex(rest, [<<c>> | acc])

  # ---------------------------------------------------------------------------
  # Pattern matching
  # ---------------------------------------------------------------------------

  # Returns `true` if the last matching pattern says `:ignore`.
  defp match_any?(patterns, sub) do
    patterns
    |> Enum.reduce(nil, fn {type, exact, prefix}, acc ->
      if Regex.match?(exact, sub) or Regex.match?(prefix, sub), do: type, else: acc
    end)
    |> case do
      :ignore -> true
      _ -> false
    end
  end

  # ---------------------------------------------------------------------------
  # Filesystem walk helper
  # ---------------------------------------------------------------------------

  defp walk(base, prefix) do
    dir = if prefix == "", do: base, else: Path.join(base, prefix)

    case File.ls(dir) do
      {:ok, entries} ->
        Enum.flat_map(entries, fn entry ->
          rel = if prefix == "", do: entry, else: Path.join(prefix, entry)

          case File.lstat(Path.join(base, rel)) do
            {:ok, %{type: :regular}} -> [rel]
            {:ok, %{type: :directory}} -> walk(base, rel)
            _ -> []
          end
        end)

      {:error, _} ->
        []
    end
  end
end
