// Converts responses of the language server (mate --lsp, JSON on the standard
// input) for TextMate:
//
//     osascript -l JavaScript language_server.js completions
//         Suggestions for "$DIALOG" popup (a property list): the label shown
//         (display), the name typed (match), and what follows the name,
//         inserted as a snippet (insert), such as its arguments.
//
//     osascript -l JavaScript language_server.js hover
//         The hover information as HTML for "$DIALOG" tooltip, or nothing.
//
//     osascript -l JavaScript language_server.js references ROOT TITLE
//         The locations as a page for TextMate’s HTML window: by file (relative
//         to ROOT), their lines linked to open them. Nothing without any.
//
//     osascript -l JavaScript language_server.js actions
//         The titles of code actions, as items for "$DIALOG" menu (their value
//         is their index), or nothing.
//
//     osascript -l JavaScript language_server.js action INDEX
//         What running the action takes: “edit” and the params of
//         workspace/applyEdit, or “command” and those of workspace/executeCommand.
//
//     osascript -l JavaScript language_server.js applied
//         Nothing when an edit was applied; an error with the reason otherwise.
//
//     osascript -l JavaScript language_server.js symbols ROOT
//         Symbols (of workspace/symbol) as items for "$DIALOG" menu, whose value
//         is LINE:COLUMN, a tab, and the file.
//
// An error response is an error, with the server’s message.

ObjC.import('Foundation');

function run(argv) {
	const input = $.NSString.alloc.initWithDataEncoding($.NSFileHandle.fileHandleWithStandardInput.readDataToEndOfFile, $.NSUTF8StringEncoding).js;
	const response = JSON.parse(input);
	if (response.error)
		throw new Error(response.error.message.split('\n')[0]);
	switch (argv[0]) {
		case 'hover':      return hover(response.result);
		case 'references': return references(response.result, argv[1], argv[2]);
		case 'actions':    return actions(response.result);
		case 'action':     return action(response.result, Number(argv[1]));
		case 'symbols':    return symbols(response.result, argv[1]);
		case 'applied':    return applied(response.result);
		default:           return completions(response.result);
	}
}

function plist(value) {
	const data = $.NSPropertyListSerialization.dataWithPropertyListFormatOptionsError($(value), $.NSPropertyListXMLFormat_v1_0, 0, null);
	return $.NSString.alloc.initWithDataEncoding(data, $.NSUTF8StringEncoding).js;
}

function pathOf(uri) {
	return $.NSURL.URLWithString(uri).path.js;
}

function relative(path, root) {
	return root && path.startsWith(root + '/') ? path.slice(root.length + 1) : path;
}

const escapeHTML = text => text.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');

function references(result, root, title) {
	const locations = (result || []).filter(location => location && location.uri && location.range);
	if (locations.length === 0)
		return '';

	const files = new Map();
	for (const location of locations) {
		const path = pathOf(location.uri);
		if (!files.has(path))
			files.set(path, []);
		files.get(path).push(location.range.start);
	}

	const sections = [...files.keys()].sort((a, b) => relative(a, root).localeCompare(relative(b, root))).map(path => {
		const text = $.NSString.stringWithContentsOfFileEncodingError(path, $.NSUTF8StringEncoding, null);
		const lines = text.isNil() ? [] : text.js.split('\n');
		const items = files.get(path).sort((a, b) => a.line - b.line || a.character - b.character).map(start => {
			const url = `txmt://open?url=file://${encodeURI(path).replace(/#/g, '%23').replace(/&/g, '%26')}&line=${start.line + 1}&column=${start.character + 1}`;
			const line = (lines[start.line] || '').trim();
			return `<li><a href="${escapeHTML(url)}"><span class="line">${start.line + 1}</span> <code>${escapeHTML(line)}</code></a></li>`;
		});
		return `<h2>${escapeHTML(relative(path, root))}</h2>\n<ul>\n${items.join('\n')}\n</ul>`;
	});

	const count = `${locations.length} reference${locations.length === 1 ? '' : 's'} in ${files.size} file${files.size === 1 ? '' : 's'}`;
	return `<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<title>${escapeHTML(title)}</title>
<style>
	:root { color-scheme: light dark; --muted: #6e6e6e; --link: #1f5fd1; --hover: rgba(127, 127, 127, .15); }
	@media (prefers-color-scheme: dark) { :root { --muted: #9a9a9a; --link: #7aa7ff; } }
	body { font: 13px -apple-system, sans-serif; margin: 1.5em; }
	h1 { font-size: 1.3em; margin: 0 0 .2em; }
	.meta { color: var(--muted); margin: 0 0 1em; }
	h2 { font-size: 1em; margin: 1.2em 0 .3em; }
	ul { list-style: none; margin: 0; padding: 0; }
	li a { display: block; padding: .15em .4em; border-radius: 4px; color: inherit; text-decoration: none; }
	li a:hover { background: var(--hover); }
	.line { display: inline-block; min-width: 3em; text-align: right; color: var(--muted); font: 12px ui-monospace, Menlo, monospace; }
	code { font: 12px ui-monospace, Menlo, monospace; }
</style>
</head>
<body>
<h1>${escapeHTML(title)}</h1>
<p class="meta">${count}</p>
${sections.join('\n')}
</body>
</html>
`;
}

function actions(result) {
	const items = (result || []).map((action, index) => ({ title: action && action.title, value: String(index) })).filter(item => item.title);
	return items.length ? plist(items) : '';
}

function action(result, index) {
	const chosen = (result || [])[index];
	if (!chosen)
		throw new Error('There is no such action.');
	// A Command has a string command; a CodeAction may have an edit, a command, or both.
	if (typeof chosen.command === 'string')
		return 'command\n' + JSON.stringify({ command: chosen.command, arguments: chosen.arguments || [] });
	if (chosen.edit)
		return 'edit\n' + JSON.stringify({ label: chosen.title, edit: chosen.edit }) + (chosen.command ? '\n' + JSON.stringify({ command: chosen.command.command, arguments: chosen.command.arguments || [] }) : '');
	if (chosen.command)
		return 'command\n' + JSON.stringify({ command: chosen.command.command, arguments: chosen.command.arguments || [] });
	throw new Error('The action has nothing to do.');
}

function symbols(result, root) {
	const kinds = { 2: 'module', 5: 'class', 6: 'method', 10: 'enum', 11: 'interface', 12: 'function', 13: 'variable', 14: 'constant', 22: 'struct', 23: 'event', 24: 'operator', 26: 'type' };
	const items = (result || []).filter(symbol => symbol && symbol.location && symbol.location.range).map(symbol => {
		const path = pathOf(symbol.location.uri), start = symbol.location.range.start;
		return {
			title: `${symbol.name} — ${relative(path, root)}:${start.line + 1}${kinds[symbol.kind] ? `  (${kinds[symbol.kind]})` : ''}`,
			value: `${start.line + 1}:${start.character + 1}\t${path}`,
		};
	});
	return items.length ? plist(items) : '';
}

function completions(result) {
	const items = (result && result.items ? result.items : result || []).filter(item => item && typeof item.label === 'string');
	items.sort((a, b) => (a.sortText || a.label) < (b.sortText || b.label) ? -1 : (a.sortText || a.label) > (b.sortText || b.label) ? 1 : 0);

	const suggestions = items.map(item => {
		const name = (item.filterText || item.label).split(/[( ]/)[0];
		let text = item.textEdit ? item.textEdit.newText : (item.insertText || item.label);
		if (item.insertTextFormat !== 2)
			text = text.replace(/[$`\\]/g, '\\$&'); // Plain text, inserted as a snippet
		const suggestion = { display: item.label, match: name };
		if (text.startsWith(name) && text.length > name.length)
			suggestion.insert = text.slice(name.length);
		return suggestion;
	});

	return suggestions.length ? plist(suggestions) : '';
}

// Markdown (as servers send it) as simple HTML: code blocks, inline code,
// emphasis, and paragraphs. Long documentation ends after a few paragraphs.
function hover(result) {
	if (!result || !result.contents)
		return '';

	const parts = [].concat(result.contents).map(part => typeof part === 'string' ? part : part.language ? '```\n' + part.value + '\n```' : part.value);
	const escape = text => text.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
	const inline = text => escape(text)
		.replace(/`([^`]+)`/g, '<code>$1</code>')
		.replace(/\*\*([^*]+)\*\*/g, '<b>$1</b>')
		.replace(/(^|[^\w*])[*_]([^*_]+)[*_](?![\w*])/g, '$1<i>$2</i>');

	const paragraph = text => {
		if (text.split('\n').every(line => /^(    |\t)/.test(line)))
			return `<pre>${escape(text.replace(/^(    |\t)/gm, ''))}</pre>`;
		const heading = text.match(/^#{1,6}\s+(.*)$/);
		return heading ? `<p><b>${inline(heading[1])}</b></p>` : `<p>${inline(text.trim())}</p>`;
	};

	const blocks = parts.join('\n\n').split(/(```[^\n]*\n[\s\S]*?\n```)/);
	const html = [];
	let length = 0;
	for (const block of blocks) {
		const code = block.match(/^```[^\n]*\n([\s\S]*?)\n```$/);
		const pieces = code ? [`<pre>${escape(code[1])}</pre>`] : block.split(/\n\s*\n/).filter(p => p.trim()).map(paragraph);
		for (const piece of pieces) {
			if (length > 1200) {
				html.push('<p class="more">…</p>');
				return page(html);
			}
			html.push(piece);
			length += piece.length;
		}
	}
	return page(html);
}

function page(html) {
	return '<style>body { font: 12px -apple-system, sans-serif; max-width: 42em; } p { margin: .4em 0; } ' +
		'pre, code { font: 11px ui-monospace, Menlo, monospace; } pre { margin: .4em 0; white-space: pre-wrap; } .more { color: gray; }</style>' +
		html.join('');
}

function applied(result) {
	if (result && result.applied === false)
		throw new Error(result.failureReason || 'The edit was not applied.');
	return '';
}
