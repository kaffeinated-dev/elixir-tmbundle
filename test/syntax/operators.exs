# SYNTAX TEST "source.elixir" "Operators"
!!
power = 2 ** 8
#         ^^ keyword.operator.arithmetic.elixir
range = 1..10//2
#        ^^ keyword.operator.range.elixir
#            ^^ keyword.operator.range.elixir
matched = name =~ "x"
#              ^^ keyword.operator.comparison.elixir
double = fn x -> x * 2 end
#             ^^ keyword.operator.arrow.elixir
list |> Enum.map(&(&1 * 2))
#    ^^ keyword.operator.pipe.elixir
#                  ^^ variable.other.anonymous.elixir
for x <- xs, do: x
#     ^^ keyword.operator.arrow.elixir
map = %{"a" => 1}
#           ^^ keyword.operator.arrow.elixir
"a" <> "b"
#   ^^ keyword.operator.concatenation.elixir
a ++ b -- c +++ d --- e
# ^^ keyword.operator.concatenation.elixir
#      ^^ keyword.operator.concatenation.elixir
#           ^^^ keyword.operator.concatenation.elixir
#                 ^^^ keyword.operator.concatenation.elixir
a ||| b &&& c ^^^ d <<< e >>> f ~~~ g
# ^^^ keyword.operator.bitwise.elixir
#       ^^^ keyword.operator.bitwise.elixir
#             ^^^ keyword.operator.bitwise.elixir
#                   ^^^ keyword.operator.bitwise.elixir
#                         ^^^ keyword.operator.bitwise.elixir
#                               ^^^ keyword.operator.bitwise.elixir
a <~> b <<~ c ~>> d <~ e ~> f <|> g
# ^^^ keyword.operator.custom.elixir
#       ^^^ keyword.operator.custom.elixir
#             ^^^ keyword.operator.custom.elixir
# ^^ keyword.operator.custom.elixir
#  ^^ keyword.operator.custom.elixir
#                             ^^^ keyword.operator.custom.elixir
a === b !== c == d != e <= f >= g < h > i
# ^^^ keyword.operator.comparison.elixir
#       ^^^ keyword.operator.comparison.elixir
# ^^ keyword.operator.comparison.elixir
#       ^^ keyword.operator.comparison.elixir
#                       ^^ keyword.operator.comparison.elixir
#                            ^^ keyword.operator.comparison.elixir
a && b || !c
# ^^ keyword.operator.logical.elixir
#      ^^ keyword.operator.logical.elixir
#         ^ keyword.operator.logical.elixir
!valid?
# <- keyword.operator.logical.elixir
x in list and y not in list or z
# ^^ keyword.operator.elixir
#         ^^^ keyword.operator.elixir
#               ^^^ keyword.operator.elixir
#                           ^^ keyword.operator.elixir
@type t :: integer | nil
#       ^^ keyword.operator.type.elixir
#                  ^ keyword.operator.other.elixir
pinned = ^value
#        ^ variable.other.capture.elixir punctuation.definition.variable.elixir
!!
# Clauses: arrows and guards, including the wildcard before when.
case result do
  {:ok, value} when is_map(value) -> value
#              ^^^^ keyword.operator.elixir
#                                 ^^ keyword.operator.arrow.elixir
  _ when true -> nil
# ^ comment.wildcard.elixir
#   ^^^^ keyword.operator.elixir
#   ^^^^ - comment
end
