defmodule TextMate.HTMLTest do
  use ExUnit.Case, async: true

  alias TextMate.HTML

  @root Path.expand("../..", __DIR__)

  defp convert(text, style \\ %{}) do
    {html, style} = HTML.convert(text, style, @root)
    {IO.iodata_to_binary(html), style}
  end

  defp html(text), do: text |> convert() |> elem(0)

  describe "colors" do
    test "become classes, and styles combine" do
      assert html("\e[31mred\e[0m plain") == ~s(<span class="f1">red</span> plain)
      assert html("\e[1m\e[30mbold black\e[0m") == ~s(<span class="b f0">bold black</span>)

      assert html("\e[1;4;92mboth\e[22mnot bold") ==
               ~s(<span class="b u f10">both</span><span class="u f10">not bold</span>)
    end

    test "of the 256-color palette and 24-bit colors are inline styles" do
      assert html("\e[48;5;88mx") == ~s|<span style="background-color: rgb(135, 0, 0)">x</span>|
      assert html("\e[38;5;244mx") == ~s|<span style="color: rgb(128, 128, 128)">x</span>|
      assert html("\e[38;2;1;2;3mx") == ~s|<span style="color: rgb(1, 2, 3)">x</span>|
    end

    test "continue on the next line until reset" do
      {first, style} = convert("\e[31m** (KeyError) key :a not found in:")
      assert first == ~s|<span class="f1">** (KeyError) key :a not found in:</span>|
      assert convert("    %{}\e[0m", style) == {~s(<span class="f1">    %{}</span>), %{}}
    end

    test "other escape sequences and carriage returns are dropped" do
      assert html("\e[2Kdone\r") == "done"
    end
  end

  test "text is escaped" do
    assert html(~s(<a href="x">&</a>)) == "&lt;a href=&quot;x&quot;&gt;&amp;&lt;/a&gt;"
  end

  describe "file references" do
    test "in the project are linked, with their line and column" do
      file = Path.join(@root, "Support/lib/textmate/html.ex")

      assert html("    └─ Support/lib/textmate/html.ex:12:5: TextMate.HTML.main/1") ==
               ~s(    └─ <a href="txmt://open?url=file://#{URI.encode(file)}&amp;line=12&amp;column=5">) <>
                 ~s(Support/lib/textmate/html.ex:12:5</a>: TextMate.HTML.main/1)
    end

    test "that don't exist are not linked" do
      assert html("lib/missing.ex:12") == "lib/missing.ex:12"
      assert html("see foo.example:3") == "see foo.example:3"
    end

    test "of Elixir are linked to its source" do
      html = html("(elixir 1.20.4) lib/enum.ex:1688: Enum.map/2")
      source = Path.join(:code.lib_dir(:elixir), "lib/enum.ex")

      if File.exists?(source) do
        assert html =~ ~s{(elixir 1.20.4) <a href="txmt://open?url=file://}
        assert html =~ ~s{lib/elixir/lib/enum.ex&amp;line=1688">lib/enum.ex:1688</a>: Enum.map/2}
      end
    end

    test "of dependencies are linked to their source", %{} do
      root = Path.join(System.tmp_dir!(), "textmate-html-test")
      File.mkdir_p!(Path.join(root, "deps/plug/lib/plug"))
      File.write!(Path.join(root, "deps/plug/lib/plug/conn.ex"), "")

      {html, _} = HTML.convert("(plug 1.18.1) lib/plug/conn.ex:10: Plug.Conn.f/1", %{}, root)

      assert IO.iodata_to_binary(html) =~
               ~s{deps/plug/lib/plug/conn.ex&amp;line=10">lib/plug/conn.ex:10</a>}

      File.rm_rf!(root)
    end

    test "are escaped in URLs" do
      root = Path.join(System.tmp_dir!(), "textmate html #test")
      File.mkdir_p!(Path.join(root, "lib"))
      File.write!(Path.join(root, "lib/a.ex"), "")

      {html, _} = HTML.convert("lib/a.ex:1", %{}, root)
      assert IO.iodata_to_binary(html) =~ "textmate%20html%20%23test/lib/a.ex&amp;line=1"
      File.rm_rf!(root)
    end
  end

  describe "output" do
    test "is shown by line, and an incomplete line when flushed" do
      state = HTML.new(@root)
      {html, state} = HTML.feed(state, "Running\n\e[32m.")
      assert IO.iodata_to_binary(html) == "Running\n"

      {html, state} = HTML.flush(state)
      assert IO.iodata_to_binary(html) == ~s(<span class="f2">.</span>)

      {html, state} = HTML.feed(state, ".\n")
      assert IO.iodata_to_binary(html) == ~s(<span class="f2">.</span>\n)
      assert state.pending == ""
    end

    test "keeps an incomplete escape sequence or character for later" do
      state = %{HTML.new(@root) | pending: "ab\e[3"}
      {html, state} = HTML.flush(state)
      assert IO.iodata_to_binary(html) == "ab"
      assert state.pending == "\e[3"

      state = %{HTML.new(@root) | pending: "é" <> binary_part("é", 0, 1)}
      {html, state} = HTML.flush(state)
      assert IO.iodata_to_binary(html) == "é"
      assert byte_size(state.pending) == 1

      {html, state} = HTML.flush(%{state | pending: "é"})
      assert {IO.iodata_to_binary(html), state.pending} == {"é", ""}
    end
  end

  test "the footer describes the exit status" do
    statuses = "0:success:Done.|2:failure:Tests failed."
    assert HTML.footer(0, statuses) =~ ~s(<p class="status success">Done.</p>)
    assert HTML.footer(2, statuses) =~ ~s(<p class="status failure">Tests failed.</p>)
    assert HTML.footer(1, statuses) =~ ~s(<p class="status failure">Failed with exit code 1.</p>)
  end
end
