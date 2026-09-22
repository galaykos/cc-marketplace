# Artifact patterns

Five page shapes that earn a page. Each names what it is FOR, the markup the shell
already styles, and the one thing that makes it fail. Combine at most two.

## 1. Walkthrough — a change with reasoning in the margin

For: a reviewer reading a diff who needs the WHY beside the WHAT.

```html
<h1>PR #412 — retry budget on the outbound client</h1>
<p class="pill warn">2 findings · 1 blocking</p>
<div class="diff">
<span class="del">- client.retry(3)</span>
<span class="add">+ client.retry(budget.remaining())</span>
<div class="note">Blocking — a fixed count ignores the shared budget; under load every caller retries three times at once.</div>
</div>
```

Fails when: the annotations restate the diff instead of judging it, or the diff is
pasted whole when only twelve lines matter. Lead with the finding list; anchors from
each finding into the diff.

## 2. Compare — options side by side

For: layouts, copy variants, API shapes, implementation plans — anything the reader
must hold in view at once.

```html
<div class="grid">
  <section class="card" id="opt-a"><h2>A · Dense table</h2>…<p><strong>Trade-off:</strong> scans fast, hides state.</p></section>
  <section class="card" id="opt-b"><h2>B · Cards</h2>…<p><strong>Trade-off:</strong> shows state, three screens tall.</p></section>
</div>
```

Fails when: the options differ only in colour, or the trade-off line is missing on
any card. Two to four options; each with one honest trade-off sentence.

## 3. Dashboard — data the session already pulled

For: deploy failures by service, test flake by file, open PRs by age.

- Numbers come from a command that ran in this session; name the command in a
  `<p class="pill">` under the title with its time.
- Charts as inline SVG (bars, sparklines) or HTML `<meter>`; a `<table>` under every
  chart carries the same numbers for screen readers and for anyone who distrusts a bar.
- If the host `dataviz` skill is present, read it before choosing chart form and colour.

Fails when: a bar has no table, a number has no source, or a "live" label sits on a
snapshot. This plugin's pages do not refresh from anywhere; say "as of <time>".

## 4. Checklist — work in progress the reader follows

For: a migration plan, a release runbook, a long task someone else is waiting on.

```html
<ol id="steps">
  <li><input type="checkbox" checked disabled id="s1"><label for="s1">Backfill column — done 14:02</label></li>
  <li><input type="checkbox" disabled id="s2"><label for="s2">Swap reads — <em>skipped: feature flag already routes reads</em></label></li>
</ol>
```

Re-bundle as steps complete; the page reloads itself. The version ledger is the
history. Fails when: a skipped step is deleted instead of marked skipped with why.

## 5. Bring-back — a decision returned as text

For: ordering, triage, a pick among options, tuning values — anything the reader
decides on the page and pastes back into the session.

```html
<textarea id="out" readonly aria-label="Prompt to paste back" rows="4"></textarea>
<button class="copy" type="button" onclick="navigator.clipboard.writeText(document.getElementById('out').value)">Copy as prompt</button>
```

Generate `#out` from the page state on every change: natural language, non-default
choices only, enough context to act on without the page. Fails when: the output is a
JSON dump, or the controls have no keyboard path.

## Keep out of every pattern

- Animations on entry; hover effects on every card; gradients as decoration.
- A header repeating the title; a footer repeating the session.
- Any `<script src>` or `<link href>` pointing off the machine that the reply did
  not name as a network dependency.
