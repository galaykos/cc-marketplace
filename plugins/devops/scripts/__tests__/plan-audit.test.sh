#!/usr/bin/env bash
# Fixtures for plugins/devops/scripts/plan-audit.sh — the Terraform/OpenTofu plan
# reader. Run by CI via the plugins/*/scripts/__tests__/*.test.sh glob.
#
# The plan JSONs below are hand-written against the documented schema
# (developer.hashicorp.com/terraform/internals/json-format, re-read 2026-09-22):
# resource_changes[] with address/mode/type/name/change{actions,before,after}, and
# the actions vocabulary ["no-op"] ["create"] ["update"] ["delete"] ["delete","create"]
# ["create","delete"]. No `terraform` or `tofu` binary exists on the machine this was
# written on, so the reader is UNTESTED against output a real binary produced — the
# schema is honoured from the docs, not from a generated file.
#
# Both directions matter, same as the workflow-audit fixtures: a reader that flags
# every delete is a reader nobody runs, so the negative cases (a security group, a
# stateless helm_release, an update-only plan) are load-bearing, not padding.
set -u
cd "$(dirname "$0")/../../../.." || exit 1
AUDIT=plugins/devops/scripts/plan-audit.sh
rc=0
FX=$(mktemp -d); trap 'rm -rf "$FX"' EXIT

command -v jq >/dev/null 2>&1 || { echo "SKIP: jq not found"; exit 0; }

want() { # label want_rc json [extra args...]
  local label="$1" wantrc="$2" json="$3"; shift 3
  printf '%s\n' "$json" > "$FX/plan.json"
  local out got
  out=$(bash "$AUDIT" "$@" "$FX/plan.json" 2>&1); got=$?
  if [ "$got" = "$wantrc" ]; then echo "PASS: $label (rc=$got)"
  else echo "FAIL: $label — want rc=$wantrc, got $got"; printf '%s\n' "$out" | sed 's/^/        /'; rc=1; fi
}

plan() { # type action  -> a one-resource plan
  local t="$1" a="$2"
  cat <<EOF
{"format_version":"1.2","terraform_version":"1.9.5",
 "resource_changes":[
  {"address":"$t.main","mode":"managed","type":"$t","name":"main",
   "provider_name":"registry.terraform.io/hashicorp/aws",
   "change":{"actions":$a,"before":{"id":"x"},"after":null,"after_unknown":{}}}],
 "configuration":{"root_module":{"resources":[]}}}
EOF
}

want "delete of aws_db_instance"            2 "$(plan aws_db_instance '["delete"]')"
want "replace (delete then create)"         2 "$(plan aws_db_instance '["delete","create"]')"
want "replace (create then destroy)"        2 "$(plan aws_s3_bucket '["create","delete"]')"
want "delete of aws_security_group is fine" 0 "$(plan aws_security_group '["delete"]')"
want "creating a database is fine"          0 "$(plan aws_db_instance '["create"]')"
want "update-only plan"                     0 "$(plan aws_db_instance '["update"]')"
want "no-op plan"                           0 "$(plan aws_dynamodb_table '["no-op"]')"

# A module-nested address carries the real type, so the list still applies.
want "delete inside a module" 2 '{"format_version":"1.2",
 "resource_changes":[
  {"address":"module.storage.google_storage_bucket.assets","module_address":"module.storage",
   "mode":"managed","type":"google_storage_bucket","name":"assets",
   "change":{"actions":["delete"],"before":{"name":"assets"},"after":null}}]}'

# A data source is read, never destroyed; mode must gate it out.
want "a data-source delete is not a destroy" 0 '{"format_version":"1.2",
 "resource_changes":[
  {"address":"data.aws_s3_bucket.existing","mode":"data","type":"aws_s3_bucket","name":"existing",
   "change":{"actions":["delete"],"before":{},"after":null}}]}'

# helm_release: the one conditional row. Values naming a PVC → finding; a stateless
# release → silence. Flagging every release is how this gate gets switched off.
want "helm_release whose values name a PVC" 2 '{"format_version":"1.2",
 "resource_changes":[
  {"address":"helm_release.db","mode":"managed","type":"helm_release","name":"db",
   "change":{"actions":["delete"],
    "before":{"name":"db","chart":"postgresql",
              "values":["persistence:\n  enabled: true\n  existingClaim: pgdata\n"],
              "set":[]},
    "after":null}}]}'
want "a stateless helm_release is fine" 0 '{"format_version":"1.2",
 "resource_changes":[
  {"address":"helm_release.web","mode":"managed","type":"helm_release","name":"web",
   "change":{"actions":["delete"],
    "before":{"name":"web","chart":"nginx","values":["replicaCount: 2\n"],"set":[]},
    "after":null}}]}'
want "helm_release PVC named in a set block" 2 '{"format_version":"1.2",
 "resource_changes":[
  {"address":"helm_release.cache","mode":"managed","type":"helm_release","name":"cache",
   "change":{"actions":["delete","create"],
    "before":{"name":"cache","chart":"redis","values":[],
              "set":[{"name":"master.persistence.existingClaim","value":"redis-pvc"}]},
    "after":{"name":"cache"}}}]}'

# --- malformed and unreadable: fail CLOSED (1), never 0 ---------------------
want "truncated JSON" 1 '{"format_version":"1.2","resource_changes":['
want "valid JSON that is not a plan" 1 '{"hello":"world"}'
want "a JSON array, not an object" 1 '[1,2,3]'
printf '' > "$FX/empty.json"
bash "$AUDIT" "$FX/empty.json" >/dev/null 2>&1; [ $? -eq 1 ] \
  && echo "PASS: empty file exits 1" || { echo "FAIL: empty file did not exit 1"; rc=1; }
bash "$AUDIT" "$FX/does-not-exist.json" >/dev/null 2>&1; [ $? -eq 1 ] \
  && echo "PASS: missing file exits 1" || { echo "FAIL: missing file did not exit 1"; rc=1; }
bash "$AUDIT" --nonsense "$FX/empty.json" >/dev/null 2>&1; [ $? -eq 1 ] \
  && echo "PASS: unknown argument exits 1" || { echo "FAIL: unknown argument did not exit 1"; rc=1; }

# --- stdin, the documented invocation ---------------------------------------
plan aws_efs_file_system '["delete"]' | bash "$AUDIT" >/dev/null 2>&1; [ $? -eq 2 ] \
  && echo "PASS: stdin delete exits 2" || { echo "FAIL: stdin delete did not exit 2"; rc=1; }
plan aws_security_group '["delete"]' | bash "$AUDIT" - >/dev/null 2>&1; [ $? -eq 0 ] \
  && echo "PASS: explicit - reads stdin" || { echo "FAIL: explicit - did not read stdin"; rc=1; }

# --- the finding line names address, type, action and why -------------------
out=$(plan aws_dynamodb_table '["delete","create"]' | bash "$AUDIT" 2>&1)
if printf '%s' "$out" | grep -q 'aws_dynamodb_table.main' \
   && printf '%s' "$out" | grep -q 'replace' \
   && printf '%s' "$out" | grep -qi 'every item in it'; then
  echo "PASS: finding line carries address, action and reason"
else
  echo "FAIL: finding line is missing a field: $out"; rc=1
fi

# --- --list-types is the user-visible list ----------------------------------
out=$(bash "$AUDIT" --list-types); got=$?
n=$(printf '%s\n' "$out" | grep -c '^[a-z]')
if [ "$got" -eq 0 ] && [ "$n" -eq 15 ] && printf '%s' "$out" | grep -q 'kubernetes_persistent_volume_claim'; then
  echo "PASS: --list-types prints 15 types and exits 0"
else
  echo "FAIL: --list-types printed $n row(s), rc=$got"; rc=1
fi

# --- prevent_destroy: read from the .tf SOURCE, because the plan JSON has no
#     lifecycle key at all (verified against the JSON output format docs). The
#     fixture is a git work tree: protection present at --base, gone in the tree.
TF="$FX/tf"; mkdir -p "$TF"
git init -q "$TF" 2>/dev/null
git -C "$TF" config user.email t@example.com
git -C "$TF" config user.name tester
cat > "$TF/main.tf" <<'TFEOF'
resource "aws_s3_bucket" "state" {
  bucket = "org-tfstate"
  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_security_group" "web" {
  name = "web"
}
TFEOF
git -C "$TF" add -A >/dev/null 2>&1
git -C "$TF" commit -q -m base >/dev/null 2>&1
CLEAN=$(plan aws_security_group '["update"]')
printf '%s\n' "$CLEAN" > "$FX/clean.json"

bash "$AUDIT" --tf-dir "$TF" "$FX/clean.json" >/dev/null 2>&1; [ $? -eq 0 ] \
  && echo "PASS: protection intact and a clean plan exits 0" \
  || { echo "FAIL: unchanged source reported a removal"; rc=1; }

cat > "$TF/main.tf" <<'TFEOF'
resource "aws_s3_bucket" "state" {
  bucket = "org-tfstate"
}

resource "aws_security_group" "web" {
  name = "web"
}
TFEOF
out=$(bash "$AUDIT" --tf-dir "$TF" "$FX/clean.json" 2>&1); got=$?
if [ "$got" -eq 2 ] && printf '%s' "$out" | grep -q 'aws_s3_bucket.state' \
   && printf '%s' "$out" | grep -q 'prevent_destroy removed'; then
  echo "PASS: prevent_destroy removal exits 2 and names the resource"
else
  echo "FAIL: prevent_destroy removal — rc=$got: $out"; rc=1
fi

# Removing the whole protected block is the same loss of protection, and it is the
# form that actually lets a destroy plan: the resource leaves the config and state
# still has it.
cat > "$TF/main.tf" <<'TFEOF'
resource "aws_security_group" "web" {
  name = "web"
}
TFEOF
bash "$AUDIT" --tf-dir "$TF" "$FX/clean.json" >/dev/null 2>&1; [ $? -eq 2 ] \
  && echo "PASS: deleting the protected resource block exits 2" \
  || { echo "FAIL: deleting the protected block was not reported"; rc=1; }

git -C "$TF" checkout -q -- main.tf
out=$(bash "$AUDIT" --tf-dir "$FX" "$FX/clean.json" 2>&1)
printf '%s' "$out" | grep -q 'prevent_destroy: NOT CHECKED' \
  && echo "PASS: outside a git work tree the check says NOT CHECKED, not clean" \
  || { echo "FAIL: no NOT CHECKED notice outside a work tree: $out"; rc=1; }
out=$(bash "$AUDIT" --tf-dir "$TF" --base no-such-ref "$FX/clean.json" 2>&1)
printf '%s' "$out" | grep -q 'NOT CHECKED' \
  && echo "PASS: an unresolvable --base says NOT CHECKED" \
  || { echo "FAIL: unresolvable --base was silent: $out"; rc=1; }

# A destroy of a stateful type must still exit 2 with the source half unavailable.
bash "$AUDIT" --tf-dir "$FX" <(plan azurerm_managed_disk '["delete"]') >/dev/null 2>&1
[ $? -eq 2 ] && echo "PASS: stateful delete exits 2 with no source to read" \
  || { echo "FAIL: stateful delete did not exit 2 without source"; rc=1; }

[ "$rc" -eq 0 ] && echo "All devops plan-audit fixtures passed."
exit "$rc"
