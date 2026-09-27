defmodule TextMate.Markdown do
  @moduledoc false

  # Renders documentation Markdown, as ExDoc and Erlang/OTP write it, to HTML:
  # headings, paragraphs, lists, block quotes (and ExDoc's admonitions), code
  # blocks, tables, and inline code, emphasis, and links. `link` gets the text
  # of inline code (and of ExDoc links, such as [`map/2`](`Enum.map/2`)) and
  # returns a reference to link to (such as "Enum.map/2"), or nil.

  def to_html(markdown, link \\ fn _ -> nil end) do
    markdown
    |> String.replace("\r\n", "\n")
    |> String.split("\n")
    |> blocks(link)
    |> IO.iodata_to_binary()
  end

  # ==========
  # = Blocks =
  # ==========

  defp blocks(lines, link), do: blocks(lines, link, [])

  defp blocks([], _link, html), do: Enum.reverse(html)

  defp blocks([line | rest] = lines, link, html) do
    cond do
      blank?(line) ->
        blocks(rest, link, html)

      match = Regex.run(~r/^\s*(`{3,}|~{3,})\s*([\w+-]*)/, line) ->
        [_, fence, language] = match

        {code, rest} =
          Enum.split_while(rest, &(not String.starts_with?(String.trim_leading(&1), fence)))

        indent = indentation(line)
        code = Enum.map_join(code, "\n", &String.slice(&1, min(indent, indentation(&1))..-1//1))
        blocks(Enum.drop(rest, 1), link, [code_block(code, language) | html])

      match = Regex.run(~r/^\s{0,3}(\#{1,6})\s+(.*?)[\s#]*$/, line) ->
        [_, hashes, text] = match
        level = min(String.length(hashes) + 1, 6)
        blocks(rest, link, [["<h#{level}>", inline(text, link), "</h#{level}>\n"] | html])

      Regex.match?(~r/^\s{0,3}>/, line) ->
        {quote, rest} = Enum.split_while(lines, &Regex.match?(~r/^\s{0,3}>/, &1))
        quote = Enum.map(quote, &Regex.replace(~r/^\s{0,3}> ?/, &1, ""))
        blocks(rest, link, [block_quote(quote, link) | html])

      Regex.match?(~r/^\s{0,3}([-*_])(\s*\1){2,}\s*$/, line) ->
        blocks(rest, link, ["<hr>\n" | html])

      list_item(line) ->
        {items, rest} = list(lines)
        blocks(rest, link, [list_html(items, line, link) | html])

      indentation(line) >= 4 ->
        {code, rest} = Enum.split_while(lines, &(blank?(&1) or indentation(&1) >= 4))
        {code, trailing} = trim_trailing_blanks(code)
        code = Enum.map_join(code, "\n", &String.slice(&1, 4..-1//1))
        blocks(trailing ++ rest, link, [code_block(code, "") | html])

      table?(lines) ->
        {rows, rest} = Enum.split_while(lines, &String.contains?(&1, "|"))
        blocks(rest, link, [table(rows, link) | html])

      true ->
        {paragraph, rest} =
          case Enum.split_while(lines, &paragraph_line?/1) do
            {[], _} -> {[line], rest}
            split -> split
          end

        text = Enum.map_join(paragraph, "\n", &String.trim/1)
        blocks(rest, link, [["<p>", inline(text, link), "</p>\n"] | html])
    end
  end

  defp paragraph_line?(line) do
    not blank?(line) and not Regex.match?(~r/^\s{0,3}(\#{1,6}\s|>|`{3}|~{3})/, line) and
      list_item(line) == nil
  end

  defp blank?(line), do: String.trim(line) == ""

  defp indentation(line), do: byte_size(line) - byte_size(String.trim_leading(line, " "))

  defp trim_trailing_blanks(lines) do
    {blanks, rest} = lines |> Enum.reverse() |> Enum.split_while(&blank?/1)
    {Enum.reverse(rest), blanks}
  end

  defp code_block(code, language) do
    class = if language == "", do: "", else: ~s( class="language-#{escape(language)}")
    ["<pre><code", class, ">", escape(code), "</code></pre>\n"]
  end

  # ExDoc's admonitions: > #### Warning {: .warning}
  defp block_quote([first | rest] = lines, link) do
    case Regex.run(~r/^\#{1,6}\s+(.*?)\s*\{:\s*\.(\w+)\s*\}\s*$/, first) do
      [_, title, kind] ->
        [
          ~s(<blockquote class="admonition #{kind}"><p class="title">),
          inline(title, link),
          "</p>\n",
          blocks(rest, link),
          "</blockquote>\n"
        ]

      nil ->
        ["<blockquote>\n", blocks(lines, link), "</blockquote>\n"]
    end
  end

  # =========
  # = Lists =
  # =========

  defp list_item(line), do: Regex.run(~r/^(\s{0,3})([*+-]|\d{1,9}[.)])(\s+)(.*)$/, line)

  # The lines of a list, up to a line after a blank line that is neither
  # indented nor another item.
  defp list([first | rest]) do
    {more, rest} = take_list(rest, [], false, indentation(first))
    {[first | more], rest}
  end

  defp take_list([], acc, _blank, _indent),
    do: {acc |> Enum.drop_while(&blank?/1) |> Enum.reverse(), []}

  defp take_list([line | rest] = lines, acc, after_blank, indent) do
    cond do
      blank?(line) ->
        take_list(rest, [line | acc], true, indent)

      list_item(line) && indentation(line) <= indent + 3 ->
        take_list(rest, [line | acc], false, indent)

      indentation(line) > indent ->
        take_list(rest, [line | acc], false, indent)

      not after_blank and not Regex.match?(~r/^\s{0,3}(\#{1,6}\s|>|`{3})/, line) ->
        take_list(rest, [line | acc], false, indent)

      true ->
        {acc |> Enum.drop_while(&blank?/1) |> Enum.reverse(), lines}
    end
  end

  defp list_html(lines, first, link) do
    [_, indent, marker, _, _] = list_item(first)
    ordered = marker =~ ~r/\d/
    base = String.length(indent)

    items =
      Enum.chunk_while(
        lines,
        [],
        fn line, item ->
          case list_item(line) do
            [_, i, _, _, _] when item != [] and byte_size(i) <= base + 1 ->
              {:cont, Enum.reverse(item), [line]}

            _ ->
              {:cont, [line | item]}
          end
        end,
        fn item -> {:cont, Enum.reverse(item), []} end
      )

    loose = Enum.any?(lines, &blank?/1)
    tag = if ordered, do: "ol", else: "ul"

    start =
      if ordered and marker not in ["1.", "1)"],
        do: ~s( start="#{Integer.parse(marker) |> elem(0)}"),
        else: ""

    [
      "<#{tag}#{start}>\n",
      Enum.map(items, fn [item | more] ->
        [_, i, m, s, text] = list_item(item)
        width = String.length(i <> m <> s)
        content = [text | Enum.map(more, &String.slice(&1, min(width, indentation(&1))..-1//1))]
        html = blocks(content, link)
        html = if loose, do: html, else: unwrap(html)
        ["<li>", html, "</li>\n"]
      end),
      "</#{tag}>\n"
    ]
  end

  # A tight list item shows its first paragraph without <p>.
  defp unwrap([["<p>", text, "</p>\n"] | rest]), do: [text | rest]
  defp unwrap(html), do: html

  # ==========
  # = Tables =
  # ==========

  defp table?([header, separator | _]) do
    String.contains?(header, "|") and
      Regex.match?(~r/^\s*\|?\s*:?-+:?\s*(\|\s*:?-+:?\s*)+\|?\s*$/, separator)
  end

  defp table?(_lines), do: false

  defp table([header, _separator | rows], link) do
    cells = fn row ->
      row |> String.trim() |> String.trim("|") |> String.split("|") |> Enum.map(&String.trim/1)
    end

    [
      "<table>\n<tr>",
      Enum.map(cells.(header), &["<th>", inline(&1, link), "</th>"]),
      "</tr>\n",
      Enum.map(rows, fn row ->
        ["<tr>", Enum.map(cells.(row), &["<td>", inline(&1, link), "</td>"]), "</tr>\n"]
      end),
      "</table>\n"
    ]
  end

  # ==========
  # = Inline =
  # ==========

  # Links first (their text may have code), then code spans (nothing inside
  # them is Markdown), then emphasis in the rest.
  def inline(text, link) do
    ~r/\[((?:[^\[\]`]|`[^`]*`)+)\]\(([^()\s]+|`[^`]+`)\)/
    |> Regex.split(text, include_captures: true)
    |> Enum.map(fn part ->
      case Regex.run(~r/^\[(.+)\]\((.+)\)$/s, part) do
        [_, label, target] ->
          link(label, String.trim(target, "`"), String.starts_with?(target, "`"), link)

        nil ->
          code_spans(part, link)
      end
    end)
  end

  defp link(label, target, code?, link) do
    label = code_spans(label, fn _ -> nil end)

    case link.(target) do
      nil when code? -> label
      nil -> [~s(<a href="), escape(target), ~s(">), label, "</a>"]
      reference -> reference_link(reference, label)
    end
  end

  defp code_spans(text, link) do
    ~r/(`+)(.+?)\1/s
    |> Regex.split(text, include_captures: true)
    |> Enum.map(fn part ->
      case Regex.run(~r/^(`+)(.+?)\1$/s, part) do
        [_, _, code] -> code_span(String.trim(code), link)
        nil -> autolinks(part)
      end
    end)
  end

  defp code_span(code, link) do
    html = ["<code>", escape(code), "</code>"]

    case link.(code) do
      nil -> html
      reference -> reference_link(reference, html)
    end
  end

  defp reference_link(reference, html),
    do: [~s(<a href="#" data-reference="), escape(reference), ~s(">), html, "</a>"]

  # <https://…>
  defp autolinks(text) do
    ~r/<(https?:\/\/[^>\s]+)>/
    |> Regex.split(text, include_captures: true)
    |> Enum.map(fn part ->
      case Regex.run(~r/^<(https?:\/\/[^>\s]+)>$/, part) do
        [_, url] -> [~s(<a href="), escape(url), ~s(">), escape(url), "</a>"]
        nil -> emphasis(escape(part))
      end
    end)
  end

  defp emphasis(html) do
    html
    |> then(&Regex.replace(~r/(\*\*|__)(?=\S)(.+?)(?<=\S)\1/s, &1, "<strong>\\2</strong>"))
    |> then(
      &Regex.replace(~r/(?<![\w*])\*(?=[^\s*])(.+?)(?<=[^\s*])\*(?![\w*])/s, &1, "<em>\\1</em>")
    )
    |> then(
      &Regex.replace(~r/(?<![\w_])_(?=[^\s_])(.+?)(?<=[^\s_])_(?![\w_])/s, &1, "<em>\\1</em>")
    )
  end

  def escape(text) do
    text
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    |> String.replace("\"", "&quot;")
  end
end
