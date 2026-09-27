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

	MIX_QUIET=1 elixir_exec "$dir" elixir -r "$ELIXIR_LIB/format.ex" -S mix textmate.format "$file" "$tmp/output" < "$tmp/input" > /dev/null 2> "$tmp/errors"
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
	elixir_exec "$dir" elixir -r "$ELIXIR_LIB/html.ex" -e 'TextMate.HTML.main()' -- "$@"
	exit 0
}

# ===============
# = Compilation =
# ===============

# Compile MIX_ROOT, showing the output, and the warnings and errors as marks.
elixir_compile () {
	elixir_html "$MIX_ROOT" "Compile" "mix compile" "0:success:Compiled.|1:failure:Compilation failed." \
		elixir -r "$ELIXIR_LIB/marks.ex" -r "$ELIXIR_LIB/compile.ex" -S mix textmate.compile
}

# Compile MIX_ROOT in the background, only updating the marks.
elixir_compile_in_background () {
	( elixir_exec "$MIX_ROOT" elixir -r "$ELIXIR_LIB/marks.ex" -r "$ELIXIR_LIB/compile.ex" -S mix textmate.compile </dev/null >/dev/null 2>&1 & )
}
