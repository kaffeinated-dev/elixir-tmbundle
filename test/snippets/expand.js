// Expand the Elixir snippets the way TextMate does when each placeholder keeps its default
// text, and print them as JSON for check.exs:  node test/snippets/expand.js | elixir test/snippets/check.exs
//
// A tab stop without default text alone on a line stands for a body (nil); elsewhere it is
// empty. Tabs become two spaces. The variables are those of a file in a Mix project.

const fs = require('fs'), path = require('path');
const onig = require('vscode-oniguruma');
const vsctm = require('vscode-textmate');

const root = path.resolve(__dirname, '../..');
const VARIABLES = {
  TM_FILEPATH: '/Users/me/my_app/lib/my_app/accounts/user_token.ex',
  TM_FILENAME: 'user_token.ex',
  TM_SELECTED_TEXT: '',
};

// === TextMate format strings: $n, \u \l \U \L \E, (?n:if:else) ===

function format(fmt, captures) {
  let i = 0;
  const parse = (stop) => {
    const parts = [];
    while (i < fmt.length && !stop.includes(fmt[i])) {
      const c = fmt[i];
      if (c === '\\' && i + 1 < fmt.length) {
        const n = fmt[i + 1]; i += 2;
        parts.push('uUlLE'.includes(n) ? { caseChange: n } : n === 'n' ? '\n' : n === 't' ? '\t' : n);
      } else if (c === '$' && /\d/.test(fmt[i + 1] || '')) {
        parts.push({ capture: +fmt[i + 1] }); i += 2;
      } else if (c === '(' && fmt[i + 1] === '?' && /\d/.test(fmt[i + 2] || '')) {
        const n = +fmt[i + 2]; i += 4; // (?n:
        const ifSet = parse(':)');
        let otherwise = [];
        if (fmt[i] === ':') { i++; otherwise = parse(')'); }
        i++; // )
        parts.push({ condition: n, ifSet, otherwise });
      } else {
        parts.push(c); i++;
      }
    }
    return parts;
  };
  const render = (parts) => {
    let out = '', next = null, span = null;
    const push = (text) => {
      for (const ch of text) {
        let c = ch;
        if (span === 'U') c = c.toUpperCase(); else if (span === 'L') c = c.toLowerCase();
        if (next === 'u') { c = c.toUpperCase(); next = null; } else if (next === 'l') { c = c.toLowerCase(); next = null; }
        out += c;
      }
    };
    for (const p of parts) {
      if (typeof p === 'string') push(p);
      else if (p.caseChange) { if ('ul'.includes(p.caseChange)) next = p.caseChange; else span = p.caseChange === 'E' ? null : p.caseChange; }
      else if ('capture' in p) push(captures[p.capture] || '');
      else push(render(captures[p.condition] ? p.ifSet : p.otherwise));
    }
    return out;
  };
  return render(parse(''));
}

function transform(value, regexp, fmt, options) {
  const scanner = new onig.OnigScanner([regexp]);
  let out = '', from = 0;
  for (;;) {
    const m = scanner.findNextMatchSync(new onig.OnigString(value), from);
    if (!m) break;
    const [whole] = m.captureIndices;
    const captures = m.captureIndices.map(c => c.start === 4294967295 || c.start < 0 ? undefined : value.slice(c.start, c.end));
    out += value.slice(from, whole.start) + format(fmt, captures);
    from = whole.end > whole.start ? whole.end : whole.end + 1;
    if (whole.end === whole.start) out += value.slice(whole.end, from);
    if (!options.includes('g') || from > value.length) break;
  }
  return out + value.slice(from);
}

// === Snippet syntax ===

function expand(content) {
  let i = 0;
  const defaults = {};
  const readUntil = (close) => { // raw text up to an unescaped close character
    let s = '';
    while (i < content.length && content[i] !== close) {
      if (content[i] === '\\' && i + 1 < content.length) s += content[i++];
      s += content[i++];
    }
    i++;
    return s;
  };
  const parse = (stop) => { // returns nodes
    const nodes = [];
    while (i < content.length && content[i] !== stop) {
      const c = content[i];
      if (c === '\\' && i + 1 < content.length && '$`\\}'.includes(content[i + 1])) { nodes.push(content[i + 1]); i += 2; continue; }
      if (c === '$') {
        const bare = /^\$(\d+|[A-Z_][A-Z0-9_]*)/.exec(content.slice(i));
        if (bare) { i += bare[0].length; nodes.push(/^\d/.test(bare[1]) ? { tab: +bare[1] } : { variable: bare[1] }); continue; }
        const m = /^\$\{(\d+|[A-Z_][A-Z0-9_]*)([:/}])/.exec(content.slice(i));
        if (m) {
          i += m[0].length;
          const name = m[1], isTab = /^\d/.test(name);
          if (m[2] === '}') { nodes.push(isTab ? { tab: +name } : { variable: name }); continue; }
          if (m[2] === ':') {
            const inner = parse('}'); i++;
            if (isTab) { if (!(name in defaults)) defaults[name] = inner; nodes.push({ tab: +name }); }
            else nodes.push({ variable: name, fallback: inner });
            continue;
          }
          const regexp = readUntil('/'), fmt = readUntil('/'), options = readUntil('}');
          nodes.push(isTab ? { tab: +name, regexp, fmt, options } : { variable: name, regexp, fmt, options });
          continue;
        }
      }
      nodes.push(c); i++;
    }
    return nodes;
  };
  const nodes = parse('');
  const render = (ns) => ns.map(n => {
    if (typeof n === 'string') return n;
    let value;
    if ('tab' in n) value = n.tab in defaults ? render(defaults[n.tab]) : '\u0000';
    else value = VARIABLES[n.variable] || (n.fallback ? render(n.fallback) : '');
    return n.regexp !== undefined ? transform(value, n.regexp, n.fmt, n.options) : value;
  }).join('');
  return render(nodes)
    .split('\n').map(line => line.trim() === '\u0000' && !process.argv.includes('--raw') ? line.replace('\u0000', 'nil') : line.replace('\u0000', '')).join('\n')
    .replace(/\t/g, '  ');
}

// === Main ===

module.exports = { expand, format, transform };
if (require.main === module) {
  onig.loadWASM(fs.readFileSync(require.resolve('vscode-oniguruma/release/onig.wasm')).buffer).then(() => {
    const out = [];
    for (const f of fs.readdirSync(path.join(root, 'Snippets')).sort()) {
      const file = path.join(root, 'Snippets', f);
      const s = vsctm.parseRawGrammar(fs.readFileSync(file, 'utf8'), file);
      if (!/source\.elixir/.test(s.scope || '')) continue;
      out.push({ name: s.name, trigger: s.tabTrigger || s.keyEquivalent, code: expand(s.content) });
    }
    console.log(JSON.stringify(out, null, 1));
  });
}
