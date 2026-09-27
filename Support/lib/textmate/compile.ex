defmodule Mix.Tasks.Textmate.Compile do
  use Mix.Task

  @moduledoc false

  # Compiles the project, like `mix compile`, and shows its warnings and errors
  # as marks in TextMate's gutter.
  #
  #     elixir -r load.exs -S mix textmate.compile [ARGS…]

  @impl true
  def run(args) do
    {status, diagnostics} =
      case Mix.Task.run("compile", ["--return-errors" | args]) do
        {status, diagnostics} when is_list(diagnostics) -> {status, diagnostics}
        # When compile is an alias, the diagnostics are those Mix kept.
        _ -> {:ok, persisted_diagnostics()}
      end

    marks = TextMate.Marks.marks(diagnostics, File.cwd!())
    TextMate.Marks.update(File.cwd!(), marks)

    if status == :error do
      if marks != [], do: Mix.shell().info(summary(marks))
      exit({:shutdown, 1})
    else
      Mix.shell().info(summary(marks))
    end
  end

  defp persisted_diagnostics do
    if function_exported?(Mix.Task.Compiler, :diagnostics, 0),
      do: Mix.Task.Compiler.diagnostics(),
      else: []
  end

  def summary(marks) do
    counts = Enum.frequencies_by(marks, & &1.type)
    parts = for type <- ["error", "warning"], count = counts[type], do: pluralize(count, type)

    if parts == [],
      do: "No warnings.",
      else: "#{Enum.join(parts, " and ")}, marked in the gutter (F3 jumps to the next mark)."
  end

  defp pluralize(1, type), do: "1 #{type}"
  defp pluralize(count, type), do: "#{count} #{type}s"
end
