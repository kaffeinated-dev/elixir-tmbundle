defmodule TextMate.Marks do
  @moduledoc false

  # Shows compiler diagnostics as marks in TextMate's gutter; clicking a mark
  # shows its message. Each update replaces the previous marks of the project:
  # the files that had marks are remembered, and their marks are cleared.

  @types ["error", "warning", "note"]

  # The marks for diagnostics: those with a file and a line.
  def marks(diagnostics, root) do
    diagnostics |> Enum.map(&mark(&1, root)) |> Enum.reject(&is_nil/1)
  end

  def update(root, marks, mate \\ System.get_env("TM_MATE"))

  def update(_root, _marks, nil), do: :ok

  def update(root, marks, mate) do
    by_file = Enum.group_by(marks, & &1.file)
    state = state_file(root)
    previous = read_state(state)

    case previous -- Map.keys(by_file) do
      [] -> :ok
      files -> mate(mate, clear_args(files))
    end

    for {file, marks} <- by_file do
      mate(mate, clear_args([]) ++ Enum.flat_map(marks, &set_args/1) ++ [file])
    end

    write_state(state, Map.keys(by_file))
  end

  # Clears the marks of each file (each file follows its mark types, as mate
  # pairs the nth type with the nth file).
  defp clear_args(files) do
    Enum.flat_map(@types, &["--clear-mark", &1]) ++
      Enum.flat_map(files, &List.duplicate(&1, length(@types)))
  end

  defp set_args(mark) do
    ["--set-mark", "#{mark.type}:#{mark.message}", "--line", "#{mark.line}:#{mark.column}"]
  end

  defp mate(mate, args), do: System.cmd(mate, args, stderr_to_stdout: true)

  # =========
  # = Marks =
  # =========

  def mark(%{file: file, position: position, severity: severity, message: message}, root)
      when is_binary(file) do
    {line, column} =
      case position do
        {line, column} -> {line, column}
        line when is_integer(line) -> {line, 1}
        _ -> {0, 0}
      end

    if line > 0 do
      %{
        file: Path.expand(file, root),
        line: line,
        column: max(column, 1),
        type: type(severity),
        message: message(message)
      }
    end
  end

  def mark(_diagnostic, _root), do: nil

  defp type(:error), do: "error"
  defp type(:warning), do: "warning"
  defp type(_), do: "note"

  # The message without its snippet of code (shown in the editor anyway), and
  # without the heading and stacktrace of syntax errors.
  def message(message) do
    lines =
      message
      |> IO.chardata_to_string()
      |> String.replace(~r/\e\[[0-9;]*m/, "")
      |> String.split("\n")
      |> Enum.reject(&Regex.match?(~r/^\s*(\d+\s*)?[│└]/u, &1))
      |> Enum.reject(&Regex.match?(~r/^\*\* \([\w.]+\) .*:$/, &1))
      |> Enum.reject(&Regex.match?(~r/^\s*\([a-z]\w* [^()\s]+\) \S+:\d+/, &1))

    indent =
      lines
      |> Enum.reject(&(String.trim(&1) == ""))
      |> Enum.map(&(byte_size(&1) - byte_size(String.trim_leading(&1, " "))))
      |> Enum.min(fn -> 0 end)

    lines
    |> Enum.map(
      &binary_part(&1, min(indent, byte_size(&1)), byte_size(&1) - min(indent, byte_size(&1)))
    )
    |> Enum.join("\n")
    |> String.replace(~r/\n{3,}/, "\n\n")
    |> String.trim()
    |> String.replace_prefix("error: ", "")
  end

  # =========
  # = State =
  # =========

  defp state_file(root) do
    Path.join([System.tmp_dir!(), "textmate-elixir", "marks-#{:erlang.phash2(root)}"])
  end

  defp read_state(path) do
    case File.read(path) do
      {:ok, contents} -> String.split(contents, "\n", trim: true)
      {:error, _} -> []
    end
  end

  defp write_state(path, files) do
    File.mkdir_p!(Path.dirname(path))
    File.write!(path, Enum.map(files, &[&1, ?\n]))
  end
end
