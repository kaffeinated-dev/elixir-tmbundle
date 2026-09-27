defmodule TextMate.HTML do
  @moduledoc false

  # Runs a command for TextMate's HTML output window: shows its output as it
  # arrives, with ANSI colors as styled spans and file references such as
  # `lib/my_app/user.ex:12` as links that open in TextMate, then its status.
  #
  #     elixir -r html.ex -e TextMate.HTML.main -- TITLE SHOWN STATUSES COMMAND [ARGS…]
  #
  # SHOWN is the command shown in the heading, if not COMMAND itself. STATUSES
  # describes exit statuses, e.g. "0:success:Tests passed.|2:failure:Tests failed.";
  # other statuses are shown as failures. The command runs in the current directory,
  # which is also where relative file references are looked up.

  # A line without a newline (such as ExUnit's dots) is shown once the command
  # has printed nothing for this long, in milliseconds.
  @flush_after 100

  def main(argv \\ System.argv()) do
    [title, shown, statuses, executable | args] = argv
    root = File.cwd!()
    shown = if shown == "", do: Enum.join([executable | args], " "), else: shown

    IO.write(header(title, shown, root))

    status =
      case System.find_executable(executable) do
        nil ->
          IO.write(escape("#{executable}: command not found\n"))
          127

        path ->
          run(path, args, root)
      end

    IO.write(footer(status, statuses))
    System.halt(0)
  end

  # Output is colored, as when running in a terminal.
  defp run(path, args, root) do
    erl_options = String.trim("#{System.get_env("ELIXIR_ERL_OPTIONS")} -elixir ansi_enabled true")

    port =
      Port.open({:spawn_executable, path}, [
        :binary,
        :exit_status,
        :stderr_to_stdout,
        args: args,
        env: [{~c"ELIXIR_ERL_OPTIONS", String.to_charlist(erl_options)}]
      ])

    loop(port, new(root))
  end

  defp loop(port, state) do
    timeout = if state.pending == "", do: :infinity, else: @flush_after

    receive do
      {^port, {:data, data}} ->
        {html, state} = feed(state, data)
        IO.write(html)
        loop(port, state)

      {^port, {:exit_status, status}} ->
        {html, _state} = finish(state)
        IO.write(html)
        status
    after
      timeout ->
        {html, state} = flush(state)
        IO.write(html)
        loop(port, state)
    end
  end

  # ==========
  # = Output =
  # ==========

  # `pending` is output not yet shown: the end of an incomplete line.
  def new(root), do: %{root: root, style: %{}, pending: ""}

  # Converts the complete lines of the output so far.
  def feed(state, data) do
    lines = String.split(state.pending <> data, "\n")
    {complete, [pending]} = Enum.split(lines, -1)

    {html, style} =
      Enum.map_reduce(complete, state.style, fn line, style ->
        {html, style} = convert(line, style, state.root)
        {[html, ?\n], style}
      end)

    {html, %{state | style: style, pending: pending}}
  end

  # Converts the incomplete line, except for an incomplete escape sequence or
  # character at its end.
  def flush(state) do
    {ready, rest} = split_incomplete(state.pending)
    {html, style} = convert(ready, state.style, state.root)
    {html, %{state | style: style, pending: rest}}
  end

  def finish(state) do
    {html, style} = convert(state.pending, state.style, state.root)
    {html, %{state | style: style, pending: ""}}
  end

  defp split_incomplete(text) do
    {text, rest} =
      case :unicode.characters_to_binary(text) do
        {:incomplete, complete, rest} -> {complete, rest}
        _ -> {text, ""}
      end

    case Regex.run(~r/\e(?:\[[0-9;?]*)?\z/, text, return: :index) do
      [{start, _}] ->
        {binary_part(text, 0, start), binary_part(text, start, byte_size(text) - start) <> rest}

      nil ->
        {text, rest}
    end
  end

  # Converts one line (or part of one) to HTML. Returns the HTML and the style
  # at its end, as colors continue on the next line until they are reset.
  def convert(line, style, root) do
    line
    |> String.replace("\r", "")
    |> then(&Regex.split(~r/\e\[[0-9;?]*[ -\/]*[@-~]/, &1, include_captures: true))
    |> Enum.map_reduce(style, fn
      "\e[" <> sequence, style ->
        if String.ends_with?(sequence, "m"),
          do: {[], sgr(style, String.trim_trailing(sequence, "m"))},
          else: {[], style}

      "", style ->
        {[], style}

      text, style ->
        {span(style, link(text, root)), style}
    end)
  end

  # =================
  # = ANSI graphics =
  # =================

  defp sgr(style, codes) do
    codes
    |> String.split(";")
    |> Enum.map(fn
      "" -> 0
      code -> with {n, ""} <- Integer.parse(code), do: n, else: (_ -> nil)
    end)
    |> apply_codes(style)
  end

  defp apply_codes([], style), do: style
  defp apply_codes([0 | rest], _style), do: apply_codes(rest, %{})
  defp apply_codes([1 | rest], style), do: apply_codes(rest, Map.put(style, :bold, true))
  defp apply_codes([2 | rest], style), do: apply_codes(rest, Map.put(style, :faint, true))
  defp apply_codes([3 | rest], style), do: apply_codes(rest, Map.put(style, :italic, true))
  defp apply_codes([4 | rest], style), do: apply_codes(rest, Map.put(style, :underline, true))
  defp apply_codes([22 | rest], style), do: apply_codes(rest, Map.drop(style, [:bold, :faint]))
  defp apply_codes([23 | rest], style), do: apply_codes(rest, Map.delete(style, :italic))
  defp apply_codes([24 | rest], style), do: apply_codes(rest, Map.delete(style, :underline))
  defp apply_codes([39 | rest], style), do: apply_codes(rest, Map.delete(style, :fg))
  defp apply_codes([49 | rest], style), do: apply_codes(rest, Map.delete(style, :bg))

  defp apply_codes([38, 5, n | rest], style),
    do: apply_codes(rest, Map.put(style, :fg, color_256(n)))

  defp apply_codes([48, 5, n | rest], style),
    do: apply_codes(rest, Map.put(style, :bg, color_256(n)))

  defp apply_codes([38, 2, r, g, b | rest], style),
    do: apply_codes(rest, Map.put(style, :fg, {r, g, b}))

  defp apply_codes([48, 2, r, g, b | rest], style),
    do: apply_codes(rest, Map.put(style, :bg, {r, g, b}))

  defp apply_codes([n | rest], style) when n in 30..37,
    do: apply_codes(rest, Map.put(style, :fg, n - 30))

  defp apply_codes([n | rest], style) when n in 40..47,
    do: apply_codes(rest, Map.put(style, :bg, n - 40))

  defp apply_codes([n | rest], style) when n in 90..97,
    do: apply_codes(rest, Map.put(style, :fg, n - 82))

  defp apply_codes([n | rest], style) when n in 100..107,
    do: apply_codes(rest, Map.put(style, :bg, n - 92))

  defp apply_codes([_ | rest], style), do: apply_codes(rest, style)

  # The 16 basic colors are classes, so the page picks colors that suit its
  # appearance; the others are the xterm 256-color palette.
  defp color_256(n) when n < 16, do: n

  defp color_256(n) when n < 232 do
    level = fn i -> if i == 0, do: 0, else: 55 + 40 * i end
    n = n - 16
    {level.(div(n, 36)), level.(rem(div(n, 6), 6)), level.(rem(n, 6))}
  end

  defp color_256(n), do: {8 + 10 * (n - 232), 8 + 10 * (n - 232), 8 + 10 * (n - 232)}

  defp span(style, html) when style == %{}, do: html

  defp span(style, html) do
    classes =
      for {key, class} <- [bold: "b", faint: "d", italic: "i", underline: "u"],
          style[key],
          do: class

    {classes, css} =
      Enum.reduce([fg: {"f", "color"}, bg: {"g", "background-color"}], {classes, []}, fn
        {key, {prefix, property}}, {classes, css} ->
          case style[key] do
            nil -> {classes, css}
            n when is_integer(n) -> {classes ++ ["#{prefix}#{n}"], css}
            {r, g, b} -> {classes, css ++ ["#{property}: rgb(#{r}, #{g}, #{b})"]}
          end
      end)

    attributes = [
      if(classes != [], do: [" class=\"", Enum.join(classes, " "), ?"], else: []),
      if(css != [], do: [" style=\"", Enum.join(css, "; "), ?"], else: [])
    ]

    ["<span", attributes, ?>, html, "</span>"]
  end

  # ===================
  # = File references =
  # ===================

  # A file reference, optionally after the application it belongs to, as in
  # stacktraces: "(elixir 1.20.4) lib/enum.ex:1688: Enum.map/2".
  @reference ~r{(?:\((?<app>[a-z][a-z0-9_]*) [^()\s]+\) )?(?<path>(?:/|\.\.?/)?(?:[\w.@+-]+/)*[\w@+-][\w.@+-]*\.(?:exs?|heex|eex|leex|neex|erl|hrl|xrl|yrl))(?::(?<line>\d+))?(?::(?<column>\d+))?(?![\w/])}

  def link(text, root) do
    matches = Regex.scan(@reference, text, return: :index, capture: [:app, :path, :line, :column])

    {html, at} =
      Enum.flat_map_reduce(matches, 0, fn [app, {start, _} = path, line, column], at ->
        stop = Enum.max(for {from, length} <- [path, line, column], do: from + length)

        case resolve(part(text, path), part(text, app), root) do
          nil ->
            {[], at}

          file ->
            href = url(file, part(text, line), part(text, column))

            {[
               escape(slice(text, at, start)),
               ~s(<a href="),
               escape(href),
               ~s(">),
               escape(slice(text, start, stop)),
               "</a>"
             ], stop}
        end
      end)

    [html, escape(slice(text, at, byte_size(text)))]
  end

  defp part(_text, {_, 0}), do: nil
  defp part(text, {start, length}), do: binary_part(text, start, length)

  defp slice(text, from, to), do: binary_part(text, from, to - from)

  # Finds the file: relative to the project, or to where the application's
  # code is (a dependency, an umbrella application, or Elixir or Erlang/OTP).
  def resolve(path, app, root) do
    candidates =
      case Path.type(path) do
        :absolute -> [path]
        _ -> app_candidates(app, path, root) ++ [Path.join(root, path)]
      end

    candidates
    |> Enum.map(&Path.expand/1)
    |> Enum.find(&File.regular?/1)
  end

  defp app_candidates(nil, _path, _root), do: []

  defp app_candidates(app, path, root) do
    lib_dir =
      try do
        case :code.lib_dir(String.to_existing_atom(app)) do
          {:error, _} -> nil
          dir -> List.to_string(dir)
        end
      rescue
        ArgumentError -> nil
      end

    [Path.join([root, "deps", app, path]), Path.join([root, "apps", app, path])] ++
      if(lib_dir, do: [Path.join(lib_dir, path), Path.join([lib_dir, "src", path])], else: [])
  end

  defp url(file, line, column) do
    path = URI.encode(file, &(URI.char_unreserved?(&1) or &1 == ?/))
    line = if line, do: "&line=#{line}", else: ""
    column = if column, do: "&column=#{column}", else: ""
    "txmt://open?url=file://#{path}#{line}#{column}"
  end

  # ========
  # = Page =
  # ========

  def escape(text) do
    text
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    |> String.replace("\"", "&quot;")
  end

  def header(title, command, root) do
    home = System.user_home() || ""

    directory =
      if home != "" and String.starts_with?(root, home),
        do: "~" <> String.replace_prefix(root, home, ""),
        else: root

    """
    <!DOCTYPE html>
    <html>
    <head>
    <meta charset="utf-8">
    <title>#{escape(title)}</title>
    <style>
    #{css()}</style>
    </head>
    <body>
    <h1>#{escape(title)}</h1>
    <p class="meta"><code>#{escape(command)}</code> in #{escape(directory)}</p>
    <pre>\
    """
  end

  def footer(status, statuses) do
    {kind, message} =
      statuses
      |> String.split("|", trim: true)
      |> Enum.map(&String.split(&1, ":", parts: 3))
      |> Enum.find_value({"failure", "Failed with exit code #{status}."}, fn
        [code, kind, message] -> if code == Integer.to_string(status), do: {kind, message}
        _ -> nil
      end)

    ~s{</pre>\n<p class="status #{kind}">#{escape(message)}</p>\n</body>\n</html>\n}
  end

  # Terminal colors, lighter in dark mode. Black is gray there: ExUnit shows file
  # references in bold black.
  defp css do
    """
    :root { color-scheme: light dark;
      --c0: #000000; --c1: #c4291e; --c2: #1f8a1f; --c3: #9a6f00; --c4: #1f4fd1; --c5: #a326a3; --c6: #00808a; --c7: #6e6e6e;
      --c8: #6e6e6e; --c9: #e0392b; --c10: #25a825; --c11: #b58900; --c12: #3d6ff0; --c13: #c238c2; --c14: #0098a3; --c15: #3a3a3a; }
    @media (prefers-color-scheme: dark) { :root {
      --c0: #9a9a9a; --c1: #ff6b61; --c2: #5fd35f; --c3: #e8c15a; --c4: #6f9dff; --c5: #e47de4; --c6: #4fcfd8; --c7: #d0d0d0;
      --c8: #9a9a9a; --c9: #ff8a82; --c10: #7fe07f; --c11: #f0d36e; --c12: #92b4ff; --c13: #ee9cee; --c14: #74dde4; --c15: #ffffff; } }
    body { font: 13px -apple-system, sans-serif; margin: 1.5em; }
    h1 { font-size: 1.3em; margin: 0 0 .2em; }
    .meta { color: GrayText; margin: 0 0 1em; }
    pre { font: 12px ui-monospace, Menlo, monospace; white-space: pre-wrap; margin: 0; }
    pre a { color: inherit; text-decoration: underline; text-decoration-color: color-mix(in srgb, currentColor 40%, transparent); }
    pre a:hover { text-decoration-color: currentColor; }
    .status { margin-top: 1em; font-weight: 600; }
    .success { color: var(--c2); }
    .failure { color: var(--c1); }
    .b { font-weight: bold; } .d { opacity: .65; } .i { font-style: italic; } .u { text-decoration: underline; }
    #{for n <- 0..15, into: "", do: ".f#{n} { color: var(--c#{n}); } "}
    #{for n <- 0..15, into: "", do: ".g#{n} { background-color: color-mix(in srgb, var(--c#{n}) 30%, transparent); } "}
    """
  end
end
