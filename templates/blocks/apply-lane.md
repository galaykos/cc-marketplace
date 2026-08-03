6. When findings exist, offer the next step as a selectable choice (AskUserQuestion):
   Apply all / Apply critical+high only / Report only{{applyExtraBlock}}. On an apply
   pick, dispatch the finding list down the static chain {{workerChain}} — never leave
   the user to retype findings as instructions. In a headless or non-interactive run,
   report only and print the apply command instead of dispatching.

7. **Prime the worker's rubric in that same dispatch.** A worker has no `Skill` tool. It
   can usually FIND a skill (with `Bash`, or `Glob` given an explicit `path`) but cannot
   rank the copies it finds, so the `bestpractices-skill:` line in its agent frontmatter
   names a rubric it cannot reliably open — unqualified, it works from recalled
   convention. Ranking is your job. Resolve the agent file of the chain
   head you ACTUALLY dispatch to, not the first name in the chain: `${CLAUDE_PLUGIN_ROOT}/agents/<name>.md`
   same-plugin, else cross-plugin `"${CLAUDE_PLUGIN_ROOT}"/../<plugin>/agents/<name>.md`
   (checkout) or `"${CLAUDE_PLUGIN_ROOT}"/../../<plugin>/*/agents/<name>.md` at the highest
   version (cache) — naming an agent file without saying where it is would repeat the exact
   bug this step exists to fix, and the cache form is not optional: most chain heads here
   live in another plugin. Read its
   `bestpractices-skill:` line and resolve each comma-separated token to the FIRST hit of
   `${CLAUDE_PLUGIN_ROOT}/skills/<tok>/SKILL.md` →
   sibling plugin in YOUR install, whichever layout you are in — checkout
   `"${CLAUDE_PLUGIN_ROOT}"/../*/skills/<tok>/SKILL.md`, else cache
   `"${CLAUDE_PLUGIN_ROOT}"/../../*/*/skills/<tok>/SKILL.md` taking the highest version
   segment (under a cache install `${CLAUDE_PLUGIN_ROOT}` is `<mp>/<plugin>/<version>`, so
   `..` is the plugin's OTHER VERSIONS, not its siblings — the one-level form silently
   matches nothing there) →
   `find ~/.claude/plugins/marketplaces \( -path '*/skills/<tok>/SKILL.md' -o -path '*/skills/*/<tok>/SKILL.md' \) | grep -v '/[^/]*\.bak/' | grep -v '/marketplaces/[^/]*/\.' | sort | head -1` →
   the same find under `cache`, keyed on the version SEGMENT and never the whole path:
   `awk -F/ '{v="0.0.0"; for(i=NF;i>0;i--) if($i ~ /^[0-9]+(\.[0-9]+)+$/){v=$i; break} print v"\t"$0}' | sort -V | tail -1 | cut -f2-` →
   `plugins/*/skills/<tok>/SKILL.md`, then add one line per hit to the dispatch text:
   `Read <abs-path> before writing; it is the authoritative best-practice source for this
   stack.` A token that resolves nowhere is skipped, never an error — but name it, so a
   missing plugin is visible rather than a rubric that quietly shrank. If the dispatched head declares
   NO `bestpractices-skill:` (`task-runner:task-executor` does not), OR its agent file
   cannot be found or read at all, there is nothing in frontmatter to resolve and a fix
   list is not a task card — inject instead
   the skills THIS review itself loaded to produce the findings, so the applier works to
   the same rubric the findings were judged against. Full
   doctrine, and the discipline preamble that rides the same dispatch:
   `orchestration:delegation-contracts` § Skill priming. Standing: agent-graded — no
   script verifies a dispatch actually carried the paths.

You may close by recommending an ultra-assess re-run when the change was large or
high-risk — recommend it only, never self-execute it.