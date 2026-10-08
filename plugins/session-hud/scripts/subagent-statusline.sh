#!/bin/bash
# subagent-statusline.sh — session-hud's subagentStatusLine: one row per subagent with its type, model, effort, context use and age.
#   Reads the host's {columns, tasks[]} JSON on stdin and writes one {"id","content"} line per row. Prints nothing, so every row keeps
#   the engine's default, without jq, on input it cannot read, or with the switch off.
# The switch is CC_HUD_SUBAGENTS, else CLAUDE_PLUGIN_OPTION_CC_HUD_SUBAGENTS where the host exports it, else the cc_hud_subagents
#   option saved in the user settings.json; a project- or local-scope saved option is not read.
command -v jq >/dev/null 2>&1 || exit 0

switch="${CC_HUD_SUBAGENTS:-${CLAUDE_PLUGIN_OPTION_CC_HUD_SUBAGENTS:-}}"
if [ -z "$switch" ]; then
  switch="$(jq -r 'first(.pluginConfigs? | objects | to_entries[] | select(.key | startswith("session-hud@"))
    | .value.options.cc_hud_subagents? | select(. != null) | tostring) // empty' "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/settings.json" 2>/dev/null)"
fi
case "$switch" in off | OFF | Off | 0 | false | FALSE | False) exit 0 ;; esac

jq -c --argjson now "$(date +%s)" '
  def pad2: tostring | if length < 2 then "0" + . else . end;
  def tok: if . >= 1000000 then "\((. / 100000 | floor) / 10)M" elif . >= 1000 then "\((. / 100 | floor) / 10)k" else "\(floor)" end;
  def age: (. / 1000 | floor) as $s
    | if $s >= 3600 then "\($s / 3600 | floor)h\(($s % 3600) / 60 | floor | pad2)m"
      elif $s >= 60 then "\($s / 60 | floor)m\($s % 60 | pad2)s"
      else "\($s)s" end;
  (.columns // 80) as $width
  | .tasks[]? | select(type == "object" and (.id | type) == "string")
  | . as $task
  | (.tokenCount // 0) as $tokens
  | [ (if .name then "@\(.name)" else empty end),
      (.agentType // empty),
      (.model // empty | sub("^claude-"; "") | sub("-[0-9]{8}$"; "")),
      (.effort // empty | tostring),
      (if (.contextWindowSize // 0) > 0 then "\($tokens | tok) \($tokens * 100 / .contextWindowSize | floor)%" else ($tokens | tok) end),
      ($now * 1000 - (.startTime // ($now * 1000)) | if . < 0 then 0 else . end | age),
      (.label // .description // empty)
    ]
  | map(select(. != "")) | join(" · ")
  | (({ completed: "✓ ", failed: "✗ ", killed: "✗ " })[$task.status // ""] // "") + .
  | { id: $task.id, content: .[0:$width] }
' 2>/dev/null
exit 0
