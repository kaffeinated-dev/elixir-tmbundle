defmodule TextMate.Docs do
  @moduledoc false

  alias TextMate.{Definition, Markdown, Symbol}

  # The documentation of a target as HTML: {:ok, title, html} or {:error,
  # message}. A function's documentation is that of each of its arities (or
  # of the type or callback of that name), with its specs and a link to its
  # source. Code that names a module or function links to its documentation.

  def render(nil, _env, _root), do: {:error, "No module or function here."}
  def render({:attribute, name}, _env, _root), do: {:error, "No documentation for @#{name}."}

  def render({:function, nil, name, arity} = target, env, root) do
    case Symbol.resolve(target, env) do
      {:function, nil, _, _} ->
        {:error,
         "#{name}#{arity_suffix(arity)} is not imported here, or its module is not compiled."}

      resolved ->
        render(resolved, env, root)
    end
  end

  def render({:module, module}, _env, root) do
    with {:ok, docs} <- fetch(module) do
      {:docs_v1, _, _, format, moduledoc, metadata, entries} = docs
      link = &link(&1, module)

      summary =
        for {title, kinds} <- [
              {"Types", [:type, :opaque]},
              {"Callbacks", [:callback, :macrocallback]},
              {"Functions", [:function, :macro]}
            ],
            entries = Enum.filter(entries, &(kind(&1) in kinds and visible?(&1))),
            entries != [] do
          [
            "<h2>#{title}</h2>\n<dl class=\"summary\">\n",
            for {{_kind, name, arity}, _, _, doc, _} <- Enum.sort_by(entries, &elem(&1, 0)) do
              reference = "#{inspect(module)}.#{name}/#{arity}"

              [
                ~s(<dt><a href="#" data-reference="),
                escape(reference),
                ~s("><code>),
                escape("#{name}/#{arity}"),
                "</code></a></dt>\n",
                "<dd>",
                summary(doc, format, link),
                "</dd>\n"
              ]
            end,
            "</dl>\n"
          ]
        end

      html = [
        heading(inspect(module), source_link({:module, module}, root)),
        notes(metadata),
        doc(moduledoc, format, link, "No documentation for this module."),
        summary
      ]

      {:ok, inspect(module), IO.iodata_to_binary(html)}
    end
  end

  def render({:function, module, name, arity}, _env, root) do
    with {:ok, {:docs_v1, _, _, format, _, _, entries}} <- fetch(module) do
      matching = fn kinds ->
        Enum.filter(entries, fn {{kind, n, a}, _, _, _, _} ->
          kind in kinds and n == name and (arity == nil or a == arity)
        end)
      end

      entries =
        Enum.find(
          [
            matching.([:function, :macro]),
            matching.([:type, :opaque]),
            matching.([:callback, :macrocallback])
          ],
          [],
          &(&1 != [])
        )

      title = "#{inspect(module)}.#{name}#{arity_suffix(arity)}"

      # An implementation of a callback (with @impl, so @doc false) shows the callback's.
      callback =
        if entries != [] and
             Enum.all?(entries, fn {_, _, _, doc, _} -> doc in [:hidden, :none] end) do
          module
          |> behaviours()
          |> Enum.find(fn behaviour ->
            match?({:ok, _, _}, render({:function, behaviour, name, arity}, nil, root)) and
              Code.ensure_loaded?(behaviour) and function_exported?(behaviour, :behaviour_info, 1) and
              Enum.any?(behaviour.behaviour_info(:callbacks), fn {n, a} ->
                n == name and (arity == nil or a == arity)
              end)
          end)
        end

      cond do
        callback ->
          {:ok, title, html} = render({:function, callback, name, arity}, nil, root)

          note = [
            "<p class=\"since\">",
            escape("#{inspect(module)} implements this callback."),
            "</p>\n"
          ]

          [heading, rest] = String.split(html, "</h1>\n", parts: 2)
          {:ok, title, IO.iodata_to_binary([heading, "</h1>\n", note, rest])}

        entries == [] ->
          {:error, "No documentation for #{title}."}

        true ->
          link = &link(&1, module)
          specs = specs(module, entries)

          sections =
            for {{kind, n, a}, _, signature, doc, metadata} = entry <-
                  Enum.sort_by(entries, &elem(&1, 0)) do
              signature = if signature == [], do: ["#{n}/#{a}"], else: signature

              [
                ~s(<section>\n<h2 class="signature"><code>),
                Enum.map_join(signature, "<br>", &escape/1),
                "</code>",
                source_link(target(module, kind, n, a), root),
                "</h2>\n",
                Enum.map(
                  Map.get(specs, {kind(entry), n, a}, []),
                  &["<pre class=\"spec\"><code>", escape(&1), "</code></pre>\n"]
                ),
                notes(metadata),
                doc(doc, format, link, "No documentation."),
                "</section>\n"
              ]
            end

          {:ok, title, IO.iodata_to_binary([heading(title, ""), sections])}
      end
    end
  end

  defp behaviours(module) do
    if Code.ensure_loaded?(module),
      do: module.module_info(:attributes) |> Keyword.get_values(:behaviour) |> List.flatten(),
      else: []
  end

  defp fetch(module) do
    case Code.fetch_docs(module) do
      {:docs_v1, _, _, _, _, _, _} = docs ->
        {:ok, docs}

      {:error, :module_not_found} ->
        {:error, "#{inspect(module)} is not compiled, or doesn’t exist."}

      {:error, _} ->
        {:error, "#{inspect(module)} has no documentation."}
    end
  end

  defp kind({{kind, _, _}, _, _, _, _}), do: kind
  defp visible?({_, _, _, doc, _}), do: doc != :hidden

  defp target(module, kind, name, arity) when kind in [:function, :macro],
    do: {:function, module, name, arity}

  defp target(module, _kind, _name, _arity), do: {:module, module}

  defp heading(title, links),
    do: [~s(<h1 data-title="), escape(title), ~s(">), escape(title), links, "</h1>\n"]

  defp source_link(target, root) do
    case Definition.find(target, %Symbol{}, "", nil, root) do
      {:ok, file, line} when is_binary(file) ->
        url =
          "txmt://open?url=file://#{URI.encode(file, &(URI.char_unreserved?(&1) or &1 == ?/))}&line=#{line}"

        [
          ~s( <a class="source" href="),
          escape(url),
          ~s(" title="),
          escape("#{Path.relative_to(file, root)}:#{line}"),
          ~s(">source</a>)
        ]

      _ ->
        []
    end
  end

  defp notes(metadata) do
    [
      if(deprecated = metadata[:deprecated],
        do: ["<p class=\"deprecated\">Deprecated: ", escape(deprecated), "</p>\n"],
        else: []
      ),
      if(since = metadata[:since],
        do: ["<p class=\"since\">Since ", escape(since), "</p>\n"],
        else: []
      )
    ]
  end

  defp doc(%{"en" => text}, "text/markdown", link, _none), do: Markdown.to_html(text, link)

  defp doc(%{"en" => _}, format, _link, _none),
    do: [
      "<p class=\"none\">The documentation is in a format that can’t be shown (",
      escape(format),
      ").</p>\n"
    ]

  defp doc(:hidden, _format, _link, _none),
    do: "<p class=\"none\">Not documented (<code>@doc false</code>).</p>\n"

  defp doc(_none, _format, _link, message), do: ["<p class=\"none\">", message, "</p>\n"]

  # The first paragraph, for summaries.
  defp summary(%{"en" => text}, "text/markdown", link) do
    text |> String.split(~r/\n\s*\n/, parts: 2) |> hd() |> Markdown.inline(link)
  end

  defp summary(_doc, _format, _link), do: []

  # Specs by {kind, name, arity}: of functions, macros (without their caller
  # argument), types, and callbacks.
  defp specs(module, entries) do
    kinds = entries |> Enum.map(&kind/1) |> Enum.uniq()

    [
      if(Enum.any?(kinds, &(&1 in [:function, :macro])), do: function_specs(module), else: []),
      if(Enum.any?(kinds, &(&1 in [:type, :opaque])), do: type_specs(module), else: []),
      if(Enum.any?(kinds, &(&1 in [:callback, :macrocallback])),
        do: callback_specs(module),
        else: []
      )
    ]
    |> List.flatten()
    |> Enum.group_by(fn {key, _} -> key end, fn {_, spec} -> spec end)
  end

  defp function_specs(module) do
    case Code.Typespec.fetch_specs(module) do
      {:ok, specs} ->
        for {{name, arity}, specs} <- specs, spec <- specs do
          case Atom.to_string(name) do
            "MACRO-" <> macro ->
              name = String.to_atom(macro)
              {{:macro, name, arity - 1}, "@spec " <> spec_string(name, drop_caller(spec))}

            _ ->
              {{:function, name, arity}, "@spec " <> spec_string(name, spec)}
          end
        end

      :error ->
        []
    end
  end

  defp drop_caller({:type, line, :fun, [{:type, args_line, :product, [_caller | args]}, result]}),
    do: {:type, line, :fun, [{:type, args_line, :product, args}, result]}

  defp drop_caller(spec), do: spec

  defp type_specs(module) do
    case Code.Typespec.fetch_types(module) do
      {:ok, types} ->
        for {kind, {name, _, args} = type} <- types, kind in [:type, :opaque] do
          quoted =
            if kind == :opaque,
              do: {name, [], Enum.map(args, fn _ -> {:_, [], nil} end)},
              else: Code.Typespec.type_to_quoted(type)

          {{kind, name, length(args)}, "@#{kind} " <> Macro.to_string(quoted)}
        end

      :error ->
        []
    end
  end

  defp callback_specs(module) do
    case Code.Typespec.fetch_callbacks(module) do
      {:ok, callbacks} ->
        for {{name, arity}, specs} <- callbacks, spec <- specs do
          {{:callback, name, arity}, "@callback " <> spec_string(name, spec)}
        end

      :error ->
        []
    end
  end

  defp spec_string(name, spec),
    do: name |> Code.Typespec.spec_to_quoted(spec) |> Macro.to_string()

  # What inline code in the documentation of a module links to: modules, and
  # functions, types (t:), and callbacks (c:), in that module or others.
  def link(code, module) do
    {kind, code} =
      case Regex.run(~r/^([tcm]):(.*)$/, code) do
        [_, kind, code] -> {kind, code}
        nil -> {nil, code}
      end

    case Regex.run(
           ~r/^(?:((?:[A-Z]\w*\.)*[A-Z]\w*|:\w+)\.)?([a-z_]\w*[?!]?|[^\w\s.\/()\[\]{}"'`,]+)\/(\d+)$/,
           code
         ) do
      # Types and callbacks of the module.
      [_, "", name, arity] when kind in ["t", "c"] ->
        "#{inspect(module)}.#{name}/#{arity}"

      [_, "", name, arity] ->
        owner =
          Enum.find([module, Kernel, Kernel.SpecialForms], fn owner ->
            Symbol.exports?(owner, String.to_atom(name), String.to_integer(arity))
          end)

        if owner, do: "#{inspect(owner)}.#{name}/#{arity}"

      [_, owner, name, arity] ->
        if loaded?(owner), do: "#{owner}.#{name}/#{arity}"

      nil ->
        if code =~ ~r/^(?:[A-Z]\w*\.)*[A-Z]\w*$/ and loaded?(code), do: code
    end
  end

  defp loaded?(":" <> module), do: Code.ensure_loaded?(String.to_atom(module))
  defp loaded?(module), do: Code.ensure_loaded?(Module.concat([module]))

  defp arity_suffix(nil), do: ""
  defp arity_suffix(arity), do: "/#{arity}"

  defp escape(text), do: Markdown.escape(to_string(text))

  # ========
  # = Page =
  # ========

  # The page for TextMate's HTML window. Links to other documentation show it
  # in the page, by running Support/bin/elixir-docs.
  def page(title, html) do
    """
    <!DOCTYPE html>
    <html>
    <head>
    <meta charset="utf-8">
    <title>#{escape(title)}</title>
    <style>
    :root { color-scheme: light dark; --muted: #6e6e6e; --code: rgba(127, 127, 127, .12); --link: #1f5fd1; --line: rgba(127, 127, 127, .3); }
    @media (prefers-color-scheme: dark) { :root { --muted: #9a9a9a; --link: #7aa7ff; } }
    body { font: 14px/1.5 -apple-system, sans-serif; margin: 1.5em 2em; max-width: 52em; }
    body.busy, body.busy a { cursor: progress; }
    nav { margin-bottom: 1em; }
    nav a, #docs a { color: var(--link); text-decoration: none; }
    nav a:hover, #docs a:hover { text-decoration: underline; }
    nav .error { color: #d33; margin-left: 1em; }
    h1 { font-size: 1.6em; margin: 0 0 .6em; }
    h2 { font-size: 1.25em; margin: 1.6em 0 .5em; }
    h3, h4, h5, h6 { font-size: 1.05em; margin: 1.4em 0 .4em; }
    h2.signature { font-size: 1.05em; border-top: 1px solid var(--line); padding-top: 1em; }
    a.source { font: 12px -apple-system, sans-serif; margin-left: .8em; }
    code, pre { font: 12.5px/1.45 ui-monospace, Menlo, monospace; }
    code { background: var(--code); border-radius: 3px; padding: .05em .25em; }
    pre { background: var(--code); border-radius: 5px; padding: .7em .9em; overflow-x: auto; }
    pre code, h2 code, dt code { background: none; padding: 0; }
    pre.spec { background: none; padding: 0 0 0 .2em; margin: .2em 0; color: var(--muted); }
    blockquote { margin: 1em 0; padding: .1em 1em; border-left: 3px solid var(--line); }
    blockquote.admonition { border-left-color: #1f8a9a; background: var(--code); }
    blockquote.warning, blockquote.error { border-left-color: #d98c00; }
    blockquote .title { font-weight: 600; }
    table { border-collapse: collapse; } th, td { border: 1px solid var(--line); padding: .3em .6em; text-align: left; }
    dl.summary dt { margin-top: .6em; } dl.summary dd { margin-left: 1.5em; color: var(--muted); }
    .deprecated { color: #d33; } .since, .none { color: var(--muted); }
    </style>
    </head>
    <body>
    <nav><a class="back" href="#" hidden>← Back</a><span class="error"></span></nav>
    <div id="docs">
    #{html}
    </div>
    <script>
    (function () {
      var docs = document.getElementById("docs"), back = document.querySelector("nav .back"), error = document.querySelector("nav .error"), history = [];
      function quote(text) { return "'" + text.replace(/'/g, "'\\\\''") + "'"; }
      function show(html) {
        docs.innerHTML = html;
        var heading = docs.querySelector("[data-title]");
        if (heading) document.title = heading.getAttribute("data-title");
        back.hidden = history.length == 0;
        window.scrollTo(0, 0);
      }
      document.addEventListener("click", function (event) {
        var link = event.target.closest("a[data-reference], a.back");
        if (!link) return;
        event.preventDefault();
        if (link == back) { if (history.length) show(history.pop()); return; }
        if (!window.TextMate || document.body.classList.contains("busy")) return;
        document.body.classList.add("busy");
        error.textContent = "";
        TextMate.system('"$TM_BUNDLE_SUPPORT/bin/elixir-docs" ' + quote(link.getAttribute("data-reference")), function (task) {
          document.body.classList.remove("busy");
          if (task.status == 0) { history.push(docs.innerHTML); show(task.outputString); }
          else error.textContent = task.errorString.trim().split("\\n").pop();
        });
      });
    })();
    </script>
    </body>
    </html>
    """
  end
end

defmodule Mix.Tasks.Textmate.Docs do
  use Mix.Task

  @moduledoc false

  # Prints the documentation of the code at the caret (TM_LINE_NUMBER and
  # TM_LINE_INDEX) of the file, whose document is the standard input, as a
  # page for TextMate's HTML window; or of a reference, as the page or just its
  # documentation (for links in the page).
  #
  #     elixir -r load.exs -S mix textmate.docs page FILE LINE INDEX
  #     elixir -r load.exs -S mix textmate.docs page|html --reference Enum.map/2

  @impl true
  def run([format | args]) do
    TextMate.load_paths()

    {target, env} =
      case args do
        ["--reference", reference] ->
          {TextMate.Symbol.parse(reference), %TextMate.Symbol{}}

        [file, line, index] ->
          document = TextMate.read_document()
          file = if file == "", do: nil, else: Path.expand(file)

          TextMate.Symbol.at(
            document,
            String.to_integer(line),
            String.to_integer(index),
            TextMate.template_env(file)
          )
      end

    case TextMate.Docs.render(target, env, File.cwd!()) do
      {:ok, title, html} when format == "page" -> IO.binwrite(TextMate.Docs.page(title, html))
      {:ok, _title, html} -> IO.binwrite(html)
      {:error, message} -> fail(message)
    end
  rescue
    exception -> fail("Couldn’t show the documentation: " <> Exception.message(exception))
  end

  defp fail(message) do
    IO.binwrite(:stderr, [message, ?\n])
    exit({:shutdown, 1})
  end
end
