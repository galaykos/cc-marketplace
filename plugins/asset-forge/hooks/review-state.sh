#!/bin/bash
# PostToolUse marks this context's scene changed after a Blender MCP execute_blender_code call and clears it after a successful forge render_review_set; Stop blocks once per change cycle when the scene changed since the last review and asset-forge is in use here.
# Misses: changes made by hand in Blender, reviews done without render_review_set, execute calls that only read (they mark it changed too), a context that never touched forge (never blocked). Fail-open. Off: CC_FORGE_REVIEW=off, or /config.
# Why, limits, history: rationale/derivations/plugin-asset-forge.md § plugins/asset-forge/hooks/review-state.sh

# Shared block templates/blocks/option-resolver.md — edit there, re-paste byte-for-byte.
# Why, limits, history: rationale/derivations/templates-and-blocks.md § templates/blocks/option-resolver.md
# cc_option <ENV_NAME> <default> [<level-file>] prints, status 0, the first non-empty of: variable ENV_NAME,
# <level-file>'s first word, option CLAUDE_PLUGIN_OPTION_<ENV_NAME> (true/false as on/off), <default>.
# The host exports only SAVED options, so <default> must equal the manifest's default.
# Misses: a malformed name, which yields <default>; a variable passed instead of a literal name; a value outside the vocabulary.
cc_option() {
  local v="" opt
  case "${1:-}" in '' | [0-9]* | *[!A-Za-z0-9_]*) printf '%s\n' "${2:-}"; return 0 ;; esac
  v="${!1:-}"
  if [ -z "$v" ] && [ -n "${3:-}" ] && [ -f "$3" ] && [ -r "$3" ]; then
    read -r v _ 2>/dev/null < "$3" || :
  fi
  if [ -z "$v" ]; then
    opt="CLAUDE_PLUGIN_OPTION_$1"; v="${!opt:-}"
    case "$v" in true) v=on ;; false) v=off ;; esac
  fi
  [ -n "$v" ] || v="${2:-}"
  printf '%s\n' "$v"
  return 0
}

{
  command -v jq >/dev/null 2>&1 || exit 0
  input=$(cat)
  [ "$(cc_option CC_FORGE_REVIEW on)" = off ] && exit 0
  IFS=$'\x1f' read -r event key tool forge_code reviewed stop_active <<EOF
$(printf '%s' "$input" | jq -r '[.hook_event_name // "", .transcript_path // .session_id // "", .tool_name // "",
  ((.tool_input.code // "") | tostring | test("blender_lib|from forge|import forge")),
  ([.tool_response | .. | if type == "string" and startswith("{") then (try fromjson catch null) else . end
    | objects | select(.ok == true and (.contact_sheet | type) == "string")] | length > 0),
  .stop_hook_active // false] | map(tostring) | join("\u001f")')
EOF
  [ -n "$key" ] || exit 0
  base="${CLAUDE_PLUGIN_DATA:-${TMPDIR:-/tmp}/asset-forge}"
  dir="$base/review-$(printf '%s' "$key" | cksum | cut -d' ' -f1)"
  mkdir -p "$dir" && touch "$dir" || exit 0
  find "$base" -mindepth 1 -maxdepth 1 -type d -name 'review-*' -mmin +1440 -exec rm -rf {} + 2>/dev/null

  case "$event" in
    PostToolUse)
      case "$tool" in
        mcp__*__execute_blender_code)
          [ "$forge_code" = true ] && : > "$dir/active"
          [ -f "$dir/dirty" ] || date +%s > "$dir/dirty"
          ;;
        mcp__plugin_asset-forge_forge__*)
          : > "$dir/active"
          if [ "$tool" = mcp__plugin_asset-forge_forge__render_review_set ] && [ "$reviewed" = true ]; then
            rm -f "$dir/dirty" "$dir"/blocked-*
          fi
          ;;
      esac
      ;;
    Stop)
      [ "$stop_active" = true ] && exit 0
      [ -f "$dir/active" ] && [ -f "$dir/dirty" ] || exit 0
      since=$(cat "$dir/dirty")
      [ -e "$dir/blocked-$since" ] && exit 0
      : > "$dir/blocked-$since" || exit 0
      jq -cn '{decision: "block", reason: "asset-forge: the Blender scene changed since the last review. Run /asset-forge:review (snapshot, then render_review_set) before calling the asset done, or tell the user why you are skipping it. This reminder fires once per change cycle; CC_FORGE_REVIEW=off turns it off."}'
      ;;
  esac
} 2>/dev/null
exit 0
