defmodule TextMate.Definition do
  @moduledoc false

  alias TextMate.Symbol

  # Where a target is defined: {:ok, file, line} or {:error, message}. Source
  # files are searched as they are now (the current file as it is in the
  # editor), so the line is right even before the code is compiled again.
  def find(target, env, document, file, root)

  def find(nil, _env, _document, _file, _root),
    do: {:error, "No module, function, or attribute here."}

  def find({:attribute, name}, _env, document, file, _root) do
    case line_matching(document, ~r/^\s*@#{Regex.escape(Atom.to_string(name))}(?![\w?!])/) do
      nil -> {:error, "@#{name} is not set in this file."}
      line -> {:ok, file, line}
    end
  end

  def find({:function, nil, name, arity} = target, env, document, file, root) do
    case line_matching(document, definition(name)) do
      nil ->
        case Symbol.resolve(target, env) do
          {:function, nil, _, _} ->
            {:error, "#{name}#{arity_suffix(arity)} is not defined here or imported."}

          resolved ->
            find(resolved, env, document, file, root)
        end

      line ->
        {:ok, file, line}
    end
  end

  def find({:function, module, name, arity}, _env, document, file, root) do
    with {:ok, source, text} <- source(module, document, file, root) do
      start = module_line(text, module) || 1

      pattern =
        if elixir?(module),
          do: definition(name),
          else: ~r/^'?#{Regex.escape(Atom.to_string(name))}'?\(/

      line =
        line_matching(text, pattern, start) || compiled_line(module, name, arity) ||
          start

      {:ok, source, line}
    else
      {:error, _} ->
        {:error, "Can’t find the source of #{inspect(module)}.#{name}#{arity_suffix(arity)}."}
    end
  end

  def find({:module, module}, _env, document, file, root) do
    case source(module, document, file, root) do
      {:ok, source, text} -> {:ok, source, module_line(text, module) || 1}
      {:error, _} -> {:error, "Can’t find the source of #{inspect(module)}."}
    end
  end

  # The module's source file and its text: the current document if that's the
  # file, the file it was compiled from, or a file in the project that defines it.
  defp source(module, document, file, root) do
    case File.cd!(root, fn -> Symbol.find_source(module) end) do
      nil -> {:error, :not_found}
      ^file when is_binary(file) -> {:ok, file, document}
      source -> {:ok, source, File.read!(source)}
    end
  end

  defp module_line(text, module) do
    if elixir?(module) do
      last = module |> Module.split() |> List.last() |> Regex.escape()
      line_matching(text, ~r/^\s*defmodule\s+(?:[\w.]+\.)?#{last}\s+do\b/)
    else
      line_matching(text, ~r/^-module\(/)
    end
  end

  defp definition(name) do
    name = Regex.escape(Atom.to_string(name))

    ~r/^\s*def(?:p|macro|macrop|guard|guardp|delegate|struct|exception)?\s+(?:unquote\()?#{name}(?![\w?!])/
  end

  # The line (1-based) of the first match at or after a line.
  defp line_matching(text, pattern, from \\ 1) do
    text
    |> String.split("\n")
    |> Enum.with_index(1)
    |> Enum.find_value(fn {line, number} -> number >= from and line =~ pattern and number end)
  end

  # The line the compiler recorded, for functions that macros define (such as
  # Ecto.Repo's), which are not written in the source.
  defp compiled_line(module, name, arity) do
    macro = :"MACRO-#{name}"

    with [_ | _] = beam <- :code.which(module),
         {:ok, {_, [abstract_code: {:raw_abstract_v1, code}]}} <-
           :beam_lib.chunks(beam, [:abstract_code]) do
      Enum.find_value(code, fn
        {:function, anno, ^name, a, _} when arity == nil or a == arity ->
          :erl_anno.line(anno)

        {:function, anno, ^macro, a, _} when arity == nil or a == arity + 1 ->
          :erl_anno.line(anno)

        _ ->
          nil
      end)
    else
      _ -> nil
    end
  end

  defp elixir?(module), do: match?("Elixir." <> _, Atom.to_string(module))

  defp arity_suffix(nil), do: ""
  defp arity_suffix(arity), do: "/#{arity}"
end

defmodule Mix.Tasks.Textmate.Definition do
  use Mix.Task

  @moduledoc false

  # Prints where the code at the caret (TM_LINE_NUMBER and TM_LINE_INDEX) of the
  # file is defined, as "LINE<tab>FILE". The document is the standard input.
  #
  #     elixir -r load.exs -S mix textmate.definition FILE LINE INDEX

  @impl true
  def run([file, line, index]) do
    TextMate.load_paths()
    document = TextMate.read_document()

    {target, env} =
      TextMate.Symbol.at(
        document,
        String.to_integer(line),
        String.to_integer(index),
        TextMate.template_env(file)
      )

    file = if file == "", do: nil, else: Path.expand(file)

    case TextMate.Definition.find(target, env, document, file, File.cwd!()) do
      {:ok, nil, _line} ->
        IO.binwrite(:stderr, ["Save the document to go to definitions in it.", ?\n])
        exit({:shutdown, 1})

      {:ok, file, line} ->
        IO.binwrite("#{line}\t#{file}")

      {:error, message} ->
        IO.binwrite(:stderr, [message, ?\n])
        exit({:shutdown, 1})
    end
  end
end
