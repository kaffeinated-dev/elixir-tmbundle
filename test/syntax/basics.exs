# SYNTAX TEST "source.elixir" "Existing highlighting that must keep working"

# A comment
# <----------- comment.line.number-sign.elixir
## Section
# <---------- comment.line.section.elixir
name = "Hello #{user.name}!"
#      ^^^^^^ string.quoted.double.elixir
#             ^^ meta.embedded.line.elixir punctuation.section.embedded.begin.elixir
#               ^^^^ meta.embedded.line.elixir source.elixir
#                        ^ meta.embedded.line.elixir punctuation.section.embedded.end.elixir
doc = """
#     ^^^ string.quoted.double.heredoc.elixir punctuation.definition.string.begin.elixir
Hello #{name}
#     ^^ string.quoted.double.heredoc.elixir meta.embedded.line.elixir
"""
# <--- string.quoted.double.heredoc.elixir punctuation.definition.string.end.elixir
charlist = 'abc'
#          ^^^^^ string.quoted.single.elixir
numbers = [1_000, 0x1F, 0b1010, 0o777, 1.5e-3]
#          ^^^^^ constant.numeric.integer.elixir
#                 ^^^^ constant.numeric.hex.elixir
#                       ^^^^^^ constant.numeric.binary.elixir
#                               ^^^^^ constant.numeric.octal.elixir
#                                      ^^^^^^ constant.numeric.float.elixir
values = [nil, true, false, __MODULE__, __ENV__, __STACKTRACE__]
#         ^^^ constant.language.elixir
#              ^^^^ constant.language.elixir
#                                       ^^^^^^^ variable.language.elixir
#                                                ^^^^^^^^^^^^^^ variable.language.elixir
@attribute 1
# <---------- variable.other.readwrite.module.elixir
Enum.map(list, &String.upcase/1)
# <---- entity.name.type.class.elixir
#    ^^^ entity.name.function.elixir
#              ^ variable.other.anonymous.elixir
#                      ^^^^^^ entity.name.function.elixir
result = with {:ok, a} <- fetch(), do: a
#        ^^^^ keyword.control.elixir
#                         ^^^^^ entity.name.function.elixir
if valid?(x), do: :yes, else: :no
# <-- keyword.control.elixir
#             ^^^ constant.other.keywords.elixir
#                       ^^^^^ constant.other.keywords.elixir
try do
# <--- keyword.control.elixir
  raise ArgumentError, "bad"
# ^^^^^ keyword.control.elixir
rescue
# <------ keyword.control.elixir
  e in ArgumentError -> reraise e, __STACKTRACE__
catch
  :exit, _ -> :ok
after
# <----- keyword.control.elixir
  cleanup()
end
receive do
  {:msg, value} -> value
after
  1_000 -> :timeout
end
import Kernel, except: [raise: 2]
# <------ keyword.control.elixir
alias MyApp.{Accounts, Repo}
# <----- keyword.control.elixir
require Logger
use GenServer
# <--- keyword.control.elixir
defstruct [:name, age: 0]
# <--------- keyword.control.elixir
defexception [:message]
# <------------ keyword.control.elixir
