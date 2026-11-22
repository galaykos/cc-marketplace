# ui-libraries: derivations for files whose header points here

Standing: `recorded` — no gate reads this file.

## plugins/ui-libraries/hooks/package-command-guard.sh

What made it exist: two skill rules that were broken, or could be broken, at the moment a command
ran, with nothing reading the skill then. The 2026-11-21 thinking-disciplines follow-up review (UI
and web plugins, findings 2 and 3) proposed both; both were on the build list of the 2026-11-21 fix dispatch.

**Astryx (deny).** `npx astryx` resolves the npm package named `astryx`, which is not Astryx's
CLI (`@astryxdesign/cli`, whose bin is also called `astryx`). On 2026-11-21 the registry held
`astryx@0.0.0` with no bin, so a run failed with "could not determine executable to run"; the
review's own accidental run saw that. The exposure is the package gaining a binary later. npx,
bunx and `npm exec` use a local `astryx` bin when the CLI is installed, so the hook denies only
when no `package.json` at or above the working directory declares `@astryxdesign/cli` (the
approved condition). `pnpm dlx` and `yarn dlx` always fetch from the registry, and
`astryx@<version>` names the registry package by spec, so those are denied even with the CLI
declared: the approved condition is a proxy for "this will fetch the unrelated package", and for
those forms the proxy is wrong. A declared CLI that is not yet installed (a fresh clone) still
fetches through npx; the hook does not look at `node_modules`.

**PrimeReact (ask).** On 2026-11-21 npm's `latest` for `primereact` was 11.2.3 and for
`@primeuix/themes` 3.1.1, so a bare install or `@latest` of either moves a v10 project onto the
v11 line, a rewrite under the keyed PrimeUI licence (`skills/primereact-best-practices/SKILL.md`
§ 9). The hook asks only when the nearest lockfile (package-lock.json, npm-shrinkwrap.json,
pnpm-lock.yaml, yarn.lock classic or berry, bun.lock) resolves `primereact` 10.x. Ask, not deny:
migrating is legitimate when asked for. `bun.lockb` is binary and not read.

Limits: hand edits to `package.json`, `npm update`, ncu and Renovate never pass through a Bash
install line; `npx -p`, a `cd` through a variable, and quoting that splits a package name are not
followed. The harness is `plugins/ui-libraries/scripts/__tests__/package-command-guard.test.sh`.
