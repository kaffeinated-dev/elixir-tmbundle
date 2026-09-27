defmodule TextMate.DocsTest do
  use ExUnit.Case, async: true

  alias TextMate.{Docs, Markdown, Symbol}

  defp html(markdown, link \\ fn _ -> nil end), do: Markdown.to_html(markdown, link)

  describe "Markdown" do
    test "blocks" do
      assert html("## Examples\n\nSome *text*\nand **more**.\n") ==
               "<h3>Examples</h3>\n<p>Some <em>text</em>\nand <strong>more</strong>.</p>\n"

      assert html("```elixir\niex> 1 <> 2\n```\n") ==
               ~s(<pre><code class="language-elixir">iex&gt; 1 &lt;&gt; 2</code></pre>\n)

      assert html("Example:\n\n    iex> x = 1\n    1\n\nDone.") ==
               "<p>Example:</p>\n<pre><code>iex&gt; x = 1\n1</code></pre>\n<p>Done.</p>\n"

      assert html("---\n") == "<hr>\n"
    end

    test "lists, tight and loose, nested, and ordered" do
      assert html("* one\n* two\n  * nested\n") ==
               "<ul>\n<li>one</li>\n<li>two<ul>\n<li>nested</li>\n</ul>\n</li>\n</ul>\n"

      assert html("1. one\n\n2. two\n") ==
               "<ol>\n<li><p>one</p>\n</li>\n<li><p>two</p>\n</li>\n</ol>\n"

      assert html("3. three\n") == ~s(<ol start="3">\n<li>three</li>\n</ol>\n)
    end

    test "block quotes and ExDoc admonitions" do
      assert html("> quoted\n") == "<blockquote>\n<p>quoted</p>\n</blockquote>\n"

      assert html("> #### Warning {: .warning}\n>\n> Careful.\n") ==
               ~s(<blockquote class="admonition warning"><p class="title">Warning</p>\n<p>Careful.</p>\n</blockquote>\n)
    end

    test "tables" do
      assert html("| a | b |\n|---|:-:|\n| `x` | 2 |\n") ==
               "<table>\n<tr><th>a</th><th>b</th></tr>\n<tr><td><code>x</code></td><td>2</td></tr>\n</table>\n"
    end

    test "links, and code that names something" do
      link = fn code -> if code == "Enum.map/2", do: "Enum.map/2" end

      assert html(
               "See `Enum.map/2`, `x`, [docs](https://hexdocs.pm) and <https://elixir-lang.org>.",
               link
             ) ==
               ~s(<p>See <a href="#" data-reference="Enum.map/2"><code>Enum.map/2</code></a>, <code>x</code>, ) <>
                 ~s(<a href="https://hexdocs.pm">docs</a> and <a href="https://elixir-lang.org">https://elixir-lang.org</a>.</p>\n)

      assert html("[`map/2`](`Enum.map/2`)", link) ==
               ~s(<p><a href="#" data-reference="Enum.map/2"><code>map/2</code></a></p>\n)
    end

    test "snake_case and code are not emphasis" do
      assert html("a snake_case_name and `*x*`") ==
               "<p>a snake_case_name and <code>*x*</code></p>\n"
    end
  end

  describe "documentation" do
    test "of a function has its signature, spec, and text" do
      assert {:ok, "Enum.map/2", html} = Docs.render({:function, Enum, :map, 2}, %Symbol{}, "/")
      assert html =~ ~s(<h1 data-title="Enum.map/2">)
      assert html =~ "<code>map(enumerable, fun)</code>"
      assert html =~ "@spec map(t(), (element() -&gt; any())) :: list()"
      assert html =~ "Returns a list where each element is the result of invoking"
    end

    test "of all arities" do
      assert {:ok, "Enum.reduce", html} =
               Docs.render({:function, Enum, :reduce, nil}, %Symbol{}, "/")

      assert html =~ "reduce(enumerable, fun)"
      assert html =~ "reduce(enumerable, acc, fun)"
    end

    test "of a module lists its functions, types, and callbacks" do
      assert {:ok, "GenServer", html} = Docs.render({:module, GenServer}, %Symbol{}, "/")
      assert html =~ "<h2>Types</h2>"
      assert html =~ "<h2>Callbacks</h2>"
      assert html =~ ~s(<a href="#" data-reference="GenServer.call/3"><code>call/3</code></a>)
      assert html =~ ~s(<a href="#" data-reference="GenServer.init/1"><code>init/1</code></a>)
    end

    test "of types and callbacks, when there is no such function" do
      assert {:ok, _, html} = Docs.render({:function, GenServer, :init, 1}, %Symbol{}, "/")
      assert html =~ "@callback init(init_arg :: term())"
      assert {:ok, _, html} = Docs.render({:function, String, :t, 0}, %Symbol{}, "/")
      assert html =~ "@type t() :: binary()"
    end

    test "of a local call, through the imports" do
      assert {:ok, "Kernel.is_nil", _} =
               Docs.render({:function, nil, :is_nil, nil}, %Symbol{}, "/")

      assert {:error, message} = Docs.render({:function, nil, :nope, nil}, %Symbol{}, "/")
      assert message =~ "nope is not imported here"
    end

    test "that doesn't exist" do
      assert Docs.render({:module, Nope}, %Symbol{}, "/") ==
               {:error, "Nope is not compiled, or doesn’t exist."}

      assert Docs.render({:function, Enum, :nope, 1}, %Symbol{}, "/") ==
               {:error, "No documentation for Enum.nope/1."}

      assert Docs.render({:attribute, :doc}, %Symbol{}, "/") ==
               {:error, "No documentation for @doc."}
    end

    test "links code naming modules and functions, relative to the module" do
      assert Docs.link("map/2", Enum) == "Enum.map/2"
      assert Docs.link("is_nil/1", Enum) == "Kernel.is_nil/1"
      assert Docs.link("c:init/1", GenServer) == "GenServer.init/1"
      assert Docs.link("t:t/0", String) == "String.t/0"
      assert Docs.link("String.Chars", Enum) == "String.Chars"
      assert Docs.link(":lists.map/2", Enum) == ":lists.map/2"
      assert Docs.link("NotAModule", Enum) == nil
      assert Docs.link("%{a: 1}", Enum) == nil
    end
  end
end
