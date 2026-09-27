# SYNTAX TEST "source.elixir" "Modules and functions"

defmodule MyApp.Accounts.User do
# <--------- keyword.control.module.elixir
#         ^^^^^^^^^^^^^^^^^^^ entity.name.type.module.elixir
#                             ^^ keyword.control.module.elixir
  defn softmax(t), do: Nx.exp(t) / Nx.sum(Nx.exp(t))
# ^^^^ keyword.control.module.elixir
#      ^^^^^^^ entity.name.function.public.elixir
  defnp helper(t), do: t
#       ^^^^^^ entity.name.function.private.elixir

# A head without a body ends at the end of the line.
  defp body_less(a, b \\ nil)
#      ^^^^^^^^^ meta.function.private.elixir entity.name.function.private.elixir
#                     ^^ keyword.operator.default.elixir
  def uses_length(list), do: length(list)
# ^^^ - meta.function.private.elixir
#                            ^^^^^^ - meta.function.public.elixir meta.function.private.elixir
#                            ^^^^^^ entity.name.function.elixir
  defdelegate size(map), to: Kernel, as: :map_size
#             ^^^^ entity.name.function.public.elixir
#                        ^^^ constant.other.keywords.elixir
  def after_delegate(x), do: x
#                            ^ - meta.function.public.elixir meta.function.private.elixir

# Parameters can span lines, including calls inside patterns.
  def handle_event("save", %{
#     ^^^^^^^^^^^^ entity.name.function.public.elixir
        "user" => <<id::size(8), rest::binary>>
#                       ^^^^ meta.function.public.elixir
      }, socket) do
#                ^^ meta.function.public.elixir keyword.control.module.elixir
    {:noreply, socket}
#    ^^^^^^^^ - meta.function.public.elixir
  end

  def long_function_name(argument),
#     ^^^^^^^^^^^^^^^^^^ entity.name.function.public.elixir
    do: argument
#   ^^^ constant.other.keywords.elixir

  defguard is_even(x) when is_integer(x) and rem(x, 2) == 0
#          ^^^^^^^ entity.name.function.public.elixir
#                     ^^^^ keyword.operator.elixir
  defmacro __using__(opts) do
#          ^^^^^^^^^ entity.name.function.public.elixir
    quote do
#   ^^^^^ keyword.control.elixir
      unquote_splicing(opts)
#     ^^^^^^^^^^^^^^^^ keyword.control.elixir
    end
  end
  def ok?, do: true
#     ^^^ entity.name.function.public.elixir
end

defprotocol Size do
#           ^^^^ entity.name.type.protocol.elixir
  def size(data)
end
defimpl Size, for: Map do
#       ^^^^ entity.name.type.protocol.elixir
#             ^^^^ constant.other.keywords.elixir
#                  ^^^ entity.name.type.protocol.elixir
  def size(map), do: map_size(map)
end

# Remote calls, including one-letter module names.
A.b(1)
# <- entity.name.type.class.elixir
# ^ entity.name.function.elixir
config = [defmodule: 2, def: 1]
#         ^^^^^^^^^^ constant.other.keywords.elixir
#         ^^^^^^^^^^ - meta.module.elixir
Calendar.after?(a, b) and alias?(task)
#        ^^^^^^ entity.name.function.elixir
#                         ^^^^^^ entity.name.function.elixir
quote do: unquote(module).unquote(function)(args)
#         ^^^^^^^ keyword.control.elixir
#                         ^^^^^^^ entity.name.function.elixir
:ets.new(:table, [])
# <---- constant.other.symbol.elixir
#    ^^^ entity.name.function.elixir

# ExUnit describe and test names, for the symbol list.
  describe "get!/1" do
# ^^^^^^^^^^^^^^^^^ meta.describe.elixir
#          ^^^^^^^^ meta.describe.elixir string.quoted.double.elixir
    test "returns the user", %{conn: conn} do
#   ^^^^^^^^^^^^^^^^^^^^^^^ meta.test.elixir
#                          ^ - meta.test.elixir
