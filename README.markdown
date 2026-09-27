# Elixir.tmbundle

A **TextMate / Sublime Text Bundle** for the [**Elixir**](http://github.com/elixir-editors/elixir) programming language.

It provides syntax highlighting, snippets, and keybindings. Contributions and extensions are welcome!

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


## Development

Grammar changes are covered by scope tests in `test/syntax`. Each file starts with a `# SYNTAX TEST "source.elixir"` header, and lines with `^` markers assert the scopes of the source line above them (see [vscode-tmgrammar-test](https://github.com/PanAeon/vscode-tmgrammar-test)). Run them with:

    npm install
    npm test

The tests use the HTML grammar from [textmate/html.tmbundle](https://github.com/textmate/html.tmbundle), pinned in `test/fetch-grammars` to the revision that TextMate installs.
