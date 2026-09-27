defmodule MyApp.Accounts do
  @moduledoc """
  Accounts and **users**.

  ## Examples

      iex> MyApp.Accounts.get(1)
      %User{id: 1}

  """

  alias MyApp.{Repo, User}

  @type id :: pos_integer()
  @typep row :: {id(), String.t()}

  @callback fetch(id) :: {:ok, User.t()} | :error

  @doc """
  Gets a user, raising when it doesn't exist.
  """
  @spec get!(id) :: User.t()
  def get!(id) do
    # Look the user up, then decide what to do
    case Repo.get(User, id) do
      nil -> raise ArgumentError, "no user #{id}"
      user -> user
    end
  end

  def create(attrs \\ %{}) do
    changeset =
      User.changeset(%User{}, attrs)

    if changeset.valid? do
      Repo.insert(changeset)
    else
      {:error, changeset}
    end
  end

  def names(users) do
    users
    |> Enum.map(fn user ->
      user.name
    end)
    |> Enum.sort()
  end

  def options do
    [
      timeout: 5_000,
      retries: 3
    ]
  end

  def config do
    %{
      name: "accounts",
      pool: pool_size()
    }
  end

  def greeting(user) do
    "Hello " <>
      user.name
  end

  defp pool_size, do: 10

  defp safely(fun) do
    try do
      fun.()
    rescue
      e in RuntimeError -> {:error, e}
    after
      :ok
    end
  end

  defp wait do
    receive do
      {:done, result} -> result
    after
      1_000 -> :timeout
    end
  end

  defmacro __using__(_opts) do
    quote do
      import MyApp.Accounts
    end
  end

  def query do
    """
    SELECT * FROM users
    """
  end

  def render(assigns) do
    ~H"""
    <div class="accounts">
      <.table rows={@users}>
        <:col :let={user} label="Name">{user.name}</:col>
      </.table>
      <p :if={@empty}>
        No users yet.
      </p>
    </div>
    """
  end
end

defprotocol MyApp.Nameable do
  def name(data)
end

defimpl MyApp.Nameable, for: MyApp.User do
  def name(user), do: user.name
end
