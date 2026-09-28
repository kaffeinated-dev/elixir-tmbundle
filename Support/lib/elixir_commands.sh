# Shared helpers for the Elixir commands.
#
# Commands run in the Mix project with the Elixir version configured for it:
# via mise when available (set TM_MISE in Preferences → Variables to override
# its location), otherwise with the PATH TextMate provides. The bundle’s own
# Mix tasks and output formatting are Elixir files in Support/lib/textmate.

ELIXIR_LIB="$TM_BUNDLE_SUPPORT/lib/textmate"
ELIXIR_TEST_STATUSES="0:success:Done.|2:failure:Tests failed."

# Print the Mix project root: the closest directory with a mix.exs, starting
# with the current file’s directory (or the project folder for an untitled
# document).
elixir_mix_root () {
	local dir=${TM_DIRECTORY:-${TM_PROJECT_DIRECTORY:-}}
	while [[ -n "$dir" && "$dir" != / ]]; do
		if [[ -f "$dir/mix.exs" ]]; then
			echo "$dir"
			return 0
		fi
		dir=$(dirname "$dir")
	done
	return 1
}

# Set MIX_ROOT, or show a tool tip and exit when not in a Mix project.
elixir_require_mix_root () {
	MIX_ROOT=$(elixir_mix_root) || elixir_exit_tool_tip "No Mix project found: there is no mix.exs in the current file’s folder or its parents."
}

# Print the path to mise, if installed.
elixir_mise () {
	local candidate
	for candidate in "${TM_MISE:-}" "$(command -v mise)" "$HOME/.local/bin/mise" /opt/homebrew/bin/mise /usr/local/bin/mise; do
		if [[ -n "$candidate" && -x "$candidate" ]]; then
			echo "$candidate"
			return 0
		fi
	done
	return 1
}

# Run a command in a directory with the Elixir version configured for it.
elixir_exec () { # directory, command…
	local dir=$1 mise
	shift
	mise=$(elixir_mise)
	if [[ -z "$mise" ]] && ! command -v elixir >/dev/null; then
		echo "Elixir was not found. Install it with mise, or add the folder with elixir and mix to PATH in Preferences → Variables." >&2
		return 127
	fi
	(
		cd "$dir" || exit 1
		if [[ -n "$mise" ]]; then
			exec "$mise" exec -- "$@"
		else
			exec "$@"
		fi
	)
}

# Run one of the bundle’s Mix tasks (mix textmate.TASK) in a directory.
elixir_mix_task () { # directory, task, arguments…
	local dir=$1 task=$2
	shift 2
	MIX_QUIET=1 elixir_exec "$dir" elixir -r "$ELIXIR_LIB/load.exs" -S mix "textmate.$task" "$@"
}

# The Mix project of the current file, or its folder.
elixir_project_or_folder () {
	elixir_mix_root || echo "${TM_DIRECTORY:-${TM_PROJECT_DIRECTORY:-${TMPDIR:-/tmp}}}"
}

# Is a TM_ELIXIR_… setting on? (1, true, yes, on)
elixir_enabled () {
	case "$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')" in
		1|true|yes|on) return 0 ;;
		*)             return 1 ;;
	esac
}

# Tool tips are printed to stderr, as the standard output of HTML commands goes
# to their window.
elixir_exit_tool_tip () { printf '%s' "$1" >&2; exit 206; }
elixir_exit_discard  () { exit 200; }

# ==============
# = Formatting =
# ==============

# Format the document (standard input) as `mix format` would, with the settings
# and plugins of its project. Prints the formatted document and exits 0, exits
# 200 when it is already formatted, or shows why it could not be formatted.
elixir_format () {
	local dir file tmp rc reason
	dir=$(elixir_mix_root) || dir=${TM_DIRECTORY:-${TMPDIR:-/tmp}}
	file=${TM_FILEPATH:-}
	if [[ -z "$file" ]]; then
		file="$dir/untitled.exs"
		[[ "${TM_SCOPE:-}" == text.html.heex* ]] && file="$dir/untitled.heex"
	fi

	tmp=$(mktemp -d "${TMPDIR:-/tmp}/textmate-elixir.XXXXXX") || exit 1
	trap 'rm -rf "$tmp"' EXIT
	cat > "$tmp/input"

	elixir_mix_task "$dir" format "$file" "$tmp/output" < "$tmp/input" > /dev/null 2> "$tmp/errors"
	rc=$?

	if [[ $rc -ne 0 ]]; then
		reason=$(grep -m 1 '^Not formatted: ' "$tmp/errors" || grep -m 1 '^\*\* (' "$tmp/errors" || grep -v '^[[:space:]]*$' "$tmp/errors" | tail -n 1)
		reason=${reason#Not formatted: }
		elixir_exit_tool_tip "Not formatted: ${reason#\*\* (Mix) }"
	fi

	cmp -s "$tmp/input" "$tmp/output" && exit 200
	cat "$tmp/output"
	exit 0
}

# ===========
# = Testing =
# ===========

# Print the test for the current file, relative to MIX_ROOT: the file itself
# when it is a test, otherwise its test (lib/my_app/user.ex → test/my_app/user_test.exs).
elixir_test_file () {
	local file=${TM_FILEPATH#"$MIX_ROOT"/} test
	case "$file" in
		*_test.exs) echo "$file"; return 0 ;;
		lib/*.ex)   test="test/${file#lib/}"; test="${test%.ex}_test.exs" ;;
		*)          return 1 ;;
	esac
	[[ -f "$MIX_ROOT/$test" ]] && echo "$test"
}

# ===============
# = HTML output =
# ===============

# Run a command in a directory and show its output in an HTML window, with
# colors, and file references linked. The shown command defaults to the one run.
elixir_html () { # directory, title, shown command, statuses (see html.ex), command…
	local dir=$1
	shift
	elixir_exec "$dir" elixir -r "$ELIXIR_LIB/load.exs" -e 'TextMate.HTML.main()' -- "$@"
	exit 0
}

# ===============
# = Compilation =
# ===============

# Compile MIX_ROOT, showing the output, and the warnings and errors as marks.
elixir_compile () {
	elixir_html "$MIX_ROOT" "Compile" "mix compile" "0:success:Compiled.|1:failure:Compilation failed." \
		elixir -r "$ELIXIR_LIB/load.exs" -S mix textmate.compile
}

# Compile MIX_ROOT in the background, only updating the marks.
elixir_compile_in_background () {
	( elixir_mix_task "$MIX_ROOT" compile </dev/null >/dev/null 2>&1 & )
}

# ==========================
# = Documentation and code =
# ==========================

# Show the documentation of the selection, or of the code at the caret (the
# document is the standard input), in an HTML window.
elixir_docs () {
	local dir html errors
	dir=$(elixir_project_or_folder)
	errors=$(mktemp "${TMPDIR:-/tmp}/textmate-elixir.XXXXXX") || exit 1
	trap 'rm -f "$errors"' EXIT

	if [[ -n "${TM_SELECTED_TEXT:-}" ]]; then
		html=$(elixir_mix_task "$dir" docs page --reference "$TM_SELECTED_TEXT" </dev/null 2> "$errors")
	else
		html=$(elixir_mix_task "$dir" docs page "${TM_FILEPATH:-}" "${TM_LINE_NUMBER:-1}" "${TM_LINE_INDEX:-0}" 2> "$errors")
	fi || elixir_exit_tool_tip "$(grep -v '^[[:space:]]*$' "$errors" | tail -n 1)"

	printf '%s' "$html"
	exit 0
}

# Open the definition of the code at the caret (the document is the standard input).
elixir_go_to_definition () {
	local dir result errors
	dir=$(elixir_project_or_folder)
	errors=$(mktemp "${TMPDIR:-/tmp}/textmate-elixir.XXXXXX") || exit 1
	trap 'rm -f "$errors"' EXIT

	result=$(elixir_mix_task "$dir" definition "${TM_FILEPATH:-}" "${TM_LINE_NUMBER:-1}" "${TM_LINE_INDEX:-0}" 2> "$errors") ||
		elixir_exit_tool_tip "$(grep -v '^[[:space:]]*$' "$errors" | tail -n 1)"

	"$TM_MATE" -l "${result%%$'\t'*}" "${result#*$'\t'}" >/dev/null 2>&1
	exit 200
}

# ==============
# = Navigation =
# ==============

# Open the test of the current file (lib/my_app/user.ex → test/my_app/user_test.exs),
# or the file of the current test. A missing test can be created.
elixir_go_to_test () {
	elixir_require_mix_root
	local file=${TM_FILEPATH#"$MIX_ROOT"/} other
	case "$file" in
		test/*_test.exs) other="lib/${file#test/}"; other="${other%_test.exs}.ex" ;;
		lib/*.ex)        other="test/${file#lib/}"; other="${other%.ex}_test.exs" ;;
		*)               elixir_exit_tool_tip "Go to Test works in the lib and test folders." ;;
	esac

	if [[ ! -f "$MIX_ROOT/$other" ]]; then
		[[ "$other" == test/* ]] || elixir_exit_tool_tip "There is no $other."
		elixir_confirm "Create $other?" "There is no test for $file yet." "Create Test" || elixir_exit_discard
		elixir_create_test "$file" "$other"
	fi

	"$TM_MATE" "$MIX_ROOT/$other" >/dev/null 2>&1
	exit 200
}

# Write a test module for a module (paths relative to MIX_ROOT). Tests of web
# modules use the ConnCase of Phoenix projects, other tests their DataCase,
# and doctests run when the module has examples.
elixir_create_test () { # file, test
	local module template support options=", async: true" doctest=""
	module=$(sed -n -E 's/^[[:space:]]*defmodule[[:space:]]+([A-Za-z0-9_.]+)[[:space:]]+do.*/\1/p' "$MIX_ROOT/$1" | head -n 1)
	[[ -n "$module" ]] || elixir_exit_tool_tip "There is no module in $1."

	template=ExUnit.Case
	case "$1" in
		lib/*_web/*|lib/*_web.ex) support=conn_case ;;
		*)                        support=data_case ;;
	esac
	if [[ -f "$MIX_ROOT/test/support/$support.ex" ]]; then
		template=$(sed -n -E 's/^defmodule[[:space:]]+([A-Za-z0-9_.]+)[[:space:]]+do.*/\1/p' "$MIX_ROOT/test/support/$support.ex" | head -n 1)
		options=""
	fi
	grep -q 'iex>' "$MIX_ROOT/$1" && doctest=$'\n  doctest '"$module"$'\n'

	mkdir -p "$(dirname "$MIX_ROOT/$2")"
	printf 'defmodule %sTest do\n  use %s%s\n%s\n  alias %s\nend\n' "$module" "${template:-ExUnit.Case}" "$options" "$doctest" "$module" > "$MIX_ROOT/$2"
}

# Ask for confirmation in an alert: title, message, button. Returns 0 when the
# button was clicked.
elixir_confirm () {
	"$DIALOG" alert --alertStyle informational --title "$1" --body "$2" --button1 "$3" --button2 Cancel |
		tr -d '\n\t' | grep -q '<key>buttonClicked</key><integer>0</integer>'
}

# Open IEx in Terminal, in the project (iex -S mix) or the file’s folder.
elixir_open_iex () {
	local dir command mise
	if dir=$(elixir_mix_root); then command="iex -S mix"; else dir=$(elixir_project_or_folder); command=iex; fi
	mise=$(elixir_mise) && command="$(printf '%q' "$mise") exec -- $command"
	command="cd $(printf '%q' "$dir") && $command"
	command=${command//\\/\\\\}
	command=${command//\"/\\\"}
	osascript -e "tell application \"Terminal\" to do script \"$command\"" -e 'tell application "Terminal" to activate' >/dev/null ||
		elixir_exit_tool_tip "Could not open Terminal."
	exit 200
}

# ===================
# = Language server =
# ===================

# Send a request about the code at the caret to the document’s language server
# (through TextMate) and convert the response with language_server.js. Shows
# why, and exits, when it can’t.
elixir_language_server () { # method, conversion (completions or hover)
	local response output
	response=$("$TM_MATE" --lsp "$1" --line "${TM_LINE_NUMBER:-1}:$(( ${TM_LINE_INDEX:-0} + 1 ))" 2>&1) ||
		elixir_exit_tool_tip "This needs TextMate 2.0.23+kaffeinated.3 or later, with the language server client."
	output=$(printf '%s' "$response" | osascript -l JavaScript "$TM_BUNDLE_SUPPORT/lib/language_server.js" "$2" 2>&1) ||
		elixir_exit_tool_tip "$(printf '%s' "$output" | sed -E 's/.*execution error: (Error: )*//; s/ \(-?[0-9]+\)$//')"
	printf '%s' "$output"
}

# Show the language server’s completions of the word at the caret in a popup.
# Choosing one completes it, with placeholders for its arguments.
elixir_complete () {
	local typed="" suggestions
	if (( ${TM_LINE_INDEX:-0} > 0 )); then
		typed=$(printf '%s' "${TM_CURRENT_LINE:-}" | head -c "$TM_LINE_INDEX" | sed -E 's/.*[^[:alnum:]_?!]//')
	fi
	suggestions=$(elixir_language_server textDocument/completion completions) || exit
	[[ -n "$suggestions" ]] || elixir_exit_tool_tip "No completions."
	"$DIALOG" popup --suggestions "$suggestions" --alreadyTyped "$typed" --additionalWordCharacters '?!'
	exit 200
}

# Show what the language server knows about the code at the caret (its type
# and documentation) in a tool tip.
elixir_hover () {
	local html
	html=$(elixir_language_server textDocument/hover hover) || exit
	[[ -n "$html" ]] || elixir_exit_tool_tip "No information about this."
	"$DIALOG" tooltip --html "$html"
	exit 200
}
