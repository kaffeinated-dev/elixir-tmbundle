# SYNTAX TEST "source.elixir" "Literals"

escapes = "\u{1F600} \u00E9 \x41 \n \""
#          ^^^^^^^^^ string.quoted.double.elixir constant.character.escaped.elixir
#                    ^^^^^^ string.quoted.double.elixir constant.character.escaped.elixir
#                           ^^^^ string.quoted.double.elixir constant.character.escaped.elixir

# Quoted keyword keys.
opts = [plain: 1, "with space": 2, 'single': 3, "inter#{x}": 4]
#       ^^^^^^ constant.other.keywords.elixir
#                 ^^^^^^^^^^^^^ constant.other.keywords.elixir
#                 ^ constant.other.keywords.elixir punctuation.definition.constant.begin.elixir
#                            ^ constant.other.keywords.elixir punctuation.definition.constant.end.elixir
#                             ^ constant.other.keywords.elixir punctuation.definition.constant.elixir
#                                  ^^^^^^^^^ constant.other.keywords.elixir
#                                                     ^^^^ constant.other.keywords.elixir meta.embedded.line.elixir
map = %{"key" => 1, "other": 2}
#       ^^^^^ string.quoted.double.elixir
#                   ^^^^^^^^ constant.other.keywords.elixir
binary = <<"foo"::binary, rest::binary>>
#          ^^^^^ string.quoted.double.elixir

# Character literals, including ones that look like comments.
chars = [?a, ?\n, ?#, ?\\, ?é]
#        ^^ constant.numeric.elixir
#            ^^^ constant.numeric.elixir
#                 ^^ constant.numeric.elixir
#                     ^^^ constant.numeric.elixir
#                          ^^ constant.numeric.elixir
#                            ^ - comment.line.number-sign.elixir

# Unused variables and the wildcard.
{_a, _unused?, _, __MODULE__} = tuple
#^^ comment.unused.elixir
#    ^^^^^^^^ comment.unused.elixir
#              ^ comment.wildcard.elixir
#                 ^^^^^^^^^^ variable.language.elixir

# Atoms.
atoms = [:ok, :"quoted #{x}", :..//, :<<>>, :foo?]
#        ^^^ constant.other.symbol.elixir
#             ^^^^^^^^ constant.other.symbol.double-quoted.elixir
#                             ^^^^^ constant.other.symbol.elixir
#                                    ^^^^^ constant.other.symbol.elixir
#                                           ^^^^^ constant.other.symbol.elixir
operators = [:<~, :~>>, :+++, :<|>]
#            ^^^ constant.other.symbol.elixir
#                 ^^^^ constant.other.symbol.elixir
#                       ^^^^ constant.other.symbol.elixir
#                             ^^^^ constant.other.symbol.elixir
