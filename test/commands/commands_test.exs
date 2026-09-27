defmodule CommandsTest do
  use CommandCase

  @unformatted "defmodule   Sample.Extra do\ndef hello,do: :world\nend\n"
  @formatted "defmodule Sample.Extra do\n  def hello, do: :world\nend\n"

  describe "Format Document" do
    test "prints the formatted document", %{project: project} do
      assert %{status: 0, output: @formatted} =
               run_command("Format Document", project, "lib/extra.ex", input: @unformatted)
    end

    test "leaves a formatted document", %{project: project} do
      assert %{status: 200, output: ""} =
               run_command("Format Document", project, "lib/extra.ex", input: @formatted)
    end

    test "shows why a document can't be formatted", %{project: project} do
      result =
        run_command("Format Document", project, "lib/extra.ex",
          input: "defmodule A do\n  def a, do: [1\nend\n"
        )

      assert %{status: 206, output: ""} = result

      assert result.errors ==
               "Not formatted: line 3: unexpected reserved word: end (expected ] for the [ on line 2)"
    end

    test "formats an untitled document", %{project: project} do
      assert %{status: 0, output: @formatted} =
               run_command("Format Document", project, nil, input: @unformatted)
    end
  end

  describe "Format on Save" do
    test "formats files of projects with a .formatter.exs", %{project: project} do
      assert %{status: 0, output: @formatted} =
               run_command("Format on Save", project, "lib/extra.ex", input: @unformatted)
    end

    test "can be turned off", %{project: project} do
      assert %{status: 200} =
               run_command("Format on Save", project, "lib/extra.ex",
                 input: @unformatted,
                 env: [{"TM_ELIXIR_FORMAT_ON_SAVE", "false"}]
               )
    end

    test "leaves files outside of projects", %{project: project} do
      assert %{status: 200} =
               run_command("Format on Save", Path.dirname(project), "loose.exs",
                 input: @unformatted
               )
    end
  end

  describe "Run" do
    test "runs the tests of a test file", %{project: project} do
      result = run_command("Run", project, "test/sample_test.exs")
      assert result.status == 0
      assert result.output =~ "<title>Run Tests</title>"
      assert result.output =~ "<code>mix test test/sample_test.exs</code>"
      assert result.output =~ ~s(<p class="status success">Done.</p>)
    end

    test "runs the tests of a file in lib", %{project: project} do
      assert run_command("Run", project, "lib/sample.ex").output =~
               "<code>mix test test/sample_test.exs</code>"
    end

    test "runs a script in the project", %{project: project} do
      File.write!(Path.join(project, "hello.exs"), ~S[IO.puts("Hello <#{Sample.hello()}>")])
      assert run_command("Run", project, "hello.exs").output =~ "Hello &lt;world&gt;"
    end

    test "runs an untitled document", %{project: project} do
      assert run_command("Run", project, nil, input: "IO.puts(1 + 1)").output =~ "<pre>2\n</pre>"
    end

    test "tells when there's nothing to run", %{project: project} do
      assert %{status: 206, errors: "There is no test for lib/other.ex (test/other_test.exs)."} =
               run_command("Run", project, "lib/other.ex")
    end
  end

  describe "Run Test at Caret" do
    test "runs the test at the caret", %{project: project} do
      output = run_command("Run Test at Caret", project, "test/sample_test.exs", line: 5).output
      assert output =~ "<code>mix test test/sample_test.exs:5</code>"
      assert output =~ "1 passed, 1 excluded"
    end

    test "needs a test file", %{project: project} do
      assert %{status: 206} = run_command("Run Test at Caret", project, "lib/sample.ex")
    end
  end

  test "Run All Tests shows failures linked to their tests", %{project: project} do
    failing = Path.join(project, "test/failing_test.exs")

    File.write!(
      failing,
      "defmodule FailingTest do\n  use ExUnit.Case\n\n  test \"fails\" do\n    assert 1 == 2\n  end\nend\n"
    )

    result = run_command("Run All Tests", project, "lib/sample.ex")
    File.rm!(failing)

    assert result.output =~ ~s(<p class="status failure">Tests failed.</p>)

    assert result.output =~
             ~r{<a href="txmt://open\?url=file://[^"]*/test/failing_test.exs&amp;line=4">test/failing_test.exs:4</a>}
  end

  describe "Compile" do
    test "marks warnings and errors in the gutter", %{project: project} do
      broken = Path.join(project, "lib/broken.ex")

      File.write!(
        broken,
        "defmodule Broken do\n  def a(x), do: 1\n  def b, do: undefined()\nend\n"
      )

      result = run_command("Compile", project, "lib/broken.ex")
      File.rm!(broken)

      assert result.output =~ "1 error and 1 warning, marked in the gutter"
      assert result.output =~ ~s(<p class="status failure">Compilation failed.</p>)

      assert [
               [
                 "--clear-mark",
                 "error",
                 "--clear-mark",
                 "warning",
                 "--clear-mark",
                 "note" | marks
               ]
             ] = result.marks

      assert {^broken, marks} = List.pop_at(marks, -1)

      assert [
               {"error:undefined function undefined/0" <> _, "3:" <> _},
               {~s(warning:variable "x" is unused) <> _, "2:9"}
             ] =
               marks
               |> Enum.chunk_every(4)
               |> Enum.map(fn ["--set-mark", mark, "--line", line] -> {mark, line} end)
               |> Enum.sort()
    end

    test "on save is off by default", %{project: project} do
      assert %{status: 200, marks: []} = run_command("Compile on Save", project, "lib/sample.ex")
    end

    test "on save updates the marks in the background", %{project: project} do
      broken = Path.join(project, "lib/broken.ex")
      File.write!(broken, "defmodule Broken do\n  def a(x), do: 1\nend\n")

      result =
        run_command("Compile on Save", project, "lib/broken.ex",
          env: [{"TM_ELIXIR_COMPILE_ON_SAVE", "1"}],
          background: true
        )

      File.rm!(broken)
      assert result.status == 200

      assert [
               [
                 _,
                 _,
                 _,
                 _,
                 _,
                 _,
                 "--set-mark",
                 "warning:variable \"x\" is unused" <> _,
                 "--line",
                 "2:9",
                 ^broken
               ]
             ] = result.marks
    end
  end
end
