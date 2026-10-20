'use strict';

// Converts Markdown (CommonMark + common GFM extensions) to HTML, and an edited
// DOM back to Markdown.
const Markdown = (() => {

  // ---------------------------------------------------------------------------
  // Markdown → HTML
  // ---------------------------------------------------------------------------

  const FENCE = /^ {0,3}(`{3,}|~{3,})(.*)$/;
  const ATX = /^ {0,3}(#{1,6})(?:[ \t]+(.*?))?(?:[ \t]+#+)?[ \t]*$/;
  const HR = /^ {0,3}([-*_])(?:[ \t]*\1){2,}[ \t]*$/;
  const QUOTE = /^ {0,3}>/;
  const LIST_ITEM = /^( {0,3})([-*+]|\d{1,9}[.)])(?:([ \t]+)(.*))?$/;
  const SETEXT = /^ {0,3}(=+|-+)[ \t]*$/;
  const TABLE_SEP = /^ {0,3}\|?[ \t]*:?-+:?[ \t]*(?:\|[ \t]*:?-+:?[ \t]*)*\|?[ \t]*$/;
  const REF_DEF = /^ {0,3}\[([^\]]+)\]:[ \t]*<?([^\s>]+)>?(?:[ \t]+(?:"([^"]*)"|'([^']*)'|\(([^)]*)\)))?[ \t]*$/;
  const HTML_BLOCK_TAGS = new Set((
    'address article aside blockquote body center details dialog dd div dl dt fieldset figcaption ' +
    'figure footer form h1 h2 h3 h4 h5 h6 header hr html legend li main menu nav ol p pre section ' +
    'summary table tbody td tfoot th thead tr ul'
  ).split(' '));

  let refs = new Map();

  const isBlank = line => /^[ \t]*$/.test(line);
  const refKey = label => label.trim().replace(/\s+/g, ' ').toLowerCase();
  const escapeText = s => s.replace(/&(?!#?\w+;)/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
  const escapeCode = s => s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
  const escapeAttr = s => escapeCode(s).replace(/"/g, '&quot;');

  function toHTML(markdown) {
    const lines = markdown.replace(/\r\n?/g, '\n').split('\n')
      .map(line => line.replace(/^[ \t]+/, ws => ws.replace(/\t/g, '    ')));

    // Collect reference definitions ([id]: url "title"), skipping fenced code.
    refs = new Map();
    const body = [];
    const lineMap = []; // body index → source line number, for scroll alignment
    let fence = null;
    lines.forEach((line, number) => {
      const f = line.match(FENCE);
      const d = !fence && !f && line.match(REF_DEF);
      if (fence) {
        if (f && f[1][0] === fence[0] && f[1].length >= fence.length && isBlank(f[2])) fence = null;
      } else if (f) {
        fence = f[1];
      } else if (d) {
        const key = refKey(d[1]);
        if (!refs.has(key)) refs.set(key, { url: d[2], title: d[3] ?? d[4] ?? d[5] });
        return;
      }
      body.push(line);
      lineMap.push(number);
    });
    return parseBlocks(body, false, lineMap);
  }

  function isHtmlBlockStart(line, allowStandalone) {
    if (/^ {0,3}<!--/.test(line)) return true;
    const m = line.match(/^ {0,3}<\/?([a-zA-Z][a-zA-Z0-9-]*)(?=[\s/>]|$)/);
    if (!m) return false;
    if (HTML_BLOCK_TAGS.has(m[1].toLowerCase())) return true;
    return allowStandalone && /^ {0,3}<\/?[a-zA-Z][a-zA-Z0-9-]*(?:\s[^<>]*)?\/?>[ \t]*$/.test(line);
  }

  function interruptsParagraph(line) {
    if (FENCE.test(line) || ATX.test(line) || HR.test(line) || QUOTE.test(line)) return true;
    const m = line.match(LIST_ITEM);
    if (m && m[4] && m[4].trim() && (!/\d/.test(m[2]) || parseInt(m[2], 10) === 1)) return true;
    return isHtmlBlockStart(line, false);
  }

  // lineMap (top level only) maps line indexes to source lines; each block then gets a data-line attribute.
  function parseBlocks(lines, tight, lineMap) {
    let html = '';
    let i = 0;
    let pending = null;
    const annotate = () => {
      if (pending && html.length > pending.mark) {
        html = html.slice(0, pending.mark) + html.slice(pending.mark).replace(/^<([a-z0-9]+)/i, `<$1 data-line="${pending.line}"`);
      }
      pending = null;
    };
    while (i < lines.length) {
      const line = lines[i];
      let m;

      if (isBlank(line)) { i++; continue; }
      annotate();
      if (lineMap) pending = { mark: html.length, line: lineMap[i] };

      // Fenced code
      if ((m = line.match(FENCE)) && !(m[1][0] === '`' && m[2].includes('`'))) {
        const fence = m[1];
        const lang = m[2].trim().split(/\s+/)[0];
        const indent = line.match(/^ */)[0].length;
        const strip = new RegExp(`^ {0,${indent}}`);
        const code = [];
        i++;
        while (i < lines.length) {
          const c = lines[i].match(FENCE);
          if (c && c[1][0] === fence[0] && c[1].length >= fence.length && isBlank(c[2])) { i++; break; }
          code.push(lines[i].replace(strip, ''));
          i++;
        }
        const langAttr = lang ? ` data-lang="${escapeAttr(lang)}"` : '';
        html += `<pre${langAttr}><code>${escapeCode(code.join('\n'))}</code></pre>`;
        continue;
      }

      // ATX heading
      if ((m = line.match(ATX))) {
        const level = m[1].length;
        html += `<h${level}>${inline(m[2] || '')}</h${level}>`;
        i++;
        continue;
      }

      // Thematic break
      if (HR.test(line)) { html += '<hr>'; i++; continue; }

      // Blockquote
      if (QUOTE.test(line)) {
        const quoted = [];
        const quotedLines = [];
        while (i < lines.length && !isBlank(lines[i])) {
          if (QUOTE.test(lines[i])) quoted.push(lines[i].replace(/^ {0,3}> ?/, ''));
          else if (interruptsParagraph(lines[i])) break;
          else quoted.push(lines[i]);
          quotedLines.push(lineMap?.[i]);
          i++;
        }
        html += `<blockquote>${parseBlocks(quoted, false, lineMap && quotedLines)}</blockquote>`;
        continue;
      }

      // List
      if (LIST_ITEM.test(line)) {
        const list = parseList(lines, i, lineMap);
        html += list.html;
        i = list.next;
        continue;
      }

      // Table
      if (line.includes('|') && i + 1 < lines.length && TABLE_SEP.test(lines[i + 1])) {
        const header = splitRow(line);
        const rowAttr = k => (lineMap ? ` data-line="${lineMap[k]}"` : '');
        const headerLine = rowAttr(i);
        const aligns = splitRow(lines[i + 1]).map(c => {
          const left = c.startsWith(':');
          const right = c.endsWith(':');
          return left && right ? 'center' : right ? 'right' : left ? 'left' : '';
        });
        i += 2;
        const rows = [];
        const rowLines = [];
        while (i < lines.length && !isBlank(lines[i]) && lines[i].includes('|')) {
          rowLines.push(rowAttr(i));
          rows.push(splitRow(lines[i++]));
        }
        const cell = (tag, text, k) =>
          `<${tag}${aligns[k] ? ` style="text-align: ${aligns[k]}"` : ''}>${inline(text ?? '')}</${tag}>`;
        html += `<table><thead><tr${headerLine}>` + header.map((c, k) => cell('th', c, k)).join('') + '</tr></thead>';
        if (rows.length) {
          html += '<tbody>' + rows.map((r, n) => `<tr${rowLines[n]}>` + header.map((_, k) => cell('td', r[k], k)).join('') + '</tr>').join('') + '</tbody>';
        }
        html += '</table>';
        continue;
      }

      // Indented code
      if (/^ {4}/.test(line)) {
        const code = [];
        while (i < lines.length && (/^ {4}/.test(lines[i]) || isBlank(lines[i]))) code.push(lines[i++].slice(4));
        while (code.length && isBlank(code[code.length - 1])) code.pop();
        html += `<pre><code>${escapeCode(code.join('\n'))}</code></pre>`;
        continue;
      }

      // Raw HTML block: shown rendered but kept verbatim (edit it in the source view).
      if (isHtmlBlockStart(line, true)) {
        const raw = [];
        while (i < lines.length && !isBlank(lines[i])) raw.push(lines[i++]);
        const source = raw.join('\n');
        html += `<div class="md-raw" contenteditable="false" data-raw="${escapeAttr(source)}">${sanitize(source)}</div>`;
        continue;
      }

      // Paragraph (possibly a setext heading)
      const para = [line.trimStart()];
      let heading = 0;
      i++;
      while (i < lines.length && !isBlank(lines[i])) {
        const s = lines[i].match(SETEXT);
        if (s) { heading = s[1][0] === '=' ? 1 : 2; i++; break; }
        if (interruptsParagraph(lines[i])) break;
        para.push(lines[i++].trimStart());
      }
      const content = inline(para.join('\n').trimEnd());
      if (heading) html += `<h${heading}>${content}</h${heading}>`;
      else html += tight ? content : `<p>${content}</p>`;
    }
    annotate();
    return html;
  }

  function parseList(lines, i, lineMap) {
    const first = lines[i].match(LIST_ITEM);
    const ordered = /\d/.test(first[2]);
    const start = ordered ? parseInt(first[2], 10) : 1;
    // Bullet character (- * +) or ordered delimiter (. )); a change starts a new list.
    const markerOf = m => (/\d/.test(m[2]) ? m[2].slice(-1) : m[2]);
    const marker = markerOf(first);
    const items = [];
    let loose = false;

    while (i < lines.length) {
      const m = lines[i].match(LIST_ITEM);
      if (!m || HR.test(lines[i]) || /\d/.test(m[2]) !== ordered || markerOf(m) !== marker) break;
      const baseIndent = m[1].length;
      const spacing = m[3] ? Math.min(m[3].length, 4) : 1;
      const contentIndent = baseIndent + m[2].length + spacing;
      const content = [];
      const contentLines = []; // source line of each content line
      const take = text => { content.push(text); contentLines.push(lineMap?.[i]); i++; };
      take(m[4] || '');
      let blankSeen = false;

      while (i < lines.length) {
        const l = lines[i];
        if (isBlank(l)) { take(''); blankSeen = true; continue; }
        const indent = l.match(/^ */)[0].length;
        if (indent >= contentIndent) { take(l.slice(contentIndent)); blankSeen = false; continue; }
        // Be lenient with nested lists indented less than the content column (e.g. "1. a\n  - b").
        if (indent >= baseIndent + 2 && LIST_ITEM.test(l)) { take(l.slice(indent)); blankSeen = false; continue; }
        if (blankSeen || LIST_ITEM.test(l) || interruptsParagraph(l)) break;
        take(l.trim()); // lazy continuation
      }

      let trailingBlank = false;
      while (content.length > 1 && isBlank(content[content.length - 1])) {
        content.pop();
        contentLines.pop();
        trailingBlank = true;
      }
      if (content.some((l, k) => isBlank(l) && k + 1 < content.length && /^\S/.test(content[k + 1]))) loose = true;
      const next = i < lines.length ? lines[i].match(LIST_ITEM) : null;
      if (trailingBlank && next && !HR.test(lines[i]) && /\d/.test(next[2]) === ordered && markerOf(next) === marker) loose = true;
      items.push({ content, contentLines });
    }

    const tag = ordered ? 'ol' : 'ul';
    let html = `<${tag} data-marker="${marker}"${ordered && start !== 1 ? ` start="${start}"` : ''}>`;
    items.forEach(({ content, contentLines }) => {
      const task = content[0].match(/^\[([ xX])\](?:[ \t]+|$)/);
      let checkbox = '';
      if (task) {
        checkbox = `<input type="checkbox" contenteditable="false"${task[1] === ' ' ? '' : ' checked'}>`;
        content[0] = content[0].slice(task[0].length);
      }
      const line = lineMap ? ` data-line="${contentLines[0]}"` : '';
      html += `<li${task ? ' class="task"' : ''}${line}>${checkbox}${parseBlocks(content, !loose, lineMap && contentLines)}</li>`;
    });
    return { html: html + `</${tag}>`, next: i };
  }

  function splitRow(line) {
    let s = line.trim();
    if (s.startsWith('|')) s = s.slice(1);
    if (s.endsWith('|') && !s.endsWith('\\|')) s = s.slice(0, -1);
    return s.split(/(?<!\\)\|/).map(c => c.trim().replace(/\\\|/g, '|'));
  }

  function sanitize(html) {
    const template = document.createElement('template');
    template.innerHTML = html;
    template.content.querySelectorAll('script, iframe, object, embed, style, link, meta, base, form').forEach(el => el.remove());
    template.content.querySelectorAll('*').forEach(el => {
      for (const attr of [...el.attributes]) {
        if (/^on/i.test(attr.name) || /^\s*javascript:/i.test(attr.value)) el.removeAttribute(attr.name);
      }
    });
    const holder = document.createElement('div');
    holder.append(template.content);
    return holder.innerHTML;
  }

  const LINK_URL = String.raw`(&lt;[^\n]*?&gt;|[^\s()]*(?:\([^\s()]*\)[^\s()]*)*)`;
  const LINK_TITLE = String.raw`(?:\s+(?:"([^"]*)"|'([^']*)'))?`;
  const IMAGE_RE = new RegExp(String.raw`!\[([^\]]*)\]\(\s*` + LINK_URL + LINK_TITLE + String.raw`\s*\)`, 'g');
  const LINK_RE = new RegExp(String.raw`\[((?:[^\[\]]|\[[^\[\]]*\])*)\]\(\s*` + LINK_URL + LINK_TITLE + String.raw`\s*\)`, 'g');
  const REF_LINK_RE = /(!?)\[((?:[^\[\]]|\[[^\[\]]*\])*)\](?:\[([^\]]*)\])?/g;

  function inline(text) {
    const stash = [];
    const keep = html => `\u0001${stash.push(html) - 1}\u0002`;
    const restore = s => {
      while (/\u0001\d+\u0002/.test(s)) s = s.replace(/\u0001(\d+)\u0002/g, (_, n) => stash[n]);
      return s;
    };
    const plainAttr = s => restore(s).replace(/<[^>]*>/g, '').replace(/"/g, '&quot;');
    const hrefAttr = url => url.replace(/^&lt;([\s\S]*)&gt;$/, '$1').replace(/"/g, '&quot;');
    const titleAttr = (a, b) => {
      const title = a ?? b;
      return title ? ` title="${title.replace(/"/g, '&quot;')}"` : '';
    };

    let s = text.replace(/(?: {2,}|\\)\n/g, () => keep('<br>'));

    // Backslash escapes and code spans, scanned left to right so each wins where it starts first.
    s = s.replace(/\\([!-\/:-@\[-`{-~])|(`+)([\s\S]*?[^`])\2(?!`)/g, (_, escaped, ticks, code) => {
      if (escaped !== undefined) return keep(escapeCode(escaped));
      code = code.replace(/\n/g, ' ');
      if (/^ [\s\S]* $/.test(code) && code.trim()) code = code.slice(1, -1);
      return keep(`<code>${escapeCode(code)}</code>`);
    });

    s = s.replace(/<((?:https?|ftp|mailto):[^\s<>]+)>/gi, (_, url) =>
      keep(`<a href="${escapeAttr(url)}">${escapeCode(url)}</a>`));
    s = s.replace(/<br\s*\/?>/gi, () => keep('<br>'));
    s = escapeText(s);

    s = s.replace(IMAGE_RE, (_, alt, url, t1, t2) =>
      keep(`<img src="${hrefAttr(url)}" alt="${plainAttr(alt)}"${titleAttr(t1, t2)}>`));
    s = s.replace(LINK_RE, (_, label, url, t1, t2) =>
      keep(`<a href="${hrefAttr(url)}"${titleAttr(t1, t2)}>${emphasis(label)}</a>`));
    s = s.replace(REF_LINK_RE, (match, bang, label, ref) => {
      const def = refs.get(refKey(ref || label));
      if (!def) return match;
      const title = def.title ? ` title="${escapeAttr(def.title)}"` : '';
      return keep(bang
        ? `<img src="${escapeAttr(def.url)}" alt="${plainAttr(label)}"${title}>`
        : `<a href="${escapeAttr(def.url)}"${title}>${emphasis(label)}</a>`);
    });

    // Bare URLs (GFM autolinks)
    s = s.replace(/(^|[\s(])((?:https?:\/\/|www\.)[^\s<\u0001]*[^\s<\u0001.,:;"')\]*_~])/g, (_, pre, url) =>
      pre + keep(`<a href="${url.startsWith('www.') ? 'http://' : ''}${url.replace(/"/g, '&quot;')}">${url}</a>`));

    return restore(emphasis(s));
  }

  function emphasis(s) {
    return s
      .replace(/(\*\*\*|___)(?=\S)([\s\S]*?\S)\1/g, '<strong><em>$2</em></strong>')
      .replace(/\*\*(?=\S)([\s\S]*?\S)\*\*/g, '<strong>$1</strong>')
      .replace(/(^|[^A-Za-z0-9])__(?=\S)([\s\S]*?\S)__(?![A-Za-z0-9])/g, '$1<strong>$2</strong>')
      .replace(/\*(?=\S)([\s\S]*?\S)\*/g, '<em>$1</em>')
      .replace(/(^|[^A-Za-z0-9])_(?=\S)([\s\S]*?\S)_(?![A-Za-z0-9])/g, '$1<em>$2</em>')
      .replace(/~~(?=\S)([\s\S]*?\S)~~/g, '<del>$1</del>');
  }

  // ---------------------------------------------------------------------------
  // DOM → Markdown
  // ---------------------------------------------------------------------------

  const BLOCK_ELEMENTS = new Set([
    'ADDRESS', 'ARTICLE', 'ASIDE', 'BLOCKQUOTE', 'DD', 'DETAILS', 'DIV', 'DL', 'DT', 'FIELDSET',
    'FIGCAPTION', 'FIGURE', 'FOOTER', 'FORM', 'H1', 'H2', 'H3', 'H4', 'H5', 'H6', 'HEADER', 'HR',
    'LI', 'MAIN', 'NAV', 'OL', 'P', 'PRE', 'SECTION', 'SUMMARY', 'TABLE', 'UL',
  ]);
  const DELIMITERS = { strong: '**', em: '*', del: '~~' };

  const isElement = node => node.nodeType === Node.ELEMENT_NODE;
  const isMonospace = fontFamily => /mono|menlo|courier|consolas/i.test(fontFamily || '');
  const isInlineCode = node => isElement(node) && inlineKind(node) === 'code';
  const isBlockNode = node => isElement(node) && BLOCK_ELEMENTS.has(node.tagName);

  function fromDOM(root) {
    const markdown = blocks(root).join('\n\n');
    return markdown ? markdown + '\n' : '';
  }

  function blocks(container) {
    const out = [];
    let run = [];
    const flush = () => {
      if (!run.length) return;
      const text = escapeLineStarts(cleanInline(inlineNodes(run)));
      if (text) out.push(text);
      run = [];
    };
    for (const node of container.childNodes) {
      if (isBlockNode(node)) {
        flush();
        const md = block(node);
        if (md) out.push(md);
      } else {
        run.push(node);
      }
    }
    flush();
    return out;
  }

  function block(el) {
    if (el.classList.contains('md-raw')) return el.getAttribute('data-raw') ?? el.innerHTML;
    switch (el.tagName) {
      case 'H1': case 'H2': case 'H3': case 'H4': case 'H5': case 'H6': {
        const text = cleanInline(inlineNodes(el.childNodes)).replace(/\\\n|\n/g, ' ');
        return text ? '#'.repeat(Number(el.tagName[1])) + ' ' + text : '';
      }
      case 'HR': return '---';
      case 'PRE': return codeBlock(el);
      case 'UL': case 'OL': return list(el);
      case 'LI': return listItems([listItemParts(el)], false, () => '- ');
      case 'TABLE': return table(el);
      case 'BLOCKQUOTE': {
        const inner = blocks(el).join('\n\n');
        return inner ? inner.split('\n').map(line => (line ? '> ' + line : '>')).join('\n') : '';
      }
      default: return blocks(el).join('\n\n');
    }
  }

  function codeBlock(el) {
    const code = el.querySelector('code');
    const lang = el.getAttribute('data-lang') || ((code?.className || '').match(/(?:lang|language)-(\S+)/) || [])[1] || '';
    const text = (el.isConnected ? el.innerText : el.textContent).replace(/\u00a0/g, ' ').replace(/\n+$/, '');
    const longest = Math.max(2, ...(text.match(/`{3,}/g) || []).map(t => t.length));
    const fence = '`'.repeat(longest + 1);
    return text ? `${fence}${lang}\n${text}\n${fence}` : `${fence}${lang}\n${fence}`;
  }

  function list(el) {
    const ordered = el.tagName === 'OL';
    const startAttr = parseInt(el.getAttribute('start'), 10);
    let number = Number.isNaN(startAttr) ? 1 : startAttr;
    const items = [];
    for (const child of el.childNodes) {
      if (isElement(child) && child.tagName === 'LI') {
        items.push(listItemParts(child));
      } else if (isElement(child) && (child.tagName === 'UL' || child.tagName === 'OL')) {
        // WebKit nests lists directly inside lists when indenting; attach to the previous item.
        const nested = list(child);
        if (!nested) continue;
        if (items.length) items[items.length - 1].blocks.push(nested);
        else items.push({ task: '', blocks: [nested] });
      } else if (child.textContent.trim()) {
        items.push({ task: '', blocks: blocks({ childNodes: [child] }) });
      }
    }
    const loose = [...el.children].some(li => li.tagName === 'LI' && [...li.children].some(c => c.tagName === 'P'));
    const marker = el.getAttribute('data-marker');
    const bullet = ['-', '*', '+'].includes(marker) ? marker : '-';
    const delimiter = marker === ')' ? ')' : '.';
    return listItems(items, loose, () => (ordered ? `${number++}${delimiter} ` : `${bullet} `));
  }

  function listItemParts(li) {
    const box = li.querySelector('input[type=checkbox]');
    const task = box && box.closest('li') === li ? (box.checked ? '[x] ' : '[ ] ') : '';
    return { task, blocks: blocks(li) };
  }

  function listItems(items, loose, nextMarker) {
    return items.map(item => {
      const marker = nextMarker();
      const text = item.task + item.blocks.join(loose ? '\n\n' : '\n');
      if (!text.trim()) return marker.trimEnd();
      const pad = ' '.repeat(marker.length);
      return text.split('\n').map((line, k) => (k === 0 ? marker + line : line ? pad + line : '')).join('\n');
    }).join(loose ? '\n\n' : '\n');
  }

  function table(el) {
    const rows = [...el.rows];
    if (!rows.length) return '';
    const cells = rows.map(row => [...row.cells].map(cell =>
      cleanInline(inlineNodes(cell.childNodes)).replace(/\\\n/g, '<br>').replace(/\n/g, ' ').replace(/\|/g, '\\|')));
    const width = Math.max(...cells.map(r => r.length));
    const aligns = [...rows[0].cells].map(c => c.style.textAlign || c.getAttribute('align') || '');
    const columns = fn => Array.from({ length: width }, (_, k) => fn(k)).join(' | ');
    const row = r => '| ' + columns(k => r[k] ?? '') + ' |';
    const separator = '| ' + columns(k => ({ left: ':---', center: ':---:', right: '---:' }[aligns[k]] || '---')) + ' |';
    return [row(cells[0]), separator, ...cells.slice(1).map(row)].join('\n');
  }

  function inlineKind(node) {
    if (!isElement(node)) return null;
    const style = node.style;
    switch (node.tagName) {
      case 'STRONG': case 'B':
        return /^(normal|[1-5]00)$/.test(style.fontWeight) ? null : 'strong';
      case 'EM': case 'I':
        return style.fontStyle === 'normal' ? null : 'em';
      case 'DEL': case 'S': case 'STRIKE':
        return 'del';
      case 'CODE': case 'KBD': case 'SAMP': case 'TT':
        return 'code';
      case 'SPAN':
        // Editing commands sometimes turn <code> etc. into styled spans.
        if (isMonospace(style.fontFamily)) return 'code';
        if (style.fontWeight === 'bold' || parseInt(style.fontWeight, 10) >= 600) return 'strong';
        if (style.fontStyle === 'italic') return 'em';
        if (/line-through/.test(style.textDecoration || style.textDecorationLine || '')) return 'del';
        return null;
    }
    return null;
  }

  function inlineNodes(nodes, active = new Set()) {
    const list = [...nodes];
    let out = '';
    for (let k = 0; k < list.length; k++) {
      const kind = inlineKind(list[k]);
      if (!kind) { out += inlineNode(list[k], active); continue; }
      // Merge adjacent runs of the same formatting so <b>a</b><b>b</b> becomes **ab**.
      const run = [list[k]];
      while (k + 1 < list.length && inlineKind(list[k + 1]) === kind) run.push(list[++k]);
      if (kind === 'code') {
        out += codeSpan(run.map(n => n.textContent).join(''));
      } else if (active.has(kind)) {
        out += run.map(n => inlineNodes(n.childNodes, active)).join('');
      } else {
        const inner = new Set(active).add(kind);
        out += wrap(DELIMITERS[kind], run.map(n => inlineNodes(n.childNodes, inner)).join(''));
      }
    }
    return out;
  }

  function inlineNode(node, active) {
    if (node.nodeType === Node.TEXT_NODE) {
      return escapeMarkdown(node.nodeValue.replace(/\u00a0/g, ' ').replace(/[ \t\r\f]+/g, ' '));
    }
    if (!isElement(node)) return '';
    switch (node.tagName) {
      case 'BR': return '\\\n';
      case 'INPUT': case 'SCRIPT': case 'STYLE': case 'TEMPLATE': return '';
      case 'IMG': {
        const alt = escapeMarkdown(node.getAttribute('alt') || '');
        return `![${alt}](${encodeURL(node.getAttribute('src') || '')}${titlePart(node)})`;
      }
      case 'A': {
        const href = node.getAttribute('href');
        const text = inlineNodes(node.childNodes, active);
        if (!href) return text;
        if (node.textContent === href && /^https?:\/\/[^\s<>]*[^\s<>.,:;"')\]*_~]$/.test(href)) return href;
        return `[${text}](${encodeURL(href)}${titlePart(node)})`;
      }
      default:
        return inlineNodes(node.childNodes, active);
    }
  }

  function wrap(delimiter, inner) {
    const m = inner.match(/^(\s*)([\s\S]*?)(\s*)$/);
    return m[2] ? m[1] + delimiter + m[2] + delimiter + m[3] : inner;
  }

  function codeSpan(text) {
    text = text.replace(/\u00a0/g, ' ').replace(/\n/g, ' ');
    if (!text) return '';
    const longest = Math.max(0, ...(text.match(/`+/g) || []).map(t => t.length));
    const ticks = '`'.repeat(longest + 1);
    const pad = /^`|`$/.test(text) || /^ [\s\S]* $/.test(text) ? ' ' : '';
    return ticks + pad + text + pad + ticks;
  }

  function encodeURL(url) {
    url = url.replace(/ /g, '%20');
    const balanced = url.split('(').length === url.split(')').length;
    return balanced ? url : url.replace(/\(/g, '%28').replace(/\)/g, '%29');
  }

  function titlePart(el) {
    const title = el.getAttribute('title');
    return title ? ` "${title.replace(/"/g, '&quot;')}"` : '';
  }

  function escapeMarkdown(s) {
    s = s.replace(/[\\`]/g, '\\$&').replace(/~~/g, '\\~\\~');
    s = s.replace(/\*/g, (m, k, str) => (str[k - 1] === ' ' && str[k + 1] === ' ' ? '*' : '\\*'));
    s = s.replace(/_/g, (m, k, str) =>
      (/[A-Za-z0-9]/.test(str[k - 1] || '') && /[A-Za-z0-9]/.test(str[k + 1] || '') ? '_' : '\\_'));
    if (/\[[^\]]*\]|\]\(/.test(s)) s = s.replace(/[\[\]]/g, '\\$&');
    return s.replace(/<(?=[A-Za-z\/!?])/g, '\\<').replace(/&(?=#?\w+;)/g, '\\&');
  }

  function cleanInline(s) {
    return s
      .replace(/ {2,}/g, ' ')
      .replace(/ +\n/g, '\n')
      .replace(/\n +/g, '\n')
      .replace(/\n{2,}/g, '\n')
      .replace(/^(?:\s|\\\n)+|(?:\s|\\\n)+$/g, '');
  }

  // Escapes characters at the start of a line that would otherwise begin a block.
  function escapeLineStarts(text) {
    return text.split('\n').map(line => line
      .replace(/^(#{1,6})(?=[ \t]|$)/, '\\$1')
      .replace(/^>/, '\\>')
      .replace(/^([-+])(?=[ \t]|$)/, '\\$1')
      .replace(/^(-+|=+)[ \t]*$/, '\\$1')
      .replace(/^(\d+)([.)])(?=[ \t]|$)/, '$1\\$2')
    ).join('\n');
  }

  return { toHTML, fromDOM, isInlineCode };
})();
