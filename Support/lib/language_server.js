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
// An error response is an error, with the server’s message.

ObjC.import('Foundation');

function run(argv) {
	const input = $.NSString.alloc.initWithDataEncoding($.NSFileHandle.fileHandleWithStandardInput.readDataToEndOfFile, $.NSUTF8StringEncoding).js;
	const response = JSON.parse(input);
	if (response.error)
		throw new Error(response.error.message.split('\n')[0]);
	return argv[0] === 'hover' ? hover(response.result) : completions(response.result);
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

	if (suggestions.length === 0)
		return '';
	const data = $.NSPropertyListSerialization.dataWithPropertyListFormatOptionsError($(suggestions), $.NSPropertyListXMLFormat_v1_0, 0, null);
	return $.NSString.alloc.initWithDataEncoding(data, $.NSUTF8StringEncoding).js;
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
