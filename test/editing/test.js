// Tests for indentation, folding, and the symbol list: they are computed from the
// Preferences the way TextMate does (Frameworks/regexp/src/indent.cc,
// Frameworks/layout/src/folds.cc, Frameworks/buffer/src/symbols.cc), with TextMate's
// scope selector ranking (Frameworks/scope/src/match.cc), for the files in this directory.
//
//   node test/editing/test.js            check indentation and compare with the snapshots
//   node test/editing/test.js --update   rewrite the .folds and .symbols snapshots

const fs = require('fs'), path = require('path');
const vsctm = require('vscode-textmate');
const onig = require('vscode-oniguruma');

const root = path.resolve(__dirname, '../..');
const grammarFiles = {
  'source.elixir': 'Syntaxes/Elixir.tmLanguage',
  'text.elixir': 'Syntaxes/EEx.tmLanguage',
  'text.html.elixir': 'Syntaxes/HTML (EEx).tmLanguage',
  'text.html.heex': 'Syntaxes/HEEx.tmLanguage',
  'text.html.basic': 'test/vendor/html-tmbundle/Syntaxes/HTML.plist',
};
const scopeForExtension = { '.ex': 'source.elixir', '.exs': 'source.elixir', '.heex': 'text.html.heex' };

// === Scope selectors ===

function parseSelector(src) {
  let i = 0;
  const ws = () => { while (/\s/.test(src[i])) i++; };
  const path = () => {
    const scopes = [];
    for (;;) {
      ws();
      const m = /^[\w.*+-]+/.exec(src.slice(i));
      if (!m || m[0] === '-') break;
      scopes.push(m[0]); i += m[0].length;
    }
    return scopes.length ? { path: scopes } : null;
  };
  const expression = () => {
    ws();
    const filter = /^([LRB]):/.exec(src.slice(i));
    if (filter) { i += 2; ws(); }
    let res;
    if (src[i] === '(') { i++; const group = selector(); ws(); i++; res = { group }; }
    else res = path();
    return filter ? { filter: filter[1], sel: res } : res;
  };
  const composite = () => {
    const exprs = [{ op: null, sel: expression() }];
    for (;;) {
      ws();
      const op = src[i];
      if (op !== '|' && op !== '&' && op !== '-') break;
      i++;
      exprs.push({ op, sel: expression() });
    }
    return exprs;
  };
  const selector = () => {
    const composites = [composite()];
    for (ws(); src[i] === ','; ws()) { i++; composites.push(composite()); }
    return composites;
  };
  return selector();
}

const prefixMatch = (sel, scope) => scope === sel || scope.startsWith(sel + '.');

// Returns the rank TextMate gives the selector in a context, or null. Scopes are arrays,
// outermost first. Paths match the right scope; L: and R: pick a side, B: needs both.
function rank(selector, left, right = left) {
  const matchPath = (scopes, scope) => {
    let s = scopes.length - 1, score = 0, power = 0;
    for (let n = scope.length - 1; n >= 0 && s >= 0; n--) {
      power += scope[n].split('.').length;
      if (prefixMatch(scopes[s], scope[n])) {
        for (let len = scopes[s].split('.').length; len-- > 0;)
          score += 1 / Math.pow(2, power - len);
        s--;
      }
    }
    return s < 0 ? score : null;
  };
  const matchExpr = (e, lhs, rhs) => {
    if (e.filter === 'L') return matchExpr(e.sel, lhs, lhs);
    if (e.filter === 'R') return matchExpr(e.sel, rhs, rhs);
    if (e.filter === 'B') {
      const a = matchExpr(e.sel, lhs, lhs), b = matchExpr(e.sel, rhs, rhs);
      return a !== null && b !== null ? Math.max(a, b) : null;
    }
    return e.path ? matchPath(e.path, rhs) : matchSel(e.group, lhs, rhs);
  };
  const matchSel = (sel, lhs, rhs) => {
    let best = null;
    for (const composite of sel) {
      let res = false, sum = 0;
      for (const { op, sel: e } of composite) {
        const r = matchExpr(e, lhs, rhs);
        const local = r !== null;
        if (local) sum = Math.max(sum, r);
        res = op === null ? local : op === '|' ? res || local : op === '&' ? res && local : res && !local;
      }
      if (res) best = Math.max(best ?? 0, sum);
    }
    return best;
  };
  return matchSel(selector, left, right);
}

// === Preferences ===

function loadPreferences() {
  const prefs = [];
  for (const dir of ['Preferences', 'test/vendor/html-tmbundle/Preferences']) {
    for (const f of fs.readdirSync(path.join(root, dir)).filter(f => f.endsWith('.tmPreferences'))) {
      const file = path.join(root, dir, f);
      const plist = vsctm.parseRawGrammar(fs.readFileSync(file, 'utf8'), file);
      if (plist.scope && plist.settings) prefs.push({ selector: parseSelector(plist.scope), settings: plist.settings });
    }
  }
  return prefs;
}

// TextMate's value_for_setting: the value from the highest ranked matching selector.
function valueForSetting(prefs, key, left, right = left) {
  let best = null, bestRank = -1;
  for (const p of prefs) {
    if (!(key in p.settings)) continue;
    const r = rank(p.selector, left, right);
    if (r !== null && r > bestRank) { best = p.settings[key]; bestRank = r; }
  }
  return best;
}

// === Tokenizing ===

async function setup() {
  await onig.loadWASM(fs.readFileSync(require.resolve('vscode-oniguruma/release/onig.wasm')).buffer);
  const registry = new vsctm.Registry({
    onigLib: Promise.resolve({ createOnigScanner: p => new onig.OnigScanner(p), createOnigString: s => new onig.OnigString(s) }),
    loadGrammar: async s => grammarFiles[s] ? vsctm.parseRawGrammar(fs.readFileSync(path.join(root, grammarFiles[s]), 'utf8'), grammarFiles[s]) : null,
  });
  return registry;
}

function tokenize(grammar, text) {
  let state = vsctm.INITIAL;
  return text.split('\n').map(line => {
    const r = grammar.tokenizeLine(line, state);
    state = r.ruleStack;
    const chars = [];
    for (const t of r.tokens) for (let i = t.startIndex; i < t.endIndex; i++) chars[i] = t.scopes;
    return { text: line, bol: r.tokens[0].scopes, eol: r.tokens[r.tokens.length - 1].scopes, chars };
  });
}

// Oniguruma regexes, like TextMate's.
const regexCache = new Map();
function search(pattern, str, from = 0) {
  if (!regexCache.has(pattern)) regexCache.set(pattern, new onig.OnigScanner([pattern]));
  const m = regexCache.get(pattern).findNextMatchSync(new onig.OnigString(str), from);
  return m && m.captureIndices;
}

// === Indentation (indent::fsm_t) ===

const [INCREASE, DECREASE, NEXT, IGNORE, ZERO] = [1, 2, 4, 8, 16];
const PATTERNS = { increaseIndentPattern: INCREASE, decreaseIndentPattern: DECREASE, indentNextLinePattern: NEXT,
                   unIndentedLinePattern: IGNORE, zeroIndentPattern: ZERO };
const leadingWhitespace = line => /^[ \t]*/.exec(line)[0].length;
const isBlank = line => line.trim() === '';

function classify(line, patterns) {
  let res = 0;
  for (const [type, pattern] of patterns) if (search(pattern, line)) res |= type;
  if (res & IGNORE) return IGNORE;
  if (res & ZERO) return ZERO;
  if (res & INCREASE) res &= ~NEXT;
  return res;
}

class IndentFSM {
  constructor(size) { Object.assign(this, { size, level: 0, carry: 0, seen: 0, lastType: 0, lastIndent: 0 }); }
  isSeeded(line, patterns) {
    const type = classify(line, patterns);
    if (isBlank(line) || type & (IGNORE | ZERO)) return false;
    if (++this.seen === 1) {
      this.level = leadingWhitespace(line); this.carry = 0; this.lastType = type; this.lastIndent = this.level;
      if (type & INCREASE) this.level += this.size;
      if (type & NEXT) this.carry += this.size;
      return false;
    }
    if (type & NEXT && !(this.lastType & (INCREASE | DECREASE))) {
      this.level = leadingWhitespace(line);
      if (this.lastType & NEXT && this.level < this.lastIndent) this.carry += this.lastIndent - this.level;
      this.lastIndent = this.level;
      return false;
    }
    return true;
  }
  scanLine(line, patterns) {
    const type = classify(line, patterns);
    let res = this.level + this.carry;
    if (type & ZERO) {
      res = 0;
    } else if (!(type & IGNORE)) {
      if (type & (INCREASE | DECREASE)) this.carry = 0;
      if (type & DECREASE && (!(type & INCREASE) || this.level > 0)) this.level -= this.size;
      res = this.level + this.carry;
      if (type & INCREASE) this.level += this.size;
      this.carry = type & NEXT ? this.carry + this.size : 0;
    }
    return Math.max(res, 0);
  }
}

// Indentation patterns: the context is (end of line, beginning of line), so selectors
// match the scope at the beginning of the line (indent::patterns_for_line).
function indentPatterns(prefs, line) {
  return Object.entries(PATTERNS).map(([key, type]) => [type, valueForSetting(prefs, key, line.eol, line.bol)]).filter(([, p]) => p);
}

// The indentation TextMate gives each line when it is typed after the lines above it
// (create_fsm and scan_line, as for a new line and the corrections while typing). Lines
// starting in a string or doc are free-form and not checked.
function checkIndentation(prefs, lines, file) {
  const failures = [];
  const patterns = lines.map(l => indentPatterns(prefs, l));
  lines.forEach((line, n) => {
    if (isBlank(line.text) || line.bol.some(s => /^(string|comment)\./.test(s))) return;
    const fsm = new IndentFSM(2);
    for (let m = n; m-- > 0 && !fsm.isSeeded(lines[m].text, patterns[m]);) {}
    const want = fsm.scanLine(line.text, patterns[n]), have = leadingWhitespace(line.text);
    if (want !== have) failures.push(`${file}:${n + 1}: indented ${want} instead of ${have}: ${line.text.trim()}`);
  });
  return failures;
}

// === Folding (folds_t::foldable_ranges) ===

function foldableRanges(prefs, lines) {
  const info = lines.map(line => {
    // Folding patterns: the context is (beginning of line, end of line), so selectors
    // match the scope at the end of the line and L: the beginning (setup_patterns).
    const get = key => valueForSetting(prefs, key, line.bol, line.eol);
    const [start, stop, indent, ignore] = ['foldingStartMarker', 'foldingStopMarker', 'foldingIndentedBlockStart', 'foldingIndentedBlockIgnore'].map(get);
    const has = p => !!(p && search(p, line.text));
    const res = { start: has(start), stop: has(stop), indentStart: has(indent), ignore: has(ignore),
                  empty: isBlank(line.text), indent: leadingWhitespace(line.text) };
    if (res.start || res.stop) res.indentStart = false;
    return res;
  });
  const res = [], regular = [], indented = [];
  let empties = 0;
  info.forEach((i, n) => {
    while (indented.length && !i.empty && !i.ignore && i.indent <= indented[indented.length - 1][1]) {
      const [start] = indented.pop();
      if (start < n - 1) res.push([start, n - 1 - empties]);
    }
    empties = i.empty && !i.indentStart ? empties + 1 : 0;
    if (i.start) regular.push([n, i.indent]);
    else if (i.indentStart) indented.push([n, i.indent]);
    else if (i.stop) {
      const k = regular.map(([, ind]) => ind).lastIndexOf(i.indent);
      if (k >= 0) { res.push([regular[k][0], n]); regular.length = k; }
    }
  });
  for (const [start] of indented.reverse()) res.push([start, lines.length - 1]);
  foldableRanges.markers = info.map((i, n) => i.start || i.indentStart ? n : -1).filter(n => n >= 0);
  res.sort((a, b) => a[0] - b[0] || a[1] - b[1]);
  const unique = [], stack = [];
  for (const [a, b] of res) {
    while (stack.length && stack[stack.length - 1][1] <= a) stack.pop();
    if (stack.length && stack[stack.length - 1][1] < b) continue;
    stack.push([a, b]); unique.push([a, b]);
  }
  return unique;
}

// === Symbol list (symbols_t::did_parse) ===

// A symbolTransformation: `s/regexp/format/options;` items applied in turn.
function transform(src, text) {
  let res = text.replace(/\n/g, ' ');
  for (const [, re, format, options] of (src || '').matchAll(/s\/((?:\\.|[^\\/])*)\/((?:\\.|[^\\/])*)\/([a-z]*);?/g)) {
    let from = 0, out = '';
    for (;;) {
      const m = search(re, res, from);
      if (!m) break;
      const captures = m.map(c => res.slice(c.start, c.end));
      out += res.slice(from, m[0].start) + format.replace(/\$(\d)/g, (_, d) => captures[+d] || '').replace(/\\(.)/g, '$1');
      from = m[0].end;
      if (!options.includes('g') || from >= res.length) break;
      if (m[0].end === m[0].start) out += res[from++]; // step over an empty match
    }
    res = out + res.slice(from);
  }
  return res;
}

function symbols(prefs, lines) {
  const res = [];
  let current = null;
  const flush = () => { if (current) res.push(`${current.line + 1}: ${transform(current.transform, current.text)}`); current = null; };
  lines.forEach((line, n) => {
    for (let i = 0; i <= line.text.length; i++) {
      const scope = i < line.text.length ? line.chars[i] : null;
      const shown = scope && valueForSetting(prefs, 'showInSymbolList', scope);
      if (shown) {
        if (!current) current = { line: n, text: '' };
        current.text += line.text[i];
        current.transform = valueForSetting(prefs, 'symbolTransformation', scope);
      } else {
        flush(); // a symbol's region ends before the end of its line
      }
    }
  });
  flush();
  return res;
}

// === Main ===

module.exports = { parseSelector, rank, setup, loadPreferences, tokenize, valueForSetting, foldableRanges, checkIndentation };

if (require.main === module) (async () => {
  const registry = await setup();
  const prefs = loadPreferences();
  const update = process.argv.includes('--update');
  let failures = [];
  for (const file of fs.readdirSync(__dirname).filter(f => scopeForExtension[path.extname(f)]).sort()) {
    const grammar = await registry.loadGrammar(scopeForExtension[path.extname(file)]);
    const lines = tokenize(grammar, fs.readFileSync(path.join(__dirname, file), 'utf8'));
    const indentation = checkIndentation(prefs, lines, file);
    failures = failures.concat(indentation);
    const folds = foldableRanges(prefs, lines);
    const idle = foldableRanges.markers.filter(n => !folds.some(([a, b]) => a === n && b > a));
    const snapshots = {
      folds: folds.filter(([a, b]) => b > a).map(([a, b]) => `${a + 1}-${b + 1}: ${lines[a].text.trim()}`)
        .concat(idle.map(n => `${n + 1}: marker without a fold: ${lines[n].text.trim()}`)),
      symbols: symbols(prefs, lines),
    };
    for (const [kind, actual] of Object.entries(snapshots)) {
      const snapshot = path.join(__dirname, `${file}.${kind}`);
      const text = actual.join('\n') + '\n';
      if (update) fs.writeFileSync(snapshot, text);
      else if (!fs.existsSync(snapshot) || fs.readFileSync(snapshot, 'utf8') !== text) failures.push(`${file}: ${kind} differ from ${path.basename(snapshot)} (run with --update to see)`);
    }
    console.log(`${indentation.length ? '✖' : '✓'} ${file}: ${lines.length} lines, ${snapshots.folds.length} folds, ${snapshots.symbols.length} symbols`);
  }
  failures.forEach(f => console.log('  ' + f));
  process.exit(failures.length ? 1 : 0);
})();
