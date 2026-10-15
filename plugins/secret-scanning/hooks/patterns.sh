# patterns.sh — sourced, never run, by hooks/scan.sh (the write guard) and scripts/scan-range.sh (/secret-scanning:scan): one reader of
#   hooks/patterns.tsv, so the guard and the sweep cannot disagree on what a row means, what is a placeholder, or which value is judged.
# load_patterns <file>: reads <file> into pat_kind/pat_label/pat_flags/pat_re (secret and assigned rows, in file order) and the
#   ph_i/ph_c placeholder alternations; returns 1 with pat_bad set when it is missing or malformed.
# placeholder <value>: 0 when the value announces itself as fake. pat_value <kind> <match>: sets pat_v to the value a match is judged on.
# Why, limits, history: rationale/derivations/plugin-secret-scanning.md § plugins/secret-scanning/hooks/patterns.sh

load_patterns() {
  local line rest kind label flags re tabs n=0 nsecret=0 tab=$'\t' cr=$'\r'
  # Matched after dropping `\\` pairs, so an escaped backslash before a digit is not read as a backreference.
  local dialect='\[\[(:|\.|=)|\[:[[:alpha:]]+:\]|(^|[^\\])\(\?|\\[1-9]'
  # GNU grep reads \d as d and JavaScript as a digit; \b \B \w \W differ on non-ASCII letters, \s \S on U+00A0 and U+FEFF.
  local escape='\\[^].[+*?(){}|^$/-]'
  # No placeholder word, and every character class an assigned value can carry.
  local probe='Kq7Zt9_Wm2-Rp4/Lx8+Vn3=Bc6'
  pat_file=$1; pat_bad=""; pat_kind=(); pat_label=(); pat_flags=(); pat_re=(); ph_i=""; ph_c=""
  [ -f "$pat_file" ] && [ -r "$pat_file" ] || { pat_bad="missing or unreadable"; return 1; }
  while IFS= read -r line || [ -n "$line" ]; do
    n=$((n + 1))
    case "$line" in *"$cr"*) pat_bad="line $n carries a carriage return"; return 1 ;; '' | '#'*) continue ;; esac
    tabs=${line//[!$tab]/}
    [ "${#tabs}" -eq 3 ] || { pat_bad="line $n has $((${#tabs} + 1)) fields, not 4"; return 1; }
    kind=${line%%"$tab"*}; rest=${line#*"$tab"}
    label=${rest%%"$tab"*}; rest=${rest#*"$tab"}
    flags=${rest%%"$tab"*}; re=${rest#*"$tab"}
    [ -n "$label" ] && [ -n "$re" ] || { pat_bad="line $n has an empty label or pattern"; return 1; }
    case "$re" in ' '* | *' ') pat_bad="line $n has a pattern that starts or ends with a space; write an edge space as [ ]"; return 1 ;; esac
    case "$flags" in - | i) ;; *) pat_bad="line $n has flags '$flags', not - or i"; return 1 ;; esac
    case "$kind" in secret | assigned | placeholder) ;; *) pat_bad="line $n has kind '$kind', not secret, assigned or placeholder"; return 1 ;; esac
    [[ ${re//\\\\/} =~ $dialect ]] && { pat_bad="line $n uses [[:, [[., [[=, a [:class:], (? or a backreference, which grep and JavaScript read differently"; return 1; }
    [[ ${re//\\\\/} =~ $escape ]] && { pat_bad="line $n escapes a character other than ] . [ + * ? ( ) { } | ^ \$ / -, which grep and JavaScript read differently"; return 1; }
    grep -qE -- "$re" <<<'' 2>/dev/null
    case $? in
      0) pat_bad="line $n has a pattern that matches the empty string"; return 1 ;;
      1) ;;
      *) pat_bad="line $n has a pattern grep -E cannot compile"; return 1 ;;
    esac
    if [ "$kind" = placeholder ] && LC_ALL=C grep -qiE -- "$re" <<<"$probe" 2>/dev/null; then
      pat_bad="line $n: a placeholder row matches a secret-shaped value"; return 1
    fi
    case "$kind" in
      placeholder) if [ "$flags" = i ]; then ph_i="$ph_i${ph_i:+|}($re)"; else ph_c="$ph_c${ph_c:+|}($re)"; fi ;;
      *) [ "$kind" = secret ] && nsecret=$((nsecret + 1))
         pat_kind+=("$kind"); pat_label+=("$label"); pat_flags+=("$flags"); pat_re+=("$re") ;;
    esac
  done < "$pat_file"
  [ "$nsecret" -gt 0 ] || { pat_bad="no secret row"; return 1; }
  return 0
}

# LC_ALL=C: under UTF-8, grep -i also folds U+017F and U+212A into s and k.
placeholder() {
  local v="$1"
  [ -n "$ph_i" ] && printf '%s' "$v" | LC_ALL=C grep -qiE -- "$ph_i" && return 0
  [ -n "$ph_c" ] && printf '%s' "$v" | grep -qE -- "$ph_c" && return 0
  [ "$(printf '%s' "$v" | fold -w1 | sort -u | wc -l | tr -d ' ')" -le 1 ] && return 0
  return 1
}

# An assigned row is judged on what follows its first : or =, never the variable name; a match with nothing after it, on itself.
pat_value() {
  pat_v=$2
  [ "$1" = assigned ] && pat_v=$(printf '%s' "$2" | sed -E 's/^[^:=]*[:=]["'"'"' ]*//')
  pat_v=${pat_v:-$2}
}
