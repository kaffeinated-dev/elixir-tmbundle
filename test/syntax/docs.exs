# SYNTAX TEST "source.elixir" "Documentation attributes"

defmodule MyApp.Worker do
  @moduledoc """
# ^^^^^^^^^^ comment.block.documentation.heredoc support.attr.doc.elixir
# ^ comment.block.documentation.heredoc support.attr.doc.elixir punctuation.definition.attribute.elixir
#            ^^^ comment.block.documentation.heredoc punctuation.definition.comment.begin.elixir
  Starts a **worker** for `MyApp`, _once_ per node_name.
#          ^^^^^^^^^^ comment.block.documentation.heredoc markup.bold.markdown
#                         ^^^^^^^ comment.block.documentation.heredoc markup.raw.inline.markdown
#                                  ^^^^^^ comment.block.documentation.heredoc markup.italic.markdown
#                                             ^^^^^^^^^ - markup.italic.markdown
      apply(__MODULE__, :run, [])
#           ^^^^^^^^^^ - markup.bold.markdown

  ## Examples
# ^^^^^^^^^^^ comment.block.documentation.heredoc markup.heading.markdown
# ^^ markup.heading.markdown punctuation.definition.heading.markdown

      iex> MyApp.Worker.start(name: "a")
#     ^^^^ comment.block.documentation.heredoc meta.embedded.doctest.elixir punctuation.definition.prompt.elixir
#                       ^^^^^ comment.block.documentation.heredoc meta.embedded.doctest.elixir source.elixir entity.name.function.elixir
#                                   ^^^ comment.block.documentation.heredoc meta.embedded.doctest.elixir source.elixir string.quoted.double.elixir
      ...> |> Map.keys()
#     ^^^^ meta.embedded.doctest.elixir punctuation.definition.prompt.elixir
#          ^^ meta.embedded.doctest.elixir source.elixir keyword.operator.pipe.elixir
      iex(2)> :ok
#     ^^^^^^^ meta.embedded.doctest.elixir punctuation.definition.prompt.elixir
#             ^^^ meta.embedded.doctest.elixir source.elixir constant.other.symbol.elixir
      {:ok, #PID<0.1.0>}
#     ^^^^ - meta.embedded.doctest.elixir
#     ^^^^ comment.block.documentation.heredoc markup.raw.block.markdown

      # An indented code block, not a heading
#     ^^^^^^^^^^^^^ comment.block.documentation.heredoc markup.raw.block.markdown
#     ^^^^^^^^^^^^^ - markup.heading.markdown

  ```elixir
# ^^^^^^^^^ comment.block.documentation.heredoc meta.embedded.block.elixir punctuation.definition.markdown
  Worker.run(:now)
#        ^^^ comment.block.documentation.heredoc meta.embedded.block.elixir source.elixir entity.name.function.elixir
  ```
# ^^^ meta.embedded.block.elixir punctuation.definition.markdown
  ```sh
# ^^^^^ comment.block.documentation.heredoc markup.raw.block.markdown
  mix run
# ^^^^^^^ comment.block.documentation.heredoc markup.raw.block.markdown
  ```

  > #### Note {: .info}
# ^^^^^^^^^^^^^^^^^^^^^ comment.block.documentation.heredoc markup.quote.markdown
  See [the guide](https://hexdocs.pm/elixir) and version #{@version}.
#      ^^^^^^^^^ comment.block.documentation.heredoc meta.link.inline.markdown string.other.link.title.markdown
#                 ^^^^^^^^^^^^^^^^^^^^^^^^^ meta.link.inline.markdown markup.underline.link.markdown
#                                                        ^^ comment.block.documentation.heredoc meta.embedded.line.elixir punctuation.section.embedded.begin.elixir
  """
# ^^^ comment.block.documentation.heredoc punctuation.definition.comment.end.elixir

  @doc ~S"""
# ^^^^ comment.block.documentation.heredoc support.attr.doc.elixir
#      ^^^^^ comment.block.documentation.heredoc punctuation.definition.comment.begin.elixir
  Uses #{literal} text.
#      ^^^^^^^^^^ comment.block.documentation.heredoc
#      ^^^^^^^^^^ - meta.embedded.line.elixir
  """
  @doc '''
#      ^^^ comment.block.documentation.heredoc punctuation.definition.comment.begin.elixir
  Single quotes, like "this".
#                     ^^^^^^ comment.block.documentation.heredoc
  '''
# ^^^ comment.block.documentation.heredoc punctuation.definition.comment.end.elixir
  @typedoc "The state."
# ^^^^^^^^ comment.block.documentation.string support.attr.doc.elixir
#          ^^^^^^^^^^^^ comment.block.documentation.string
  @doc false
# ^^^^^^^^^^ comment.block.documentation.false
  @doc since: "1.2.0", deprecated: "Use run/1"
# ^^^^ support.attr.doc.elixir
#      ^^^^^^ constant.other.keywords.elixir
#             ^^^^^^^ string.quoted.double.elixir
  @shortdoc "Runs the worker"
# ^^^^^^^^^ comment.block.documentation.string support.attr.doc.elixir
end
