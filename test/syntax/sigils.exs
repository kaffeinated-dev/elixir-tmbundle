# SYNTAX TEST "source.elixir" "Sigils"
!!
# Multi-letter uppercase sigils (Elixir 1.15) are literal: no interpolation.
query = ~SQL"select * from users where id = #{id}"
#       ^^^^^ string.quoted.other.sigil.literal.elixir punctuation.definition.string.begin.elixir
#            ^^^^^^ string.quoted.other.sigil.literal.elixir
#                                           ^^^^^ string.quoted.other.sigil.literal.elixir
#                                           ^^^^^ - meta.embedded.line.elixir
#                                                ^ string.quoted.other.sigil.literal.elixir punctuation.definition.string.end.elixir
html = ~HTML|<p>#{@name}</p>|
#      ^^^^^^ string.quoted.other.sigil.literal.elixir punctuation.definition.string.begin.elixir
#            ^^^ string.quoted.other.sigil.literal.elixir
#                           ^ string.quoted.other.sigil.literal.elixir punctuation.definition.string.end.elixir
view = ~LVN2[<Text/>]
#      ^^^^^^ string.quoted.other.sigil.literal.elixir punctuation.definition.string.begin.elixir
#                   ^ string.quoted.other.sigil.literal.elixir punctuation.definition.string.end.elixir
!!
# Lowercase sigils interpolate.
greeting = ~s(hello #{name})
#          ^^^ string.quoted.other.sigil.elixir punctuation.definition.string.begin.elixir
#                   ^^ string.quoted.other.sigil.elixir meta.embedded.line.elixir punctuation.section.embedded.begin.elixir
#                          ^ string.quoted.other.sigil.elixir punctuation.definition.string.end.elixir
atoms = ~w[foo bar]a
#                 ^^ string.quoted.other.sigil.elixir punctuation.definition.string.end.elixir
tags = ~w{foo bar}a1
#                ^^^ string.quoted.other.sigil.elixir punctuation.definition.string.end.elixir
path = ~s'it"s'
#      ^^^ string.quoted.other.sigil.elixir punctuation.definition.string.begin.elixir
#           ^^ string.quoted.other.sigil.elixir
#             ^ string.quoted.other.sigil.elixir punctuation.definition.string.end.elixir
!!
# An escaped terminator does not end an uppercase sigil.
quoted = ~S"a\"b"
#              ^ string.quoted.other.sigil.literal.elixir
#               ^ string.quoted.other.sigil.literal.elixir punctuation.definition.string.end.elixir
!!
# Heredoc sigils with single quotes end at a line of three quotes.
chars = ~c'''
#       ^^^^^ string.quoted.other.sigil.heredoc.elixir punctuation.definition.string.begin.elixir
it's '' still a charlist
# <---- string.quoted.other.sigil.heredoc.elixir
'''
# <--- string.quoted.other.sigil.heredoc.elixir punctuation.definition.string.end.elixir
value = 1
# <----- - string
raw = ~S"""
#     ^^^^^ string.quoted.other.sigil.heredoc.literal.elixir punctuation.definition.string.begin.elixir
Not #{interpolated}
#   ^^^^^^^^^^^^^^^ string.quoted.other.sigil.heredoc.literal.elixir
#   ^^^^^^^^^^^^^^^ - meta.embedded.line.elixir
"""
# <--- string.quoted.other.sigil.heredoc.literal.elixir punctuation.definition.string.end.elixir
!!
# Regular expressions.
pattern = ~r/a+#{b}/iu
#         ^^^ string.regexp.sigil.elixir punctuation.definition.string.begin.elixir
#            ^^ string.regexp.sigil.elixir
#              ^^ string.regexp.sigil.elixir meta.embedded.line.elixir punctuation.section.embedded.begin.elixir
#                  ^^^ string.regexp.sigil.elixir punctuation.definition.string.end.elixir
literal = ~R<a+#{b}>
#         ^^^ string.regexp.sigil.literal.elixir punctuation.definition.string.begin.elixir
#              ^^^^ string.regexp.sigil.literal.elixir
#              ^^^^ - meta.embedded.line.elixir
multi = ~r"""
#       ^^^^^ string.regexp.sigil.heredoc.elixir punctuation.definition.string.begin.elixir
  a+ # comment
# ^^ string.regexp.sigil.heredoc.elixir
"""x
# <---- string.regexp.sigil.heredoc.elixir punctuation.definition.string.end.elixir
!!
# Operators that contain a tilde are not sigils.
a ~> b
# ^^ keyword.operator.custom.elixir
