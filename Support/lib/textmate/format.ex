defmodule Mix.Tasks.Textmate.Format do
  use Mix.Task

  @moduledoc false

  # Formats the standard input as the given file, with the project's formatter
  # settings and plugins, like `mix format --stdin-filename FILE -`, and writes
  # the result to OUTPUT (where no other output of Mix can end up). When it
  # can't, it prints why on one line, for a tool tip.
  #
  #     elixir -r format.ex -S mix textmate.format FILE OUTPUT

  @impl true
  def run([file, output]) do
    input =
      case IO.binread(:stdio, :eof) do
        :eof -> ""
        input -> input
      end

    {formatter, _options} = Mix.Tasks.Format.formatter_for_file(file)
    File.write!(output, formatter.(input))
  rescue
    exception ->
      IO.puts(:stderr, "Not formatted: " <> reason(exception))
      exit({:shutdown, 1})
  end

  def reason(%MismatchedDelimiterError{} = error) do
    "line #{error.end_line}: #{error.description} " <>
      "(expected #{error.expected_delimiter} for the #{error.opening_delimiter} on line #{error.line})"
  end

  def reason(%{line: line, description: description})
      when is_integer(line) and is_binary(description),
      do: "line #{line}: #{first_line(description)}"

  def reason(exception), do: first_line(Exception.message(exception))

  defp first_line(text), do: text |> String.trim() |> String.split("\n", parts: 2) |> hd()
end
