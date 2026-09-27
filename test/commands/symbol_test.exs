defmodule TextMate.SymbolTest do
  use ExUnit.Case, async: false

  alias TextMate.{Definition, Symbol}

  @document """
  defmodule MyApp.PageLive do
    alias MyApp.{Accounts, Repo}
    alias MyApp.Accounts.User, as: U
    import Enum, only: [map: 2]

    @topic "pages"

    defmodule Inner do
    end

    def mount(socket) do
      users = Repo.all(U)
      Enum.map(users, &to_string/1) |> IO.inspect()
      :lists.reverse(users) && %U{} && Inner.new() && __MODULE__.Inner.new()
      map(users, & &1) && helper(@topic) && is_nil(socket) && ~H"<.header>x</.header>"
    end

    defp helper(topic), do: topic
  end
  """

  # The target where `text` starts on a line (with an offset into it).
  defp at(line, text, offset \\ 0) do
    index =
      (@document |> String.split("\n") |> Enum.at(line - 1) |> :binary.match(text) |> elem(0)) +
        offset

    {target, env} = Symbol.at(@document, line, index)
    Symbol.resolve(target, env)
  end

  test "aliases are expanded" do
    assert at(12, "Repo") == {:module, MyApp.Repo}
    assert at(12, "all") == {:function, MyApp.Repo, :all, nil}
    assert at(12, "U)") == {:module, MyApp.Accounts.User}
    assert at(14, "%U") == {:module, MyApp.Accounts.User}
    assert at(14, "Inner.new") == {:module, MyApp.PageLive.Inner}
    assert at(14, "new() && __MODULE__") == {:function, MyApp.PageLive.Inner, :new, nil}
    assert at(14, "Inner.new() && __MODULE__", 33) == {:function, MyApp.PageLive.Inner, :new, nil}
  end

  test "remote calls, captures, and Erlang modules" do
    assert at(13, "map(users, &") == {:function, Enum, :map, nil}
    assert at(13, "to_string") == {:function, Kernel, :to_string, 1}
    assert at(14, "reverse") == {:function, :lists, :reverse, nil}
    assert at(13, "inspect") == {:function, IO, :inspect, nil}
  end

  test "local calls are imported, from Kernel, or special forms" do
    assert at(15, "map(users, & &1)") == {:function, Enum, :map, nil}
    assert at(15, "is_nil") == {:function, Kernel, :is_nil, nil}
    assert at(13, "|>", 1) == {:function, Kernel, :|>, nil}
    assert at(15, "helper") == {:function, nil, :helper, nil}
  end

  test "attributes, sigils, and HEEx components" do
    assert at(15, "@topic", 1) == {:attribute, :topic}
    assert at(15, "~H", 1) == {:function, nil, :sigil_H, 2}
    assert at(15, ".header>", 2) == {:function, nil, :header, 1}
  end

  test "a caret just after a name is on it" do
    assert at(12, "all(", 3) == {:function, MyApp.Repo, :all, nil}
  end

  test "references are parsed" do
    assert Symbol.parse("Enum.map/2") == {:function, Enum, :map, 2}
    assert Symbol.parse("Enum") == {:module, Enum}
    assert Symbol.parse(":lists.reverse/1") == {:function, :lists, :reverse, 1}

    assert Symbol.parse("Kernel.SpecialForms.case/2") ==
             {:function, Kernel.SpecialForms, :case, 2}

    assert Symbol.parse("map/2") == {:function, nil, :map, 2}
  end

  describe "use" do
    setup do
      root =
        Path.join(System.tmp_dir!(), "textmate-symbol-test-#{System.unique_integer([:positive])}")

      File.mkdir_p!(Path.join(root, "lib"))

      File.write!(Path.join(root, "lib/my_web.ex"), """
      defmodule MyWeb do
        def live_view do
          quote do
            use Phoenix.LiveView
            unquote(helpers())
          end
        end

        def controller do
          quote do
            import Plug.Conn
          end
        end

        defp helpers do
          quote do
            import Enum
            alias String.Chars, as: Chars
          end
        end

        defmacro __using__(which) when is_atom(which), do: apply(__MODULE__, which, [])
      end
      """)

      File.write!(Path.join(root, "lib/case_template.ex"), """
      defmodule MyApp.DataCase do
        use ExUnit.CaseTemplate

        using do
          quote do
            import Map
          end
        end
      end
      """)

      on_exit(fn -> File.rm_rf!(root) end)
      %{root: root}
    end

    test "brings what the used module's function quotes", %{root: root} do
      env =
        File.cd!(root, fn -> Symbol.file_env("defmodule A do\n  use MyWeb, :live_view\nend\n") end)

      assert Enum in env.imports
      refute Plug.Conn in env.imports
      assert env.aliases["Chars"] == String.Chars
      assert Phoenix.LiveView in env.uses
    end

    test "of a case template brings its using block and ExUnit.Case", %{root: root} do
      env =
        File.cd!(root, fn ->
          Symbol.file_env("defmodule ATest do\n  use MyApp.DataCase\nend\n")
        end)

      assert Map in env.imports

      assert Symbol.resolve({:function, nil, :assert, nil}, env) ==
               {:function, ExUnit.Assertions, :assert, nil}

      assert Symbol.resolve({:function, nil, :test, nil}, env) ==
               {:function, ExUnit.Case, :test, nil}
    end
  end

  describe "definitions" do
    test "of local functions and attributes are in the document" do
      assert Definition.find({:function, nil, :helper, nil}, %Symbol{}, @document, "/a.ex", "/") ==
               {:ok, "/a.ex", 18}

      assert Definition.find({:attribute, :topic}, %Symbol{}, @document, "/a.ex", "/") ==
               {:ok, "/a.ex", 6}

      assert {:error, "@nope is not set in this file."} =
               Definition.find({:attribute, :nope}, %Symbol{}, @document, "/a.ex", "/")
    end

    test "of modules in the project are found without compiling" do
      root =
        Path.join(
          System.tmp_dir!(),
          "textmate-definition-test-#{System.unique_integer([:positive])}"
        )

      File.mkdir_p!(Path.join(root, "lib/my_app"))
      # The real path, as the temporary folder may be a symbolic link.
      root = File.cd!(root, &File.cwd!/0)

      File.write!(
        Path.join(root, "lib/my_app/user.ex"),
        "defmodule MyApp.User do\n  @moduledoc false\n\n  def name(user), do: user.name\nend\n"
      )

      file = Path.join(root, "lib/my_app/user.ex")
      assert Definition.find({:module, MyApp.User}, %Symbol{}, "", nil, root) == {:ok, file, 1}

      assert Definition.find({:function, MyApp.User, :name, 1}, %Symbol{}, "", nil, root) ==
               {:ok, file, 4}

      File.rm_rf!(root)
    end

    test "of Elixir and Erlang/OTP are in their source" do
      if Symbol.source_file(Enum) do
        assert {:ok, file, line} =
                 Definition.find({:function, Enum, :map, 2}, %Symbol{}, "", nil, "/")

        assert String.ends_with?(file, "lib/elixir/lib/enum.ex")
        assert File.read!(file) |> String.split("\n") |> Enum.at(line - 1) =~ "def map("
      end

      if Symbol.source_file(:lists) do
        assert {:ok, file, line} =
                 Definition.find({:function, :lists, :reverse, 1}, %Symbol{}, "", nil, "/")

        assert File.read!(file) |> String.split("\n") |> Enum.at(line - 1) =~ ~r/^reverse\(/
      end
    end
  end
end
