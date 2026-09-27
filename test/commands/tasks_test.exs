defmodule TextMate.TasksTest do
  use ExUnit.Case, async: true

  alias Mix.Tasks.Textmate.{Compile, Format}

  defp reason(code) do
    Code.string_to_quoted!(code)
  rescue
    exception -> Format.reason(exception)
  end

  describe "why a document is not formatted" do
    test "is where its syntax error is" do
      assert reason("defmodule A do\n  def a(x) do\n    x +\n  end\nend\n") =~
               ~r/^line 4: syntax error before: end/

      assert reason("defmodule A do\n  def a, do: 1\n") == "line 1: missing terminator: end"
    end

    test "is where a mismatched delimiter is, and which one is unclosed" do
      assert reason("def a do\n  [1\nend\n") ==
               "line 3: unexpected reserved word: end (expected ] for the [ on line 2)"
    end

    test "is otherwise the exception's first line" do
      assert Format.reason(%Mix.Error{message: "Unknown dependency :phoenix\nRun mix deps.get"}) ==
               "Unknown dependency :phoenix"
    end
  end

  test "the compile summary counts the marked errors and warnings" do
    warning = %{type: "warning"}
    assert Compile.summary([]) == "No warnings."
    assert Compile.summary([%{type: "note"}]) == "No warnings."

    assert Compile.summary([warning]) ==
             "1 warning, marked in the gutter (F3 jumps to the next mark)."

    assert Compile.summary([warning, %{type: "error"}, warning]) ==
             "1 error and 2 warnings, marked in the gutter (F3 jumps to the next mark)."
  end
end
