defmodule CommandCase do
  @moduledoc """
  Runs the bundle's commands like TextMate does, in a new Mix project: the
  command's script with TextMate's variables, the document as standard input,
  and a `mate` that logs its arguments (for gutter marks).
  """

  use ExUnit.CaseTemplate

  @bundle Path.expand("../..", __DIR__)

  using do
    quote do
      import CommandCase
    end
  end

  setup_all do
    dir =
      Path.join(System.tmp_dir!(), "textmate-elixir-test-#{System.unique_integer([:positive])}")

    File.mkdir_p!(dir)
    {_, 0} = System.cmd("mix", ["new", "sample"], cd: dir, stderr_to_stdout: true)
    on_exit(fn -> File.rm_rf!(dir) end)

    # The real path, as in compiler diagnostics (the temporary folder may be a symbolic link).
    {project, 0} = System.cmd("pwd", ["-P"], cd: Path.join(dir, "sample"))
    project = String.trim(project)
    marks = Path.join([System.tmp_dir!(), "textmate-elixir", "marks-#{:erlang.phash2(project)}"])
    on_exit(fn -> File.rm(marks) end)
    %{project: project}
  end

  @doc """
  Runs the command named `name` for `file` (relative to the project, or nil for
  an untitled document). Returns `%{output:, errors:, status:, marks:}`, where
  marks are the arguments of each call to mate.
  """
  def run_command(name, project, file, options \\ []) do
    dir =
      Path.join(
        System.tmp_dir!(),
        "textmate-elixir-command-#{System.unique_integer([:positive])}"
      )

    File.mkdir_p!(dir)
    script = Path.join(dir, "command")
    File.write!(script, command_script(name))
    File.chmod!(script, 0o755)
    input = Path.join(dir, "input")
    File.write!(input, Keyword.get(options, :input, ""))
    mate = Path.join(dir, "mate")

    File.write!(
      mate,
      ~s(#!/bin/bash\nprintf '%s\\0' "$@" >> "#{dir}/mate.log"\nprintf '\\036' >> "#{dir}/mate.log"\n)
    )

    File.chmod!(mate, 0o755)

    path = file && Path.join(project, file)

    env =
      [
        {"TM_BUNDLE_SUPPORT", Path.join(@bundle, "Support")},
        {"TM_MATE", mate},
        {"TM_FILEPATH", path},
        {"TM_FILENAME", path && Path.basename(path)},
        {"TM_DIRECTORY", path && Path.dirname(path)},
        {"TM_PROJECT_DIRECTORY", project},
        {"TM_LINE_NUMBER", to_string(Keyword.get(options, :line, 1))},
        {"TM_LINE_INDEX", to_string(Keyword.get(options, :index, 0))},
        {"TM_SCOPE", Keyword.get(options, :scope, "source.elixir")},
        {"TM_ELIXIR_FORMAT_ON_SAVE", nil},
        {"TM_ELIXIR_COMPILE_ON_SAVE", nil},
        {"TM_SELECTED_TEXT", nil},
        {"LC_CTYPE", "en_US.UTF-8"}
      ] ++ Keyword.get(options, :env, [])

    {output, status} =
      System.cmd("bash", ["-c", ~s("$0" < "$1" 2> "$2"), script, input, Path.join(dir, "errors")],
        env: env,
        cd: (path && Path.dirname(path)) || project
      )

    # A command that works in the background, such as Compile on Save, is done
    # when it has updated the marks.
    if options[:background] do
      Enum.find(1..300, fn _ ->
        File.exists?(Path.join(dir, "mate.log")) or (Process.sleep(100) && false)
      end)

      Process.sleep(500)
    end

    marks =
      case File.read(Path.join(dir, "mate.log")) do
        {:ok, log} ->
          for call <- String.split(log, "\x1e", trim: true),
              do: String.split(call, "\0", trim: true)

        {:error, _} ->
          []
      end

    result = %{
      output: output,
      errors: File.read!(Path.join(dir, "errors")),
      status: status,
      marks: marks
    }

    File.rm_rf!(dir)
    result
  end

  @doc """
  Writes an executable script to a new folder and returns the folder, to put
  first on the PATH, or the script, as $DIALOG.
  """
  def fake(project, name, script) do
    dir = Path.join(Path.dirname(project), "fake-#{System.unique_integer([:positive])}")

    File.mkdir_p!(dir)
    File.write!(Path.join(dir, name), "#!/bin/bash\n" <> script)
    File.chmod!(Path.join(dir, name), 0o755)
    dir
  end

  # The command's script, from its property list.
  defp command_script(name) do
    plist = File.read!(Path.join([@bundle, "Commands", name <> ".tmCommand"]))
    [_, script] = Regex.run(~r{<key>command</key>\s*<string>(.*?)</string>}s, plist)

    Enum.reduce(
      [{"&lt;", "<"}, {"&gt;", ">"}, {"&quot;", "\""}, {"&apos;", "'"}, {"&amp;", "&"}],
      script,
      fn
        {entity, char}, script -> String.replace(script, entity, char)
      end
    )
  end
end
