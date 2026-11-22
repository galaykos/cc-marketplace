#!/bin/bash
# PreToolUse on Bash: denies claude plugin|plugins update|install|i with -y, --yes or --accept-command (or a short cluster holding y), read through quotes, VAR= and wrapper prefixes, a shell's -c string, eval and a heredoc body a shell reads.
# Misses the flag inside a script file, a variable, an alias, a $( ), an MCP shell tool, or a heredoc piped to a shell on a later line. Silent on a heredoc body nothing runs. Fails open: no python3, or any error, prints nothing.
# Why, limits, history: rationale/derivations/plugin-plugin-updater.md § plugins/plugin-updater/hooks/accept-guard.sh
{
  input=$(cat)
  if command -v jq >/dev/null 2>&1; then
    cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // empty' 2>/dev/null) || exit 0
    case "$cmd" in *claude*plugin*) ;; *) exit 0 ;; esac
  fi
  command -v python3 >/dev/null 2>&1 || exit 0
  printf '%s' "$input" | python3 -I -c '
import json, os, re, shlex, sys

SHELLS = {"sh", "bash", "zsh", "dash", "ksh", "mksh", "fish"}
WRAP = {"sudo", "doas", "env", "command", "builtin", "exec", "nohup", "time", "nice", "stdbuf", "timeout", "xargs",
        "npx", "bunx", "pnpm", "yarn", "then", "do", "else", "if", "while", "until", "!", "{"}
FLAG = re.compile(r"^(-y|--yes|--accept-command(=.*)?|-[A-Za-z]*y[A-Za-z]*)$")
OPENER = re.compile(r"(?<!<)<<-?[ \t]*([\"\x27]?)([A-Za-z_][A-Za-z0-9_]*)\1")
READER = re.compile(r"(^|[\s;|&(])((sudo|doas)\s+)?(((ba|z|da|k|mk)?sh|fish|eval|source)(\s|$)|\.\s)")


def strip_bodies(text):
    out, lines, i = [], text.split("\n"), 0
    while i < len(lines):
        line = lines[i]
        out.append(line)
        m = OPENER.search(line)
        i += 1
        if not m or READER.search(line[:m.start()] + " " + line[m.end():]):
            continue
        dash = line[m.start():m.start() + 3] == "<<-"
        while i < len(lines):
            body = lines[i].lstrip("\t") if dash else lines[i]
            i += 1
            if body == m.group(2):
                break
    return "\n".join(out)


def segments(text):
    text = strip_bodies(text).replace("\\\n", "").replace("\n", "\n;")
    lex = shlex.shlex(text, posix=True, punctuation_chars=True)
    lex.whitespace_split = True
    seg, skip = [], False
    for tok in lex:
        if tok and set(tok) <= set(";&|()"):
            yield seg
            seg = []
        elif tok and set(tok) <= set("<>"):
            skip = True
        elif skip:
            skip = False
        else:
            seg.append(tok)
    yield seg


def is_cli(tok):
    return os.path.basename(tok) == "claude" or re.match(r"^@anthropic-ai/claude-code(@.*)?$", tok) is not None


def accepts(seg, depth=0):
    if not seg or depth > 3:
        return False
    first = os.path.basename(seg[0])
    if first in SHELLS:
        for k, tok in enumerate(seg[1:-1], 1):
            if re.match(r"^-[A-Za-z]*c[A-Za-z]*$", tok):
                return guarded(seg[k + 1], depth + 1)
        return False
    if first == "eval":
        return guarded(" ".join(seg[1:]), depth + 1)
    if not (is_cli(seg[0]) or first in WRAP or re.match(r"^[A-Za-z_][A-Za-z0-9_]*=", seg[0])):
        return False
    for i, tok in enumerate(seg):
        if not is_cli(tok):
            continue
        rest = [t for t in seg[i + 1:]]
        words = [t for t in rest if not t.startswith("-")]
        if len(words) < 2 or words[0] not in ("plugin", "plugins") or words[1] not in ("update", "install", "i"):
            return False
        after = rest[rest.index(words[1]) + 1:]
        if "--" in after:
            after = after[:after.index("--")]
        return any(FLAG.match(t) for t in after)
    return False


def guarded(text, depth=0):
    return any(accepts(s, depth) for s in segments(text))


try:
    cmd = json.load(sys.stdin).get("tool_input", {}).get("command") or ""
    if guarded(cmd):
        reason = ("plugin-updater: blocked. -y, --yes and --accept-command accept a marketplace-declared command (a changed "
                  "install command, or the headersHelper that fetches the archive) that a person has not seen. Do not retry it "
                  "in another form. Give the user the same command without the flag to run in their own terminal, where the CLI "
                  "shows the command and asks.")
        print(json.dumps({"hookSpecificOutput": {"hookEventName": "PreToolUse", "permissionDecision": "deny",
                                                 "permissionDecisionReason": reason}}))
except Exception:
    pass
'
} 2>/dev/null
exit 0
