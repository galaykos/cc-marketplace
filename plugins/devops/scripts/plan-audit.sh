#!/bin/bash
# Terraform / OpenTofu PLAN READER. Reads a plan as JSON — `terraform show -json
# plan.out` or `tofu show -json plan.out` — from a path argument or stdin, and exits 2
# when applying that plan would destroy something whose contents do not come back.
#
#   bash plan-audit.sh plan.json
#   terraform show -json plan.out | bash plan-audit.sh
#   bash plan-audit.sh --list-types                 # the stateful list, with reasons
#   bash plan-audit.sh --tf-dir infra --base origin/main plan.json
#
# Exit: 0 nothing found · 2 a finding · 1 cannot answer (no jq, unreadable file,
#       not JSON, not a plan)
#
# WHY A SCRIPT AND NOT A `terraform-best-practices` SKILL. A skill restating
# Terraform's own documentation is shape 4 in rationale/measured-zero-shapes.md and
# measured zero three times over. The thing a model cannot do from memory is read
# THIS plan: which of the 300 resource changes in front of it takes data with it.
# So this ships as a thing that runs, with an exit code, not a thing that is read.
#
# WHY IT FAILS CLOSED. Every hook in this marketplace fails OPEN and says so in its
# own header, because a guard that wedges a session gets uninstalled. This is not a
# hook: nothing invokes it on a keystroke, its output is read by a human or a CI
# step, and the only other thing it could say about a plan it cannot parse is
# "clean". So a parse error exits 1 and never 0.
#
# WHAT IT CATCHES
#   1. A `delete` — or a replace, which is a delete plus a create — of a resource
#      whose type is on the stateful list below. `--list-types` prints it.
#   2. `lifecycle.prevent_destroy = true` removed from a resource since --base.
#      This one is read from the .tf SOURCE, not from the plan: lifecycle is
#      configuration Terraform does not record in state and does not emit in the
#      JSON plan, so `configuration.root_module.resources[].expressions` has no
#      `lifecycle` key to read (verified 2026-09-22 against
#      developer.hashicorp.com/terraform/internals/json-format and
#      hashicorp/terraform#30271). A plan-only check for it would be theater.
#
# WHAT IT DOES NOT CATCH
#   - A resource type that is not on the list: another provider (DigitalOcean,
#     Oracle, Alicloud), a stateful type nobody added (`aws_rds_cluster_instance`,
#     `aws_elasticache_replication_group`), or a module that wraps the storage in a
#     type of its own. Module nesting itself is fine — `resource_changes` carries the
#     real type and the full `module.x.` address — but a wrapper that owns the data
#     under an unlisted type reads as ordinary.
#   - Data loss inside an `update`. No delete action appears for a shrunk
#     `allocated_storage`, an engine downgrade, `skip_final_snapshot` flipped to
#     true, or a `force_destroy` newly set — all of those plan as in-place changes.
#   - A `moved` block, which is an address change: the plan says no-op and there is
#     nothing to find. (Good — that is the point of `moved`.)
#   - Whether the destroy is RECOVERABLE. A final snapshot, `deletion_protection`,
#     bucket versioning and PITR are not modelled; a listed type being destroyed is a
#     finding even when the backup makes it survivable.
#   - A `helm_release` whose PVC comes from the chart's own defaults with no mention
#     in the release's values. Only values/set text is scanned.
#   - Anything about a plan that is stale, or about drift since it was generated. It
#     reads the file it is handed and does not run Terraform.
#
# Panel finding 43 (rationale/specialist-panel-2026-09-22.md §2, ops detail 9): the
# marketplace had no IaC lane at all, and the mechanism-bearing slice of that gap is
# this reader — not a terraform skill.
set -u

die() { printf 'plan-audit: %s\n' "$1" >&2; exit 1; }

# type <TAB> why it is stateful. Kept as data so --list-types and the finding lines
# read from one source.
stateful_types() {
  cat <<'TYPES'
aws_db_instance	an RDS instance; the destroy takes its databases with it unless a final snapshot is configured, and the snapshot is not visible in this plan
aws_rds_cluster	an Aurora/RDS cluster and the storage every instance in it shares
aws_s3_bucket	a bucket; deleting one requires it be empty, or force_destroy, which discards every object and version in it
aws_dynamodb_table	the table and every item in it; PITR does not survive the table
aws_efs_file_system	the filesystem and every file on it
aws_ebs_volume	the block volume and its data; a detached snapshot is not implied
google_sql_database_instance	the Cloud SQL instance and every database on it
google_storage_bucket	the bucket and every object in it
google_compute_disk	the persistent disk and its data
azurerm_storage_account	the account and every blob, file, queue and table under it
azurerm_mssql_database	the database and its data
azurerm_postgresql_flexible_server	the server and every database on it
azurerm_managed_disk	the managed disk and its data
kubernetes_persistent_volume_claim	the claim; with a Delete reclaim policy the bound volume and its data go with it
helm_release	a release whose values name a PVC; uninstalling it removes the chart's persistent volumes
TYPES
}

# helm_release is the one conditional row: most releases are stateless and flagging
# every one of them is how a gate gets switched off. Matched against the release's
# values/set text only — see WHAT IT DOES NOT CATCH.
HELM_PVC_RE='persistentvolumeclaim|claimname|persistence|"pvc|[-_.]pvc'

plan_file=""
tf_dir=""
base="HEAD"
while [ $# -gt 0 ]; do
  case "$1" in
    --list-types)
      stateful_types | while IFS="$(printf '\t')" read -r t w; do printf '%-40s %s\n' "$t" "$w"; done
      exit 0 ;;
    --tf-dir) tf_dir="${2:-}"; shift 2 ;;
    --base) base="${2:-}"; shift 2 ;;
    -h|--help) sed -n '2,12p' "$0"; exit 0 ;;
    -) plan_file="-"; shift ;;
    -*) die "unknown argument $1" ;;
    *) plan_file="$1"; shift ;;
  esac
done

command -v jq >/dev/null 2>&1 || die "jq is required to read a plan JSON and is not on PATH"

if [ -z "$plan_file" ] || [ "$plan_file" = "-" ]; then
  plan_file="-"
  plan=$(cat)
else
  # -r, not -f: `plan-audit.sh <(terraform show -json plan.out)` hands over a
  # /dev/fd entry, which is not a regular file.
  [ -r "$plan_file" ] || die "cannot read $plan_file"
  plan=$(cat "$plan_file" 2>/dev/null) || die "cannot read $plan_file"
fi
case "$plan" in *[![:space:]]*) ;; *) die "empty input — pipe \`terraform show -json plan.out\`, or pass its output as a file" ;; esac

printf '%s' "$plan" | jq -e . >/dev/null 2>&1 \
  || die "input is not valid JSON. \`terraform show -json plan.out\` converts a binary plan file; the plan file itself is not JSON"
printf '%s' "$plan" | jq -e 'type == "object" and (has("resource_changes") or has("format_version"))' >/dev/null 2>&1 \
  || die "this JSON is not a Terraform/OpenTofu plan — no top-level format_version or resource_changes"

types_json=$(stateful_types | jq -Rn '[inputs | split("\t") | {(.[0]): .[1]}] | add')

findings=$(printf '%s' "$plan" | jq -r \
  --argjson types "$types_json" --arg helm "$HELM_PVC_RE" '
  def act_label: if (index("delete") and index("create")) then "replace (delete + create)" else "delete" end;
  [ .resource_changes[]?
    | select((.mode // "managed") == "managed")
    | select((.change.actions // []) | index("delete"))
    | . as $r
    | ($types[$r.type] // "") as $why
    | select($why != "")
    | select($r.type != "helm_release"
             or ((($r.change.before // {}) | [.values, .set] | tostring)
                 + (($r.change.after // {}) | [.values, .set] | tostring)
                 | test($helm; "i")))
    | [ $r.address, $r.type, ($r.change.actions | act_label), $why ] | @tsv
  ] | .[]') || die "could not read resource_changes out of this plan"

changed=$(printf '%s' "$plan" | jq -r '(.resource_changes // []) | length')

# --- prevent_destroy: source-side, because the plan JSON does not carry lifecycle ---
# Set difference, not a diff-hunk read: an address protected at $base and no longer
# protected in the working tree is a finding whether the line was deleted, flipped to
# false, or the whole resource block was removed from the configuration — that last
# one is how a protected resource gets destroyed in practice. Only files the diff
# touches are read, so a move between two changed files does not read as a removal.
protected_addresses() { # stdin: HCL · stdout: type.name per protected resource
  awk '
    /^[[:space:]]*(data|module|variable|output|locals|provider|terraform|import|check|moved|removed)[[:space:]]*[{"]/ { cur = "" }
    /^[[:space:]]*resource[[:space:]]+"/ {
      if (match($0, /resource[[:space:]]+"[^"]+"[[:space:]]+"[^"]+"/)) {
        split(substr($0, RSTART, RLENGTH), p, "\"")
        cur = p[2] "." p[4]
      }
      next
    }
    /prevent_destroy[[:space:]]*=[[:space:]]*true/ { if (cur != "") print cur }
  ' | sort -u
}

pd_state=""
pd_findings=""
[ -n "$tf_dir" ] || { if [ "$plan_file" = "-" ]; then tf_dir="."; else tf_dir="$(dirname "$plan_file")"; fi; }
if [ ! -d "$tf_dir" ]; then
  pd_state="NOT CHECKED — --tf-dir $tf_dir is not a directory"
elif ! git -C "$tf_dir" rev-parse --git-dir >/dev/null 2>&1; then
  pd_state="NOT CHECKED — $tf_dir is not in a git work tree; pass --tf-dir <terraform source>"
elif ! git -C "$tf_dir" rev-parse --verify --quiet "$base^{commit}" >/dev/null 2>&1; then
  pd_state="NOT CHECKED — --base $base does not resolve in $tf_dir"
else
  root=$(git -C "$tf_dir" rev-parse --show-toplevel)
  changed_tf=$(git -C "$tf_dir" diff --name-only "$base" -- . 2>/dev/null | grep -E '\.(tf|tofu)$')
  if [ -z "$changed_tf" ]; then
    pd_state="checked $base..worktree in $tf_dir — no .tf/.tofu file changed"
  else
    before_set=$(printf '%s\n' "$changed_tf" | while IFS= read -r f; do
      [ -n "$f" ] && git -C "$tf_dir" show "$base:$f" 2>/dev/null
    done | protected_addresses)
    after_set=$(printf '%s\n' "$changed_tf" | while IFS= read -r f; do
      [ -n "$f" ] && [ -f "$root/$f" ] && cat "$root/$f"
    done | protected_addresses)
    pd_findings=$(comm -23 <(printf '%s\n' "$before_set" | grep -v '^$' | sort -u) \
                           <(printf '%s\n' "$after_set" | grep -v '^$' | sort -u))
    pd_state="checked $base..worktree in $tf_dir"
  fi
fi

count=0
if [ -n "$findings" ]; then
  while IFS="$(printf '\t')" read -r addr rtype action why; do
    [ -n "$addr" ] || continue
    count=$((count + 1))
    printf 'stateful  %s — %s — %s — %s\n' "$addr" "$rtype" "$action" "$why"
  done <<EOF
$findings
EOF
fi
if [ -n "$pd_findings" ]; then
  while IFS= read -r addr; do
    [ -n "$addr" ] || continue
    count=$((count + 1))
    printf 'unguarded  %s — %s — prevent_destroy removed — protected at %s, not protected in the working tree: the lifecycle rule that would have refused a destroy of this resource is gone\n' \
      "$addr" "${addr%%.*}" "$base"
  done <<EOF
$pd_findings
EOF
fi

printf 'plan-audit: %s finding(s) in %s resource change(s); prevent_destroy: %s\n' \
  "$count" "$changed" "$pd_state"
[ "$count" -gt 0 ] && exit 2
exit 0
