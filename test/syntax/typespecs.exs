# SYNTAX TEST "source.elixir" "Typespecs"

defmodule MyApp.Queue do
  @type t :: %__MODULE__{name: String.t(), size: non_neg_integer() | nil}
# ^^^^^ meta.type.elixir keyword.declaration.type.elixir
# ^ keyword.declaration.type.elixir punctuation.definition.keyword.elixir
#       ^ meta.type.elixir entity.name.type.elixir
#         ^^ meta.type.elixir keyword.operator.type.elixir
#             ^^^^^^^^^^ meta.type.elixir variable.language.elixir
#                        ^^^^^ meta.type.elixir constant.other.keywords.elixir
#                              ^^^^^^ meta.type.elixir entity.name.type.class.elixir
#                                     ^ meta.type.elixir storage.type.remote.elixir
#                                                ^^^^^^^^^^^^^^^ meta.type.elixir support.type.elixir
#                                                                  ^ meta.type.elixir keyword.operator.other.elixir
#                                                                    ^^^ meta.type.elixir constant.language.elixir
  @typep state :: {pid(), [term], atom}
# ^^^^^^ keyword.declaration.type.elixir
#        ^^^^^ entity.name.type.elixir
#                  ^^^ support.type.elixir
#                          ^^^^ support.type.elixir
#                                 ^^^^ support.type.elixir
  @opaque queue(value) :: {[value], [value]}
# ^^^^^^^ keyword.declaration.type.elixir
#         ^^^^^ entity.name.type.elixir
#                           ^^^^^ storage.type.custom.elixir
  @type options :: [timeout: timeout(), mode: :sync | :async]
#                   ^^^^^^^^ constant.other.keywords.elixir
#                            ^^^^^^^ support.type.elixir
#                                             ^^^^^ constant.other.symbol.elixir
  @type table :: %{required(atom()) => term(), optional(:x) => :inet.ip_address()}
#                  ^^^^^^^^ keyword.other.required.elixir
#                                              ^^^^^^^^ keyword.other.optional.elixir
#                                                              ^^^^^ constant.other.symbol.elixir
#                                                                    ^^^^^^^^^^ storage.type.remote.elixir
  @type chunk :: <<_::8, _::_*16>> | [...] | (-> term) | 1..10
#                  ^ comment.wildcard.elixir
#                                             ^^ keyword.operator.arrow.elixir
#                                                         ^^ keyword.operator.range.elixir
#                                     ^^^ keyword.operator.ellipsis.elixir

# The spec'd function name, named arguments, and keywords used as names (upstream #173).
  @spec import(Path.t(), keyword()) :: :ok | {:error, reason :: term()}
# ^^^^^ meta.type.elixir keyword.declaration.type.elixir
#       ^^^^^^ meta.type.elixir entity.name.function.spec.elixir
#                   ^ storage.type.remote.elixir
#                        ^^^^^^^ support.type.elixir
#                                                     ^^^^^^ variable.parameter.elixir
#                                                               ^^^^ support.type.elixir
  @callback handle(msg :: term, state) :: {:noreply, state}
# ^^^^^^^^^ keyword.declaration.type.elixir
#           ^^^^^^ entity.name.function.spec.elixir
#                  ^^^ variable.parameter.elixir
#                               ^^^^^ storage.type.custom.elixir
  @macrocallback expand(Macro.t()) :: Macro.t()
# ^^^^^^^^^^^^^^ keyword.declaration.type.elixir
#                ^^^^^^ entity.name.function.spec.elixir
  @spec map(Enumerable.t(), (element -> any)) :: list when element: var
#       ^^^ entity.name.function.spec.elixir
#                            ^^^^^^^ storage.type.custom.elixir
#                                       ^^^ support.type.elixir
#                                                ^^^^ support.type.elixir
#                                                     ^^^^ keyword.operator.elixir
#                                                          ^^^^^^^^ constant.other.keywords.elixir
#                                                                   ^^^ support.type.elixir
  @spec valid?(term) :: boolean
#       ^^^^^^ entity.name.function.spec.elixir
#                       ^^^^^^^ support.type.elixir
  @spec integer + integer :: integer
#       ^^^^^^^ support.type.elixir
#       ^^^^^^^ - entity.name.function.spec.elixir
  @spec not true :: false
#       ^^^ keyword.operator.elixir
#           ^^^^ constant.language.elixir
  @spec unquote(name)(term) :: term
#       ^^^^^^^ keyword.control.elixir

# Formatted specs and unions continue on lines indented deeper than the attribute.
  @spec start_link(
#       ^^^^^^^^^^ entity.name.function.spec.elixir
          GenServer.options()
#                   ^^^^^^^ meta.type.elixir storage.type.remote.elixir
        ) :: GenServer.on_start()
#                      ^^^^^^^^ meta.type.elixir storage.type.remote.elixir
  @type level ::
#       ^^^^^ entity.name.type.elixir
          :emergency
#         ^^^^^^^^^^ meta.type.elixir constant.other.symbol.elixir
          | :alert
#         ^ meta.type.elixir keyword.operator.other.elixir

  def start_link(opts), do: GenServer.start_link(__MODULE__, opts)
# ^^^ - meta.type.elixir
#     ^^^^^^^^^^ entity.name.function.public.elixir
  def run(timeout), do: timeout
#                       ^^^^^^^ - support.type.elixir
end
