// DEFECT: empty-suite. A test file EXISTS (so a static "has tests?" linter is
// satisfied), but the suite collects ZERO runnable tests — the describe block was
// scaffolded and never filled in. `node --test` reports `tests 0`, which the
// behavioral gate must classify as empty-suite rather than covered.
const { describe } = require('node:test');

describe('add()', () => {
  // TODO: no it() cases written yet — this suite runs nothing.
});
