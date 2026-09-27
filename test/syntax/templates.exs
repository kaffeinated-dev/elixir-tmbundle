# SYNTAX TEST "source.elixir" "Templates in sigils"

def render(assigns) do
  ~H"""
# ^^^^^ meta.embedded.block.heex punctuation.definition.string.begin.elixir
  <.button :if={@show} class={@class} phx-click="go">Hi {@name}</.button>
#   ^^^^^^ meta.embedded.block.heex text.html.heex meta.tag.component.heex entity.name.tag.component.heex
#          ^^^ meta.tag.component.heex keyword.control.heex
#                             ^^^^^^ meta.embedded.line.heex source.elixir variable.other.readwrite.module.elixir
#                                                        ^^^^^ meta.embedded.line.heex source.elixir variable.other.readwrite.module.elixir
  <div id={@id} {@rest} :for={x <- @xs}>{x}</div>
#          ^^^ meta.tag.structure.div.start.html meta.embedded.line.heex source.elixir variable.other.readwrite.module.elixir
#                ^^^^^ meta.embedded.line.heex source.elixir variable.other.readwrite.module.elixir
#                       ^^^^ keyword.control.heex
  {# rendered below}
#            ^ comment.line.number-sign.elixir
#                  ^ meta.embedded.line.heex punctuation.section.embedded.end.heex
  """
# ^^^ meta.embedded.block.heex punctuation.definition.string.end.elixir
end
# <--- keyword.control.elixir
# <--- - meta.embedded.block.heex

inline = ~H[<p>{@x}</p>]
#        ^^^ meta.embedded.block.heex punctuation.definition.string.begin.elixir
#            ^ meta.embedded.block.heex text.html.heex meta.tag.structure.p.start.html entity.name.tag.html
#                      ^ meta.embedded.block.heex punctuation.definition.string.end.elixir
quoted = ~H"<br/>"
#        ^^^ meta.embedded.block.heex punctuation.definition.string.begin.elixir
#            ^^ meta.embedded.block.heex text.html.heex meta.tag.inline.br.void.html entity.name.tag.html
legacy = ~L"<p><%= @title %></p>"
#        ^^^ meta.embedded.block.eex punctuation.definition.string.begin.elixir
#                  ^^^^^^ meta.embedded.block.eex text.html.elixir meta.embedded.line.elixir source.elixir variable.other.readwrite.module.elixir

# HTML doesn't know Elixir escapes: a one-line template with one is a plain sigil.
escaped = ~H"<a href=\"#\">x</a>"
#         ^^^ string.quoted.other.sigil.literal.elixir punctuation.definition.string.begin.elixir
#               ^^^^ string.quoted.other.sigil.literal.elixir
#                               ^ string.quoted.other.sigil.literal.elixir punctuation.definition.string.end.elixir
after_escaped = 1
# <------------- - string.quoted.double.elixir string.quoted.other.sigil.literal.elixir
not_a_template = ~HTML"<p>"
#                ^^^^^^ string.quoted.other.sigil.literal.elixir punctuation.definition.string.begin.elixir
