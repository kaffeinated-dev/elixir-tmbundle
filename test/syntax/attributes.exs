# SYNTAX TEST "source.elixir" "Module attributes"
!!
defmodule MyApp.Server do
  @behaviour GenServer
# ^^^^^^^^^^ support.attr.elixir
# ^ support.attr.elixir punctuation.definition.attribute.elixir
#            ^^^^^^^^^ entity.name.type.class.elixir
  @derive {Jason.Encoder, only: [:name]}
# ^^^^^^^ support.attr.elixir
  @enforce_keys [:name]
# ^^^^^^^^^^^^^ support.attr.elixir
  @impl true
# ^^^^^ support.attr.elixir
#       ^^^^ constant.language.elixir
  @impl GenServer
# ^^^^^ support.attr.elixir
  @compile {:inline, size: 1}
# ^^^^^^^^ support.attr.elixir
  @before_compile MyApp.Hooks
# ^^^^^^^^^^^^^^^ support.attr.elixir
  @after_verify MyApp.Hooks
# ^^^^^^^^^^^^^ support.attr.elixir
  @deprecated "Use start/1"
# ^^^^^^^^^^^ support.attr.elixir
  @external_resource "priv/data.json"
# ^^^^^^^^^^^^^^^^^^ support.attr.elixir
  @optional_callbacks [format: 1]
# ^^^^^^^^^^^^^^^^^^^ support.attr.elixir
  @dialyzer {:nowarn_function, run: 0}
# ^^^^^^^^^ support.attr.elixir
  @moduletag :integration
# ^^^^^^^^^^ support.attr.elixir
  @tag timeout: 1_000
# ^^^^ support.attr.elixir
!!
# Other attributes are variables.
  @default_timeout 5_000
# ^^^^^^^^^^^^^^^^ variable.other.readwrite.module.elixir
# ^ variable.other.readwrite.module.elixir punctuation.definition.variable.elixir
  @impl_details true
# ^^^^^^^^^^^^^ variable.other.readwrite.module.elixir
  def timeout, do: @default_timeout
#                  ^^^^^^^^^^^^^^^^ variable.other.readwrite.module.elixir
end
