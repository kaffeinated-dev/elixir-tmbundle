# Elixir.tmbundle

A **TextMate / Sublime Text Bundle** for the [**Elixir**](http://github.com/elixir-editors/elixir) programming language.

It provides syntax highlighting, snippets, and commands to run tests, compile, and format code. Contributions and extensions are welcome!

> **Note:** For a package that provides tighter and more up-to-date integration with Sublime Text 4, see [ElixirSyntax](https://packagecontrol.io/packages/ElixirSyntax).

## Installation

If you are using **TextMate 2** you can install from Preferences → Bundles. To install manually type the following commands in your shell:

    mkdir -p ~/Library/Application\ Support/TextMate/Pristine\ Copy/Bundles
    cd ~/Library/Application\ Support/TextMate/Pristine\ Copy/Bundles
    git clone git://github.com/elixir-editors/elixir-tmbundle Elixir.tmbundle

If you are using **Sublime Text 3**, type the following commands in your shell:

    cd ~/.config/sublime-text-3/Packages # If you are on Linux
    cd ~/Library/Application\ Support/Sublime\ Text\ 3/Packages # If you are on OS X
    cd %HOMEPATH%\AppData\Roaming\Sublime^ Text^ 3\Packages # If you are on Windows Vista or above
    cd %HOMEPATH%\Application^ Data\Sublime^ Text^ 3\Packages # If you are on Windows XP
    git clone git://github.com/elixir-editors/elixir-tmbundle Elixir

You can now use Elixir's color syntax in files. In some cases, you should restart Sublime Text to make changes work.

## Installation for outdated editors

Type the following commands to setup the bundle for **TextMate 1**:

    mkdir -p ~/Library/Application\ Support/TextMate/Bundles
    cd !$
    git clone git://github.com/elixir-editors/elixir-tmbundle Elixir.tmbundle
    cd Elixir.tmbundle
    git checkout tm1
    osascript -e 'tell app "TextMate" to reload bundles'

If you are using **Sublime Text 2**, type the following commands in your shell:

    cd ~/.config/sublime-text-2/Packages # If you are on Linux
    cd ~/Library/Application\ Support/Sublime\ Text\ 2/Packages # If you are on OS X
    cd %HOMEPATH%\AppData\Roaming\Sublime^ Text^ 2\Packages # If you are on Windows Vista or above
    cd %HOMEPATH%\Application^ Data\Sublime^ Text^ 2\Packages # If you are on Windows XP
    git clone git://github.com/elixir-editors/elixir-tmbundle Elixir
    cd Elixir
    git checkout tm1

## Code formatting for Sublime Text 3

Elixir v1.6 includes a code formatter. This package includes `super+shift+c` as a keybinding to automatically save and format the current file you are working on. If the file has invalid syntax, an alert will appear.

You can also add your own keybindings as follows:

    { "keys": ["super+e"], "command": "mix_format_file" }

You can also set up the package to automatically format the file on save. To do this,
go to Preferences -> Package Settings -> Elixir -> Settings and add
`"mix_format_on_save": true`.


## Commands

In TextMate, the commands run Mix in the project of the current file (the closest folder with a `mix.exs`), with the Elixir version set for the project by [mise](https://mise.jdx.dev) when it is installed, and otherwise with the `elixir` and `mix` found on the `PATH` set in Preferences → Variables.

| Command | Key | |
|---|---|---|
| Run | ⌘R | Runs the tests of a test file, or of the test of a file in `lib`. Runs a script with `mix run` in a project, and with `elixir` outside of one. |
| Run Test at Caret | ⇧⌘R | Runs the test or `describe` block at the caret. |
| Run All Tests, Run Failed Tests, Run Stale Tests | ⌃\\ | Runs `mix test`, `mix test --failed`, or `mix test --stale`. |
| Compile | ⌘B | Compiles the project and marks its warnings and errors in the gutter. Click a mark to read its message, and press F3 to jump to the next mark. |
| Format Document | ⌃⇧H | Formats the document like `mix format`, with the settings and plugins in the project’s `.formatter.exs` (such as the HEEx formatter). |

Output appears in a window, in color, and its file references, such as `test/my_app/user_test.exs:12` or those in stacktraces of dependencies and Elixir itself, open in TextMate when clicked.

Files are formatted when saved, if their project has a `.formatter.exs`. These variables, set in Preferences → Variables or in a project’s `.tm_properties`, change what happens:

* `TM_ELIXIR_FORMAT_ON_SAVE = false` stops formatting on save.
* `TM_ELIXIR_COMPILE_ON_SAVE = true` compiles the project in the background after saving, updating the marks in the gutter. It is off by default because a server running in the project, such as `mix phx.server`, only reloads code compiled by another process when the project has `listeners: [Phoenix.CodeReloader]` in `mix.exs`, as projects created with Phoenix 1.8 do.
* `TM_MISE` is the path to mise, when it is not in `~/.local/bin`, `/opt/homebrew/bin`, or `/usr/local/bin`.

## Snippets

Snippets expand in Elixir code and in `{expressions}` of templates, not in strings, comments, or template text. Type the trigger and press ⇥.

* **Definitions:** `defmod` defmodule, `def` def, `defp` defp, `df` def (one line), `dfp` defp (one line), `defm` defmacro, `defmp` defmacrop, `defg` defguard, `defd` defdelegate, `defs` defstruct, `defe` defexception, `defpro` defprotocol, `defi` defimpl
* **Attributes:** `mdoc` @moduledoc, `doc` @doc, `typedoc` @typedoc, `spec` @spec, `type` @type, `cb` @callback, `impl` @impl, `beh` @behaviour
* **Conditionals:** `if` if, `ife` if … else, `if:` if (one line), `ife:` if … else (one line), `case` case, `cond` cond, `with` with, `withe` with … else, `try` try … rescue, `rec` receive, `for` for
* **Structure:** `al` alias, `imp` import, `req` require, `use` use, `do` do … end, `fn` fn, `quote` quote, `kv` key => value, `%` map / struct, `i` inspect, `ii` IO.inspect, `iil` IO.inspect with label, `dbg` dbg, `pry` IEx.pry
* **OTP:** `genserver` GenServer, `hcall` handle_call, `hcast` handle_cast, `hinfo` handle_info, `supervisor` Supervisor
* **Testing:** `exu` ExUnit test module, `describe` describe, `test` test, `testc` test with context, `setup` setup, `setupa` setup_all, `ar` assert_raise, `arec` assert_receive, `doct` doctest
* **Phoenix:** `lv` LiveView, `mount` mount, `hparams` handle_params, `hevent` handle_event, `render` render, `comp` function component, `attr` attr, `slot` slot, `~H` ~H template, `schema` Ecto schema, `field` Ecto field, `changeset` Ecto changeset

`defmod` names the module after the file: `lib/my_app/accounts/user.ex` becomes `MyApp.Accounts.User`, `lib/my_app_web/live/user_live/index.ex` becomes `MyAppWeb.UserLive.Index`.

## Development

Grammar changes are covered by scope tests in `test/syntax`. Each file starts with a `# SYNTAX TEST "source.elixir"` header, and lines with `^` markers assert the scopes of the source line above them (see [vscode-tmgrammar-test](https://github.com/PanAeon/vscode-tmgrammar-test)). Run them with:

    npm install
    npm test

`test/editing` checks indentation, folding, and the symbol list of the files next to it. It computes them from the preferences the way TextMate does, including how it picks a preference for a scope, so every line of those files must be indented as it is, and the folds and symbols must match the `.folds` and `.symbols` snapshots. After an intended change, rewrite the snapshots with `node test/editing/test.js --update` and review the diff.

`npm run test:snippets` expands every snippet with its default text, as TextMate does, and checks with Elixir that the code parses and is already formatted.

The tests use the HTML grammar from [textmate/html.tmbundle](https://github.com/textmate/html.tmbundle), pinned in `test/fetch-grammars` to the revision that TextMate installs.
