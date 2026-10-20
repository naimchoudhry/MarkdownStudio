'use strict';

const editor = document.getElementById('editor');
const INLINE_FORMATTING = new Set(['STRONG', 'B', 'EM', 'I', 'DEL', 'S', 'STRIKE', 'CODE', 'A', 'SPAN']);
let syncTimer = null;
let isEditable = true;
let savedRange = null;
let lastState = '';

document.execCommand('defaultParagraphSeparator', false, 'p');

// Called from Swift whenever the Markdown source changes.
window.setMarkdown = markdown => {
  clearTimeout(syncTimer);
  syncTimer = null;
  const scrollY = isEditable ? window.scrollY : 0;
  editor.innerHTML = Markdown.toHTML(markdown) || '<p><br></p>';
  editor.dataset.lines = String(markdown.split('\n').length);
  if (!isEditable) editor.querySelectorAll('input').forEach(input => { input.disabled = true; });
  ignoreScrollUntil = performance.now() + 150;
  window.scrollTo(0, scrollY);
  applyFolding();
  refreshFind();
};

// Called from Swift to show read-only content (e.g. the guide).
window.setEditable = editable => {
  isEditable = editable;
  editor.contentEditable = editable ? 'true' : 'false';
};

function postMarkdown() {
  syncTimer = null;
  const markdown = Markdown.fromDOM(editor);
  refreshLineNumbers(markdown);
  window.webkit?.messageHandlers?.markdown?.postMessage(markdown);
}

// After edits here, re-derive each block's source line so scroll alignment stays accurate.
function refreshLineNumbers(markdown) {
  const fresh = document.createElement('div');
  fresh.innerHTML = Markdown.toHTML(markdown);
  editor.dataset.lines = String(markdown.split('\n').length);
  const copy = (from, to) => {
    if (from.length !== to.length) return;
    to.forEach((el, k) => el.setAttribute('data-line', from[k].getAttribute('data-line')));
  };
  copy([...fresh.children], [...editor.children]);
  copy([...fresh.querySelectorAll('li[data-line]')], [...editor.querySelectorAll('li')]);
  copy([...fresh.querySelectorAll('tr[data-line]')], [...editor.querySelectorAll('tr')]);
  const nested = el => [...el.querySelectorAll('li > *, blockquote > *')].filter(n => !['UL', 'OL', 'INPUT', 'BR'].includes(n.tagName) || n.hasAttribute('data-line'));
  copy(nested(fresh), nested(editor));
}

function scheduleSync() {
  clearTimeout(syncTimer);
  syncTimer = setTimeout(postMarkdown, 120);
}

function closestInEditor(node, selector) {
  const el = node?.nodeType === Node.ELEMENT_NODE ? node : node?.parentElement;
  const match = el?.closest(selector);
  return match && editor.contains(match) ? match : null;
}

function selectionAnchor() {
  return window.getSelection()?.anchorNode ?? null;
}

const escapeHTML = s => s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');

editor.addEventListener('input', () => {
  applyFolding();
  scheduleSync();
  scheduleFindRefresh();
});
editor.addEventListener('change', scheduleSync); // task-list checkboxes

// ⌘-click opens a link while editing (a plain click just places the caret).
editor.addEventListener('click', event => {
  const link = closestInEditor(event.target, 'a[href]');
  if (!link || !isEditable || !event.metaKey) return;
  event.preventDefault();
  window.webkit?.messageHandlers?.openLink?.postMessage(link.href);
});

// ---------------------------------------------------------------------------
// Formatting state, reported to Swift so the toolbar and Format menu reflect the selection
// ---------------------------------------------------------------------------

function inlineCodeAt(node) {
  if (closestInEditor(node, 'pre')) return null;
  for (let el = node?.nodeType === Node.ELEMENT_NODE ? node : node?.parentElement; el && el !== editor; el = el.parentElement) {
    if (Markdown.isInlineCode(el)) return editor.contains(el) ? el : null;
  }
  return null;
}

function postState() {
  const anchor = selectionAnchor();
  const inEditor = !!anchor && editor.contains(anchor);
  const find = selector => (inEditor ? closestInEditor(anchor, selector) : null);
  const heading = find('h1, h2, h3, h4, h5, h6');
  const block = find('h1, h2, h3, h4, h5, h6, pre');
  const list = find('ul, ol');
  const query = command => inEditor && document.queryCommandState(command);
  const state = {
    focused: isEditable && document.activeElement === editor && document.hasFocus(),
    bold: heading ? !!find('strong, b') : query('bold'),
    italic: query('italic'),
    strikethrough: !!find('del, s, strike') || query('strikeThrough'),
    code: inEditor && !!inlineCodeAt(anchor),
    block: block ? block.tagName.toLowerCase() : 'p',
    quote: !!find('blockquote'),
    list: list ? (list.tagName === 'OL' ? 'ordered' : 'bullet') : '',
    marker: list ? list.getAttribute('data-marker') || (list.tagName === 'OL' ? '.' : '-') : '',
    task: !!find('li')?.classList.contains('task'),
    link: find('a')?.getAttribute('href') ?? null,
    outline: outlineLevel,
  };
  const json = JSON.stringify(state);
  if (json === lastState) return;
  lastState = json;
  window.webkit?.messageHandlers?.state?.postMessage(json);
}

document.addEventListener('selectionchange', () => {
  const selection = window.getSelection();
  if (selection?.rangeCount && editor.contains(selection.getRangeAt(0).commonAncestorContainer)) {
    savedRange = selection.getRangeAt(0).cloneRange();
  }
  postState();
});
editor.addEventListener('focus', postState);
editor.addEventListener('blur', postState);
window.addEventListener('focus', postState);
window.addEventListener('blur', postState);

// ---------------------------------------------------------------------------
// Formatting commands, called from the Swift toolbar and Format menu
// ---------------------------------------------------------------------------

// Toolbar clicks may move focus away; put the caret back where the user left it.
function restoreSelection() {
  if (document.activeElement === editor) return;
  editor.focus();
  if (savedRange && editor.contains(savedRange.commonAncestorContainer)) {
    const selection = window.getSelection();
    selection.removeAllRanges();
    selection.addRange(savedRange);
  }
}

function toggleInlineCode() {
  const selection = window.getSelection();
  const code = inlineCodeAt(selection.anchorNode);
  if (code) {
    const range = document.createRange();
    range.selectNode(code);
    selection.removeAllRanges();
    selection.addRange(range);
    document.execCommand('insertHTML', false, escapeHTML(code.textContent));
  } else if (selection.isCollapsed) {
    document.execCommand('insertHTML', false, '<code>code</code>');
  } else {
    document.execCommand('insertHTML', false, `<code>${escapeHTML(selection.toString())}</code>`);
  }
}

function setBlock(tag) {
  const anchor = selectionAnchor();
  const current = closestInEditor(anchor, 'h1, h2, h3, h4, h5, h6, pre');
  const target = current && current.tagName.toLowerCase() === tag ? 'p' : tag;
  document.execCommand('formatBlock', false, `<${target}>`);
}

function toggleQuote() {
  const anchor = selectionAnchor();
  const quote = closestInEditor(anchor, 'blockquote');
  const list = closestInEditor(anchor, 'ul, ol');
  if (quote && (!list || quote.contains(list))) {
    if (list) quote.replaceWith(...quote.childNodes);
    else document.execCommand('outdent');
  } else if (list) {
    // formatBlock would quote a single list item; quote the whole list instead.
    let outer = list;
    for (let parent; (parent = closestInEditor(outer.parentElement, 'ul, ol')); ) outer = parent;
    const blockquote = document.createElement('blockquote');
    outer.replaceWith(blockquote);
    blockquote.append(outer);
  } else {
    document.execCommand('formatBlock', false, '<blockquote>');
  }
}

function setTasks(list, enabled) {
  for (const li of list.children) {
    if (li.tagName !== 'LI') continue;
    const box = li.querySelector(':scope > input[type=checkbox]');
    if (enabled && !box) {
      const input = document.createElement('input');
      input.type = 'checkbox';
      input.contentEditable = 'false';
      li.prepend(input);
      li.classList.add('task');
    } else if (!enabled && box) {
      box.remove();
      li.classList.remove('task');
    }
  }
}

// style: '-', '*', '+' (bullet styles), 'ordered', 'task' (toggles a checklist) or 'none'.
function setList(style) {
  const currentList = () => closestInEditor(selectionAnchor(), 'ul, ol');
  let list = currentList();
  if (style === 'none') {
    if (list) document.execCommand(list.tagName === 'OL' ? 'insertOrderedList' : 'insertUnorderedList');
    return;
  }
  const isTaskList = list?.querySelector(':scope > li.task');
  if (style === 'task' && isTaskList) {
    setTasks(list, false);
    return;
  }
  const ordered = style === 'ordered';
  if (!list || (list.tagName === 'OL') !== ordered) {
    document.execCommand(ordered ? 'insertOrderedList' : 'insertUnorderedList');
    list = currentList();
  }
  if (!list) return;
  if (style === 'task') setTasks(list, true);
  else if (!ordered) list.setAttribute('data-marker', style);
}

function setLink(url) {
  const selection = window.getSelection();
  const existing = closestInEditor(selection.anchorNode, 'a');
  if (existing && selection.isCollapsed) {
    const range = document.createRange();
    range.selectNodeContents(existing);
    selection.removeAllRanges();
    selection.addRange(range);
  }
  if (!url) {
    document.execCommand('unlink');
  } else if (selection.isCollapsed) {
    document.execCommand('insertHTML', false, `<a href="${escapeHTML(url)}">${escapeHTML(url)}</a>`);
  } else {
    document.execCommand('createLink', false, url);
  }
}

// Inserts a horizontal rule after the block containing the caret, rather than splitting that block
// (e.g. a title) at the caret, then puts the caret in the block after the rule.
function insertRuleAfterBlock() {
  let block = selectionAnchor();
  block = block?.nodeType === Node.ELEMENT_NODE ? block : block?.parentElement;
  while (block && block.parentElement !== editor) block = block.parentElement;
  if (!block || block === editor) {
    document.execCommand('insertHorizontalRule');
    return;
  }
  const rule = document.createElement('hr');
  block.after(rule);
  let next = rule.nextElementSibling;
  if (!next || next.tagName === 'HR' || next.classList.contains('md-raw')) {
    next = document.createElement('p');
    next.append(document.createElement('br'));
    rule.after(next);
  }
  window.getSelection().collapse(next, 0);
  applyFolding();
}

const COMMANDS = {
  bold: () => document.execCommand('bold'),
  italic: () => document.execCommand('italic'),
  strikethrough: () => document.execCommand('strikeThrough'),
  code: toggleInlineCode,
  block: setBlock,
  quote: toggleQuote,
  list: setList,
  link: setLink,
  rule: insertRuleAfterBlock,
  clear: () => {
    document.execCommand('removeFormat');
    document.execCommand('formatBlock', false, '<p>');
  },
};

window.editorCommand = (name, value) => {
  if (name === 'outline') { // view-only: no focus, selection or Markdown changes
    setOutline(value);
    return;
  }
  if (!isEditable || !COMMANDS[name]) return;
  restoreSelection();
  COMMANDS[name](value);
  scheduleSync();
  postState();
};

editor.addEventListener('keydown', event => {
  if (event.metaKey && !event.shiftKey && !event.altKey && !event.ctrlKey) {
    // Normally handled by the Format menu; kept as a fallback.
    const command = { b: 'bold', i: 'italic' }[event.key.toLowerCase()];
    if (command) {
      event.preventDefault();
      window.editorCommand(command);
      return;
    }
  }
  const anchor = selectionAnchor();
  if (event.key === 'Enter' && !event.metaKey && closestInEditor(anchor, 'pre')) {
    event.preventDefault();
    document.execCommand('insertText', false, '\n');
  } else if (event.key === 'Tab' && !event.metaKey) {
    if (closestInEditor(anchor, 'li')) {
      event.preventDefault();
      document.execCommand(event.shiftKey ? 'outdent' : 'indent');
    } else if (closestInEditor(anchor, 'pre')) {
      event.preventDefault();
      document.execCommand('insertText', false, '    ');
    }
  }
});

// Copy/cut: put Markdown on the clipboard as plain text, alongside rich HTML.
function selectionFragment() {
  const selection = window.getSelection();
  if (!selection || !selection.rangeCount || selection.isCollapsed) return null;
  const range = selection.getRangeAt(0);
  if (!editor.contains(range.commonAncestorContainer)) return null;

  let node = range.cloneContents();
  let formatted = [...node.childNodes].some(n => n.nodeType === Node.ELEMENT_NODE);
  // Re-wrap the fragment in its ancestors so partially selected bold text, list items,
  // code blocks etc. keep their meaning.
  for (let a = range.commonAncestorContainer; a && a !== editor; a = a.parentNode) {
    if (a.nodeType !== Node.ELEMENT_NODE) continue;
    if (INLINE_FORMATTING.has(a.tagName) || a.tagName === 'PRE') formatted = true;
    const wrapper = a.cloneNode(false);
    wrapper.append(node);
    node = wrapper;
  }

  const holder = document.createElement('div');
  holder.className = 'offscreen';
  holder.append(node);
  document.body.append(holder);
  try {
    return {
      html: holder.innerHTML,
      text: formatted ? Markdown.fromDOM(holder).replace(/\n$/, '') : selection.toString(),
    };
  } finally {
    holder.remove();
  }
}

function writeClipboard(event) {
  const fragment = selectionFragment();
  if (!fragment) return false;
  event.clipboardData.setData('text/plain', fragment.text);
  event.clipboardData.setData('text/html', fragment.html);
  event.preventDefault();
  return true;
}

editor.addEventListener('copy', writeClipboard);
editor.addEventListener('cut', event => {
  if (writeClipboard(event)) document.execCommand('delete');
});

// Paste: rich HTML is inserted as-is; plain text is interpreted as Markdown.
editor.addEventListener('paste', event => {
  const data = event.clipboardData;
  if (!data) return;
  const text = data.getData('text/plain');
  if (closestInEditor(selectionAnchor(), 'pre')) {
    event.preventDefault();
    document.execCommand('insertText', false, text);
    return;
  }
  if (data.types.includes('text/html') || !text) return;
  event.preventDefault();
  const html = Markdown.toHTML(text);
  const single = html.match(/^<p>([\s\S]*)<\/p>$/);
  if (single && !single[1].includes('<p>')) {
    // Inline paste: keep surrounding spaces, which Markdown parsing trims.
    const nbsp = s => s.replace(/[ \t]/g, ' ');
    const lead = nbsp(text.match(/^[ \t]*/)[0]);
    const trail = nbsp(text.match(/[ \t]*$/)[0]);
    document.execCommand('insertHTML', false, lead + single[1] + trail);
  } else {
    document.execCommand('insertHTML', false, html);
  }
});

editor.innerHTML = '<p><br></p>';

// ---------------------------------------------------------------------------
// Find & replace in the rendered text, called from Swift
// ---------------------------------------------------------------------------

const BLOCK_BREAKS = new Set(['P', 'DIV', 'LI', 'H1', 'H2', 'H3', 'H4', 'H5', 'H6', 'PRE', 'BLOCKQUOTE',
  'TD', 'TH', 'TR', 'TABLE', 'UL', 'OL', 'HR', 'BR', 'DT', 'DD', 'FIGCAPTION', 'SUMMARY']);
const WORD_CHAR = '[\\p{L}\\p{N}_]';
let findState = null; // { search, regex, matches: [{ range, groups }], current }
let findRefreshTimer = null;

function buildRegExp(search) {
  let pattern = search.isRegex ? search.query : search.query.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  if (search.mode === 'startsWith' || search.mode === 'wholeWord') pattern = `(?<!${WORD_CHAR})(?:${pattern})`;
  if (search.mode === 'endsWith' || search.mode === 'wholeWord') pattern = `(?:${pattern})(?!${WORD_CHAR})`;
  return new RegExp(pattern, 'gu' + (search.matchCase ? '' : 'i'));
}

// The editor's text as one string (blocks separated by newlines), with a map back to text nodes.
function textIndex() {
  const segments = [];
  let text = '';
  const walker = document.createTreeWalker(editor, NodeFilter.SHOW_TEXT | NodeFilter.SHOW_ELEMENT);
  for (let node = walker.nextNode(); node; node = walker.nextNode()) {
    if (node.nodeType === Node.ELEMENT_NODE) {
      if (BLOCK_BREAKS.has(node.tagName) && text && !text.endsWith('\n')) text += '\n';
      continue;
    }
    segments.push({ node, start: text.length });
    text += node.nodeValue;
  }
  return { text, segments };
}

function positionAt(segments, offset, isEnd) {
  let low = 0;
  let high = segments.length - 1;
  while (low < high) {
    const mid = (low + high + 1) >> 1;
    const start = segments[mid].start;
    if (start < offset || (!isEnd && start === offset)) low = mid; else high = mid - 1;
  }
  const segment = segments[low];
  return [segment.node, Math.min(offset - segment.start, segment.node.nodeValue.length)];
}

function runFind(search, preferredIndex) {
  const regex = buildRegExp(search);
  const { text, segments } = textIndex();
  const matches = [];
  for (const match of text.matchAll(regex)) {
    if (!match[0].length) continue;
    const range = document.createRange();
    range.setStart(...positionAt(segments, match.index, false));
    range.setEnd(...positionAt(segments, match.index + match[0].length, true));
    matches.push({ range, groups: [...match] });
  }
  let current = -1;
  if (matches.length) {
    if (preferredIndex != null && preferredIndex >= 0) {
      current = Math.min(preferredIndex, matches.length - 1);
    } else {
      // Start from the first match at or after the caret.
      const caret = savedRange;
      current = caret ? matches.findIndex(m => m.range.compareBoundaryPoints(Range.START_TO_START, caret) >= 0) : 0;
      if (current < 0) current = 0;
    }
  }
  findState = { search, regex, matches, current };
  highlightFind();
}

function highlightFind() {
  if (!window.CSS?.highlights) return;
  CSS.highlights.delete('find');
  CSS.highlights.delete('find-current');
  if (!findState?.matches.length) return;
  CSS.highlights.set('find', new Highlight(...findState.matches.map(m => m.range)));
  const current = findState.matches[findState.current];
  if (current) CSS.highlights.set('find-current', new Highlight(current.range));
}

function revealCurrentMatch() {
  const match = findState?.matches[findState.current];
  if (!match) return;
  revealBlock(match.range.startContainer);
  const rect = match.range.getBoundingClientRect();
  if (rect.top < 40 || rect.bottom > window.innerHeight - 40) {
    window.scrollTo({ top: window.scrollY + rect.top - window.innerHeight / 3 });
  }
}

function findResult(extra = {}) {
  return JSON.stringify({ count: findState?.matches.length ?? 0, current: findState?.current ?? -1, ...extra });
}

window.findSearch = search => {
  if (!search || !search.query) {
    findState = null;
    highlightFind();
    return findResult();
  }
  try {
    runFind(search);
  } catch (error) {
    findState = null;
    highlightFind();
    return findResult({ error: error.message });
  }
  revealCurrentMatch();
  return findResult();
};

window.findSelect = index => {
  if (!findState?.matches[index]) return findResult();
  findState.current = index;
  highlightFind();
  revealCurrentMatch();
  return findResult();
};

function expandReplacement(template, groups) {
  if (!findState.search.isRegex) return template;
  return template.replace(/\$(\d+|&|\$)/g, (token, ref) => {
    if (ref === '$') return '$';
    if (ref === '&') return groups[0];
    return groups[Number(ref)] ?? '';
  });
}

function replaceMatch(match, template) {
  const container = match.range.commonAncestorContainer;
  const element = container.nodeType === Node.ELEMENT_NODE ? container : container.parentElement;
  if (element?.closest('.md-raw')) return false; // raw HTML is edited in the source
  const replacement = expandReplacement(template, match.groups);
  match.range.deleteContents();
  if (replacement) match.range.insertNode(document.createTextNode(replacement));
  return true;
}

window.findReplace = (index, template) => {
  const match = findState?.matches[index];
  if (!match || !isEditable) return findResult();
  replaceMatch(match, template);
  editor.normalize();
  postMarkdown();
  runFind(findState.search, index);
  revealCurrentMatch();
  return findResult();
};

window.findReplaceAll = template => {
  if (!findState || !isEditable) return findResult({ replaced: 0 });
  let replaced = 0;
  for (const match of [...findState.matches].reverse()) {
    if (replaceMatch(match, template)) replaced++;
  }
  editor.normalize();
  postMarkdown();
  runFind(findState.search, 0);
  return findResult({ replaced });
};

window.selectedText = () => window.getSelection()?.toString() ?? '';

// Re-run the active search after the content changes, and tell Swift the new counts.
function refreshFind() {
  if (!findState) return;
  try {
    runFind(findState.search, findState.current);
  } catch {
    return;
  }
  window.webkit?.messageHandlers?.find?.postMessage(findResult());
}

function scheduleFindRefresh() {
  if (!findState) return;
  clearTimeout(findRefreshTimer);
  findRefreshTimer = setTimeout(refreshFind, 150);
}

// ---------------------------------------------------------------------------
// Scroll alignment with the source pane, using each block's data-line
// ---------------------------------------------------------------------------

let ignoreScrollUntil = 0;
let scrollFrame = null;

function lineAnchors() {
  const anchors = [{ line: 0, top: 0 }];
  for (const el of editor.querySelectorAll('[data-line]')) {
    const line = Number(el.getAttribute('data-line'));
    const top = el.getBoundingClientRect().top + window.scrollY;
    const last = anchors[anchors.length - 1];
    if (line > last.line && top > last.top) anchors.push({ line, top });
  }
  const totalLines = Number(editor.dataset.lines || 0);
  const bottom = document.documentElement.scrollHeight - window.innerHeight * 0.4; // excludes bottom padding
  const last = anchors[anchors.length - 1];
  if (totalLines > last.line && bottom > last.top) anchors.push({ line: totalLines, top: bottom });
  return anchors;
}

function lineAtOffset(y) {
  const anchors = lineAnchors();
  let k = 0;
  while (k + 1 < anchors.length && anchors[k + 1].top <= y) k++;
  const a = anchors[k];
  const b = anchors[k + 1];
  if (!b) return a.line;
  return a.line + ((y - a.top) / (b.top - a.top)) * (b.line - a.line);
}

function offsetAtLine(line) {
  const anchors = lineAnchors();
  let k = 0;
  while (k + 1 < anchors.length && anchors[k + 1].line <= line) k++;
  const a = anchors[k];
  const b = anchors[k + 1];
  if (!b) return a.top;
  return a.top + ((line - a.line) / (b.line - a.line)) * (b.top - a.top);
}

window.currentLine = () => lineAtOffset(window.scrollY);

window.scrollToLine = line => {
  ignoreScrollUntil = performance.now() + 150;
  window.scrollTo(0, offsetAtLine(line));
};

window.addEventListener('scroll', () => {
  if (performance.now() < ignoreScrollUntil || scrollFrame) return;
  scrollFrame = requestAnimationFrame(() => {
    scrollFrame = null;
    window.webkit?.messageHandlers?.scroll?.postMessage(window.currentLine());
  });
});

// ---------------------------------------------------------------------------
// Collapsible sections. View-only: folding never changes the Markdown.
// A heading's section is everything after it up to the next heading of the same or a higher level.
// ---------------------------------------------------------------------------

const HEADING_TAGS = new Set(['H1', 'H2', 'H3', 'H4', 'H5', 'H6']);
// Fold state per heading: 'expanded', 'collapsed', or 'headings:N' (show only sub-headings up to level N).
const foldByElement = new WeakMap();
let foldByKey = new Map(); // restores fold state after the content is re-rendered from the source
let outlineLevel = 0; // 0 = everything, 1–6 = outline level, -1 = folded by hand

const headingLevel = el => (HEADING_TAGS.has(el.tagName) ? Number(el.tagName[1]) : 0);

function headingKeys() {
  const counts = new Map();
  const keys = new Map();
  for (const el of editor.children) {
    const level = headingLevel(el);
    if (!level) continue;
    const base = `${level}:${el.textContent.trim()}`;
    const n = counts.get(base) ?? 0;
    counts.set(base, n + 1);
    keys.set(el, `${base}:${n}`);
  }
  return keys;
}

function applyFolding() {
  const keys = headingKeys();
  const nextKeys = new Map();
  const stack = []; // enclosing headings: { level, state }
  const insideCollapsed = () => stack.some(h => h.state === 'collapsed');
  for (const el of editor.children) {
    const level = headingLevel(el);
    let hidden;
    if (level) {
      while (stack.length && stack[stack.length - 1].level >= level) stack.pop();
      // Only the parent section's outline limit applies; an opened section shows all its sub-titles.
      const parent = stack[stack.length - 1];
      const limited = parent?.state.startsWith('headings:') && level > Number(parent.state.slice(9));
      hidden = insideCollapsed() || !!limited;
      const state = foldByElement.get(el) ?? foldByKey.get(keys.get(el)) ?? 'expanded';
      foldByElement.set(el, state);
      if (state !== 'expanded') nextKeys.set(keys.get(el), state);
      el.classList.add('md-foldable');
      el.classList.toggle('md-collapsed', state === 'collapsed');
      el.classList.toggle('md-headings-only', state.startsWith('headings:'));
      stack.push({ level, state });
    } else {
      const nearest = stack[stack.length - 1];
      hidden = insideCollapsed() || !!nearest?.state.startsWith('headings:');
    }
    el.classList.toggle('md-hidden', hidden);
  }
  foldByKey = nextKeys;
}

// Keeps the section at the top of the view in place while folding changes the layout.
function preservingTopHeading(change) {
  let anchor = null;
  for (const el of editor.children) {
    if (el.classList.contains('md-hidden')) continue;
    if (headingLevel(el)) anchor = el;
    if (el.getBoundingClientRect().bottom > 0) break;
  }
  change();
  if (anchor && !anchor.classList.contains('md-hidden') && anchor.getBoundingClientRect().top < 0) {
    anchor.scrollIntoView({ block: 'start' });
  }
}

// The headings inside a heading's section (up to the next heading of the same or a higher level).
function subheadings(heading) {
  const level = headingLevel(heading);
  const result = [];
  for (let el = heading.nextElementSibling; el; el = el.nextElementSibling) {
    const elLevel = headingLevel(el);
    if (elLevel && elLevel <= level) break;
    if (elLevel) result.push(el);
  }
  return result;
}

// A fully open section folds; a folded or partly open one (an outline level) opens completely.
function toggleSection(heading) {
  const state = foldByElement.get(heading) ?? 'expanded';
  if (state === 'expanded') {
    foldByElement.set(heading, 'collapsed');
  } else {
    foldByElement.set(heading, 'expanded');
    for (const sub of subheadings(heading)) foldByElement.set(sub, 'expanded');
  }
  outlineLevel = -1;
  applyFolding();
  lastState = '';
  postState();
}

// value: '0' shows everything, '1'–'6' shows headings up to that level, 'collapse' folds every section.
function setOutline(value) {
  const limit = value === 'collapse' ? -1 : Number(value);
  preservingTopHeading(() => {
    for (const el of editor.children) {
      const level = headingLevel(el);
      if (!level) continue;
      let state = 'collapsed';
      if (limit === 0) state = 'expanded';
      else if (limit > 0 && level < limit) state = `headings:${limit}`;
      foldByElement.set(el, state);
    }
    outlineLevel = limit === -1 ? -1 : limit;
    applyFolding();
  });
  lastState = '';
  postState();
}

// Unfolds whatever hides the block containing `node` (used by Find).
function revealBlock(node) {
  let block = node?.nodeType === Node.ELEMENT_NODE ? node : node?.parentElement;
  while (block && block.parentElement !== editor) block = block.parentElement;
  if (!block?.classList.contains('md-hidden')) return;
  let minLevel = headingLevel(block) || 7;
  for (let el = block.previousElementSibling; el; el = el.previousElementSibling) {
    const level = headingLevel(el);
    if (level && level < minLevel) {
      if (foldByElement.get(el) !== 'expanded') foldByElement.set(el, 'expanded');
      minLevel = level;
    }
  }
  outlineLevel = -1;
  applyFolding();
  lastState = '';
  postState();
}

// The fold arrow sits in the margin to the left of each heading (a CSS ::before).
editor.addEventListener('mousedown', event => {
  const heading = event.target.closest?.('h1, h2, h3, h4, h5, h6');
  if (!heading || heading.parentElement !== editor) return;
  if (event.clientX >= heading.getBoundingClientRect().left) return;
  event.preventDefault();
  toggleSection(heading);
});
