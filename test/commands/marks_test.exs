defmodule TextMate.MarksTest do
  use ExUnit.Case, async: true

  alias TextMate.Marks

  defp diagnostic(fields) do
    Map.merge(
      %{file: "/app/lib/a.ex", position: {3, 5}, severity: :warning, message: "unused"},
      Map.new(fields)
    )
  end

  describe "a diagnostic's mark" do
    test "is at its position, with a type for its severity" do
      assert Marks.mark(diagnostic([]), "/app") ==
               %{file: "/app/lib/a.ex", line: 3, column: 5, type: "warning", message: "unused"}

      assert %{type: "error", line: 7, column: 1} =
               Marks.mark(diagnostic(severity: :error, position: 7), "/app")

      assert %{type: "note"} = Marks.mark(diagnostic(severity: :hint), "/app")
      assert %{file: "/app/lib/b.ex"} = Marks.mark(diagnostic(file: "lib/b.ex"), "/app")
    end

    test "needs a file and a line" do
      assert Marks.mark(diagnostic(position: 0), "/app") == nil
      assert Marks.mark(diagnostic(file: nil), "/app") == nil
    end
  end

  describe "a mark's message" do
    test "is a syntax error without its heading, code, and stacktrace" do
      message = """
      ** (SyntaxError) invalid syntax found on lib/broken.ex:4:1:
          error: syntax error before: end
          │
        4 │ end
          │ ^
          │
          └─ lib/broken.ex:4:1
          (elixir 1.20.4) lib/kernel/parallel_compiler.ex:548: anonymous fn/5 in Kernel.ParallelCompiler.spawn_workers/8\
      """

      assert Marks.message(message) == "syntax error before: end"
    end

    test "keeps the indentation of type warnings" do
      message = [
        "incompatible types given to Map.fetch!/2:\n\n",
        "    Map.fetch!(%{}, :missing)\n\n",
        "therefore this function will always raise\n"
      ]

      assert Marks.message(message) ==
               "incompatible types given to Map.fetch!/2:\n\n    Map.fetch!(%{}, :missing)\n\ntherefore this function will always raise"
    end

    test "has no colors" do
      assert Marks.message("\e[31mred\e[0m") == "red"
    end
  end

  describe "updating the marks" do
    setup do
      dir =
        Path.join(System.tmp_dir!(), "textmate-marks-test-#{System.unique_integer([:positive])}")

      File.mkdir_p!(dir)
      mate = Path.join(dir, "mate")

      File.write!(
        mate,
        ~s(#!/bin/bash\nprintf '%s\\0' "$@" >> "#{dir}/log"\nprintf '\\036' >> "#{dir}/log"\n)
      )

      File.chmod!(mate, 0o755)
      on_exit(fn -> File.rm_rf!(dir) end)

      calls = fn ->
        log = File.read!(Path.join(dir, "log"))
        File.rm!(Path.join(dir, "log"))

        for call <- String.split(log, "\x1e", trim: true),
            do: String.split(call, "\0", trim: true)
      end

      %{root: dir, mate: mate, calls: calls}
    end

    test "replaces a file's marks, and clears those of files without diagnostics", context do
      clear = ~w(--clear-mark error --clear-mark warning --clear-mark note)
      a = Path.join(context.root, "lib/a.ex")
      b = Path.join(context.root, "lib/b.ex")

      diagnostics = [
        diagnostic(file: a),
        diagnostic(file: a, position: 9, severity: :error, message: "bad"),
        diagnostic(file: b)
      ]

      Marks.update(context.root, Marks.marks(diagnostics, context.root), context.mate)

      assert Enum.sort(context.calls.()) == [
               clear ++
                 [
                   "--set-mark",
                   "warning:unused",
                   "--line",
                   "3:5",
                   "--set-mark",
                   "error:bad",
                   "--line",
                   "9:1",
                   a
                 ],
               clear ++ ["--set-mark", "warning:unused", "--line", "3:5", b]
             ]

      Marks.update(context.root, Marks.marks([diagnostic(file: b)], context.root), context.mate)

      assert context.calls.() == [
               clear ++ [a, a, a],
               clear ++ ["--set-mark", "warning:unused", "--line", "3:5", b]
             ]

      Marks.update(context.root, [], context.mate)
      assert context.calls.() == [clear ++ [b, b, b]]
    end
  end
end
