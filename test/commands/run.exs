# Tests the commands and their Elixir support files:  elixir test/commands/run.exs
ExUnit.start()

root = Path.expand("../..", __DIR__)

for file <- ~w(html marks format compile) do
  Code.require_file("Support/lib/textmate/#{file}.ex", root)
end

Code.require_file("command_case.exs", __DIR__)

for file <- Path.wildcard(Path.join(__DIR__, "*_test.exs")) do
  Code.require_file(file)
end
