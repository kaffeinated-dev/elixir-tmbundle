# Checks that every Elixir snippet, expanded with its default text by expand.js, parses and
# is already formatted:  node test/snippets/expand.js | elixir test/snippets/check.exs

# Snippets that are only valid in some context.
contexts = %{
  "do" => {"run ", ""},
  "kv" => {"%{", "}"},
  "#" => {"\"", "\""}
}

# The DSLs of ExUnit, Phoenix, and Ecto are formatted without parentheses in projects that
# import their formatter settings.
locals_without_parens = [
  test: 2, test: 3, describe: 2, setup: 1, setup_all: 1, doctest: 1,
  assert_raise: 2, assert_receive: 1,
  attr: 2, attr: 3, slot: 1, slot: 2,
  schema: 2, field: 2, field: 3, timestamps: 1
]

snippets = IO.read(:stdio, :eof) |> JSON.decode!()

failures =
  for %{"name" => name, "trigger" => trigger, "code" => code} <- snippets,
      {before, after_} = Map.get(contexts, trigger, {"", ""}),
      source = before <> code <> after_,
      reason =
        (case Code.string_to_quoted(source) do
           {:ok, _} ->
             formatted =
               source
               |> Code.format_string!(locals_without_parens: locals_without_parens)
               |> IO.iodata_to_binary()

             if formatted != String.trim_trailing(source),
               do: "is not formatted, mix format gives:\n#{formatted}"

           {:error, error} ->
             "doesn't parse: #{inspect(error)}"
         end),
      reason != nil do
    "#{name} (#{trigger}):\n#{source}\n#{reason}\n"
  end

Enum.each(failures, &IO.puts/1)
IO.puts("#{length(snippets) - length(failures)} of #{length(snippets)} snippets parse and are formatted")
if failures != [], do: System.halt(1)
