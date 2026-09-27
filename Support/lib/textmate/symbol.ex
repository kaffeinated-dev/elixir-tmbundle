defmodule TextMate do
  @moduledoc false

  # Makes the project's compiled code and its dependencies available, without
  # compiling, as `mix help` does.
  def load_paths do
    if Mix.Project.get() do
      args = [
        "--no-elixir-version-check",
        "--no-deps-check",
        "--no-archives-check",
        "--no-listeners"
      ]

      Mix.Task.run("loadpaths", args)
    end
  end

  # The scope of a template is that of its module: page_html/home.html.heex is
  # embedded by page_html.ex, and user_live.html.heex is user_live.ex's.
  def template_env(file) do
    if is_binary(file) and String.ends_with?(file, ".heex") do
      dir = Path.dirname(file)
      base = file |> Path.basename() |> String.split(".") |> hd()

      [Path.join(dir, base <> ".ex"), dir <> ".ex"]
      |> Enum.find(&File.regular?/1)
      |> case do
        nil -> nil
        module -> module |> File.read!() |> TextMate.Symbol.file_env()
      end
    end
  end

  # The document on the standard input.
  def read_document do
    case IO.binread(:stdio, :eof) do
      :eof -> ""
      document -> document
    end
  end
end

defmodule TextMate.Symbol do
  @moduledoc false

  # Finds what the code at the caret refers to, for its documentation and
  # definition. The aliases, imports, and uses in scope come from the code
  # before the caret, and from the source of modules it uses: Phoenix's
  # `use MyAppWeb, :live_view` imports and aliases what MyAppWeb's quotes do.
  #
  # A target is {:module, module}, {:function, module, name, arity} (module is
  # nil for a local call, arity nil when unknown), or {:attribute, name}.

  defstruct module: nil, aliases: %{}, imports: [], uses: []

  # The target at the caret, given as TextMate does (a 1-based line, and the
  # 0-based byte index in it), and the scope. A caret just after a name is on
  # it. The scope of a template (a .heex file) is that of its module.
  def at(document, line, index, env \\ nil) do
    text = document |> String.split("\n") |> Enum.at(line - 1, "")
    column = length(String.to_charlist(binary_part(text, 0, min(index, byte_size(text))))) + 1
    env = env || env(document, {line, column})

    case component(text, index) do
      {nil, name} ->
        {{:function, nil, name, 1}, env}

      {module, name} ->
        {{:function, expand(module, env), name, 1}, env}

      nil ->
        context =
          case Code.Fragment.surround_context(document, {line, column}) do
            :none when column > 1 -> Code.Fragment.surround_context(document, {line, column - 1})
            context -> context
          end

        case context do
          %{context: context, end: {end_line, end_column}} ->
            {with_arity(target(context, env), arity_after(document, end_line, end_column)), env}

          :none ->
            {nil, env}
        end
    end
  end

  # A HEEx component at the byte index: <.local> or <Module.function>.
  defp component(text, index) do
    ~r{</?(\.[a-z_]\w*[?!]?|(?:[A-Z]\w*\.)+[a-z_]\w*[?!]?)}
    |> Regex.scan(text, return: :index, capture: :all_but_first)
    |> Enum.find_value(fn [{start, length}] ->
      if index >= start and index <= start + length do
        case binary_part(text, start, length) do
          "." <> name ->
            {nil, String.to_atom(name)}

          name ->
            {module, [function]} = name |> String.split(".") |> Enum.split(-1)
            {Enum.join(module, "."), String.to_atom(function)}
        end
      end
    end)
  end

  # The scope of a whole file: its first module's.
  def file_env(text) do
    case Code.string_to_quoted(text) do
      {:ok, ast} -> ast |> walk(%__MODULE__{}, false) |> add_uses()
      _ -> %__MODULE__{}
    end
  end

  # The target of a reference such as "Enum.map/2", "Enum", ":lists.map", or "map/2".
  def parse(reference, env \\ %__MODULE__{}) do
    {reference, arity} =
      case Regex.run(~r{^(.+)/(\d+)$}, String.trim(reference)) do
        [_, reference, arity] -> {reference, String.to_integer(arity)}
        nil -> {String.trim(reference), nil}
      end

    case Code.Fragment.surround_context(reference, {1, String.length(reference)}) do
      %{context: context} -> with_arity(target(context, env), arity)
      :none -> nil
    end
  end

  defp with_arity({:function, module, name, _}, arity) when is_integer(arity),
    do: {:function, module, name, arity}

  defp with_arity(target, _arity), do: target

  defp target({:alias, name}, env), do: {:module, expand(name, env)}

  defp target({:alias, inside, name}, env),
    do: module_target(module_of({:alias, inside, name}, env))

  defp target({:struct, name}, env) when is_list(name), do: {:module, expand(name, env)}
  defp target({:struct, inside}, env), do: target(inside, env)
  defp target({:local_or_var, ~c"__MODULE__"}, env), do: module_target(env.module)
  defp target({:unquoted_atom, name}, _env), do: {:module, List.to_atom(name)}
  defp target({:module_attribute, name}, _env), do: {:attribute, List.to_atom(name)}
  defp target({:sigil, name}, _env), do: {:function, nil, :"sigil_#{name}", 2}

  defp target({kind, inside, name}, env) when kind in [:dot, :dot_arity, :dot_call] do
    case module_of(inside, env) do
      nil -> nil
      module -> {:function, module, List.to_atom(name), nil}
    end
  end

  defp target({kind, name}, _env)
       when kind in [
              :local_or_var,
              :local_arity,
              :local_call,
              :operator,
              :operator_arity,
              :operator_call
            ],
       do: {:function, nil, List.to_atom(name), nil}

  defp target(_context, _env), do: nil

  defp module_target(nil), do: nil
  defp module_target(module), do: {:module, module}

  defp module_of({:alias, name}, env), do: expand(name, env)

  defp module_of({:alias, {:local_or_var, ~c"__MODULE__"}, name}, %{module: module})
       when module != nil,
       do: Module.concat(module, List.to_string(name))

  defp module_of({:unquoted_atom, name}, _env), do: List.to_atom(name)
  defp module_of({:local_or_var, ~c"__MODULE__"}, env), do: env.module
  defp module_of(_inside, _env), do: nil

  # The arity written after the name, as in &Enum.map/2.
  defp arity_after(document, line, column) do
    rest =
      document |> String.split("\n") |> Enum.at(line - 1, "") |> String.slice((column - 1)..-1//1)

    case Regex.run(~r{^/(\d+)}, rest) do
      [_, arity] -> String.to_integer(arity)
      nil -> nil
    end
  end

  # Expands an alias ("Repo.Query") with the aliases in scope.
  def expand(name, env) when is_list(name), do: expand(List.to_string(name), env)

  def expand(name, env) do
    [first | rest] = String.split(name, ".")

    case env.aliases do
      %{^first => module} -> Module.concat([module | rest])
      _ -> Module.concat([name])
    end
  end

  # =========
  # = Scope =
  # =========

  def env(document, {line, column}) do
    before =
      document
      |> String.split("\n")
      |> Enum.take(line)
      |> List.update_at(line - 1, &String.slice(&1, 0, column - 1))
      |> Enum.join("\n")

    ast =
      case Code.Fragment.container_cursor_to_quoted(before) do
        {:ok, ast} ->
          ast

        _ ->
          case Code.string_to_quoted(document) do
            {:ok, ast} -> ast
            _ -> nil
          end
      end

    ast
    |> walk(%__MODULE__{}, cursor?(ast))
    |> add_uses()
  end

  # Without the caret (when only the whole document parses), every module counts.
  defp walk({:defmodule, _, [name, [{:do, body} | _]]}, env, cursor) do
    module = defined_module(name, env)

    env =
      case {env.module, name} do
        {parent, {:__aliases__, _, [first | _]}} when parent != nil and is_atom(first) ->
          put_alias(env, Atom.to_string(first), Module.concat(parent, first))

        _ ->
          env
      end

    cond do
      cursor and cursor?(body) ->
        walk(body, %{env | module: module}, cursor)

      cursor ->
        env

      true ->
        body
        |> walk(%{env | module: env.module || module}, cursor)
        |> Map.put(:module, env.module || module)
    end
  end

  defp walk({:alias, _, [target | rest]}, env, _cursor),
    do: add_alias(env, target, List.first(rest, []))

  defp walk({:import, _, [target | _]}, env, _cursor), do: add_module(env, :imports, target)

  defp walk({:use, _, [target | rest]}, env, _cursor) do
    case {module_ast(target, env), rest} do
      {nil, _} -> env
      {module, [which | _]} when is_atom(which) -> %{env | uses: env.uses ++ [{module, which}]}
      {module, _} -> %{env | uses: env.uses ++ [{module, :__using__}]}
    end
  end

  defp walk({_, _, args}, env, cursor) when is_list(args), do: walk(args, env, cursor)
  defp walk({left, right}, env, cursor), do: walk(right, walk(left, env, cursor), cursor)

  defp walk(list, env, cursor) when is_list(list),
    do: Enum.reduce(list, env, &walk(&1, &2, cursor))

  defp walk(_ast, env, _cursor), do: env

  defp cursor?({:__cursor__, _, _}), do: true

  defp cursor?({left, _, args}) when is_list(args),
    do: cursor?(left) or Enum.any?(args, &cursor?/1)

  defp cursor?({left, right}), do: cursor?(left) or cursor?(right)
  defp cursor?(list) when is_list(list), do: Enum.any?(list, &cursor?/1)
  defp cursor?(_ast), do: false

  defp defined_module({:__aliases__, _, parts} = name, env) do
    if env.module && Enum.all?(parts, &is_atom/1),
      do: Module.concat([env.module | parts]),
      else: module_ast(name, env)
  end

  defp defined_module(name, env), do: module_ast(name, env)

  defp add_alias(env, {{:., _, [base, :{}]}, _, children}, _options) do
    base = module_ast(base, env)

    Enum.reduce(children, env, fn
      {:__aliases__, _, parts}, env when base != nil ->
        put_alias(env, Atom.to_string(List.last(parts)), Module.concat([base | parts]))

      _, env ->
        env
    end)
  end

  defp add_alias(env, target, options) do
    with module when module != nil <- module_ast(target, env) do
      name =
        case options do
          [as: {:__aliases__, _, [as]}] -> Atom.to_string(as)
          _ -> module |> Module.split() |> List.last()
        end

      put_alias(env, name, module)
    else
      _ -> env
    end
  rescue
    ArgumentError -> env
  end

  defp put_alias(env, name, module), do: %{env | aliases: Map.put(env.aliases, name, module)}

  defp add_module(env, key, target) do
    case module_ast(target, env) do
      nil -> env
      module -> Map.update!(env, key, &(&1 ++ [module]))
    end
  end

  defp module_ast({:__aliases__, _, [{:__MODULE__, _, _} | rest]}, %{module: module})
       when module != nil,
       do: Module.concat([module | rest])

  defp module_ast({:__aliases__, _, parts}, env) do
    if Enum.all?(parts, &is_atom/1), do: expand(Enum.map_join(parts, ".", &Atom.to_string/1), env)
  end

  defp module_ast({:__MODULE__, _, _}, env), do: env.module
  defp module_ast(atom, _env) when is_atom(atom), do: atom
  defp module_ast(_ast, _env), do: nil

  # What `use Module` brings: the imports, aliases, and uses in its __using__
  # macro, or for `use Module, :which` in its `which` function, and in the
  # functions they call (such as Phoenix's html_helpers). Uses in there count
  # too, a few levels deep.
  defp add_uses(env), do: add_uses(env, env.uses, MapSet.new(), 3)

  defp add_uses(env, [], _seen, _depth),
    do: %{env | uses: Enum.uniq(Enum.map(env.uses, &used_module/1))}

  defp add_uses(env, _uses, _seen, 0), do: add_uses(env, [], nil, nil)

  defp add_uses(env, uses, seen, depth) do
    {env, nested} =
      Enum.reduce(uses, {env, []}, fn use, {env, nested} ->
        if use in seen do
          {env, nested}
        else
          found = used(use)
          aliases = Map.merge(found.aliases, env.aliases)

          {%{
             env
             | imports: env.imports ++ found.imports,
               aliases: aliases,
               uses: env.uses ++ found.uses
           }, nested ++ found.uses}
        end
      end)

    add_uses(env, nested, MapSet.union(seen, MapSet.new(uses)), depth - 1)
  end

  defp used_module({module, _which}), do: module
  defp used_module(module), do: module

  defp used({module, which}) do
    empty = %__MODULE__{module: module}

    with file when file != nil <- find_source(module),
         {:ok, text} <- File.read(file),
         {:ok, ast} <- Code.string_to_quoted(text) do
      definitions = definitions(ast)
      bodies = bodies(definitions, which, MapSet.new())
      bodies = if which == :__using__, do: bodies ++ using_blocks(ast), else: bodies
      found = walk(bodies, empty, false)

      # A case template's users also use ExUnit.Case.
      found =
        if text =~ ~r/^\s*use ExUnit\.CaseTemplate\b/m,
          do: %{found | uses: [{ExUnit.Case, :__using__} | found.uses]},
          else: found

      Map.update!(found, :uses, &Enum.uniq/1)
    else
      _ -> empty
    end
  end

  # The blocks of ExUnit.CaseTemplate's `using do … end`, its __using__.
  defp using_blocks(ast) do
    {_, blocks} =
      Macro.prewalk(ast, [], fn
        {:using, _, [_ | _] = args} = node, acc -> {node, acc ++ [List.last(args)]}
        node, acc -> {node, acc}
      end)

    blocks
  end

  # The bodies of the functions and macros in a module's source, by name.
  defp definitions(ast) do
    {_, definitions} =
      Macro.prewalk(ast, %{}, fn
        {kind, _, [head, [{:do, body} | _]]} = node, acc
        when kind in [:def, :defp, :defmacro, :defmacrop] ->
          {node, Map.update(acc, name(head), [body], &(&1 ++ [body]))}

        node, acc ->
          {node, acc}
      end)

    definitions
  end

  defp name({:when, _, [head | _]}), do: name(head)
  defp name({name, _, _}), do: name

  # A function's bodies and those of the local functions they call. Quoted code
  # is included, unquoted calls too (unquote(html_helpers())).
  defp bodies(definitions, name, seen) do
    Enum.flat_map(Map.get(definitions, name, []), fn body ->
      {_, calls} =
        Macro.prewalk(body, [], fn
          {call, _, args} = node, acc when is_atom(call) and is_list(args) ->
            if Map.has_key?(definitions, call), do: {node, [call | acc]}, else: {node, acc}

          node, acc ->
            {node, acc}
        end)

      called = Enum.reject(Enum.uniq(calls), &(&1 in seen or &1 == name))
      seen = MapSet.union(seen, MapSet.new([name | called]))
      [body | Enum.flat_map(called, &bodies(definitions, &1, seen))]
    end)
  end

  # ===============
  # = Resolution =
  # ===============

  # The module a local call refers to: the current module, what is imported
  # (explicitly or by uses), or Kernel.
  def resolve({:function, nil, name, arity}, env) do
    candidates =
      Enum.reject(
        [env.module | env.imports ++ env.uses] ++ [Kernel, Kernel.SpecialForms],
        &is_nil/1
      )

    candidates = Enum.uniq(candidates)

    case Enum.find(candidates, &exports?(&1, name, arity)) do
      nil -> {:function, nil, name, arity}
      module -> {:function, module, name, arity}
    end
  end

  def resolve(target, _env), do: target

  def exports?(module, name, arity) do
    Code.ensure_loaded?(module) and
      Enum.any?(exports(module), fn {n, a} -> n == name and (arity == nil or a == arity) end)
  end

  defp exports(module) do
    if function_exported?(module, :__info__, 1),
      do: module.__info__(:functions) ++ module.__info__(:macros),
      else: module.module_info(:exports)
  end

  # ===========
  # = Sources =
  # ===========

  # The source file of a compiled module: where it was compiled, or for code
  # compiled elsewhere (Elixir, Erlang/OTP), next to where it is installed.
  def source_file(module) do
    with {:module, _} <- Code.ensure_loaded(module),
         [_ | _] = source <- module.module_info(:compile)[:source] do
      source = List.to_string(source)

      installed =
        case :code.which(module) do
          [_ | _] = beam ->
            [
              Path.join(
                beam |> List.to_string() |> Path.dirname() |> Path.dirname(),
                from_lib_or_src(source)
              )
            ]

          _ ->
            []
        end

      [source | installed] |> Enum.map(&Path.expand/1) |> Enum.find(&File.regular?/1)
    else
      _ -> nil
    end
  end

  # The source of a module: compiled, or a file in the project (the current
  # directory) that defines it, such as test support modules, which are only
  # compiled for tests.
  def find_source(module) do
    source_file(module) || project_file(module, File.cwd!())
  end

  defp project_file(module, root) do
    if match?("Elixir." <> _, Atom.to_string(module)) do
      pattern = ~r/^\s*defmodule\s+#{Regex.escape(inspect(module))}\s+do\b/m

      ["lib", "test", "config", "apps/*/lib", "apps/*/test"]
      |> Enum.flat_map(&Path.wildcard(Path.join([root, &1, "**", "*.{ex,exs}"])))
      |> Enum.find(&(File.read!(&1) =~ pattern))
    end
  end

  defp from_lib_or_src(source) do
    {in_dir, rest} =
      source |> Path.split() |> Enum.reverse() |> Enum.split_while(&(&1 not in ["lib", "src"]))

    case rest do
      [dir | _] -> Path.join([dir | Enum.reverse(in_dir)])
      [] -> source
    end
  end
end
