#!/usr/bin/env bash
# scan.sh — the mechanical core of stack-scan: required-vs-installed inventory
# from manifests, lockfiles, runtimes, and container files, as one markdown
# report on stdout. Deterministic parses only; interpretation (upgrade advice,
# EOL judgment) stays with the skill that wraps this.
#
# Usage: scan.sh [project-root]     Exit 0 always (a report, not a gate).
#
# Residual: covers node/php/python + docker files. Go/Rust/.NET/JVM rules exist
# in references/ecosystems.md as instructions, not code — a repo in those
# stacks gets the "not covered by scan.sh" line, never a silent zero.
set -u
root="${1:-.}"
cd "$root" 2>/dev/null || { echo "stack-scan: bad root '$root'"; exit 0; }

j() { command -v jq >/dev/null 2>&1; }
have() { command -v "$1" >/dev/null 2>&1; }
row() { printf '| %s | %s | %s | %s |\n' "$1" "$2" "$3" "$4"; }

echo "# Stack scan — $(basename "$(pwd)")"
echo
echo "| Component | Required (manifest) | Installed | Source |"
echo "|---|---|---|---|"

flags=()

# ---------------- Node ----------------
if [[ -f package.json ]] && j; then
  eng=$(jq -r '.engines.node // "—"' package.json 2>/dev/null)
  inst=$(have node && node -v 2>/dev/null || echo "not installed")
  row "node runtime" "$eng" "$inst" "package.json engines"
  # engines-vs-installed major check (coarse: first integer of each).
  if [[ "$eng" != "—" && "$inst" == v* ]]; then
    imaj="${inst#v}"; imaj="${imaj%%.*}"
    emaj=$(grep -oE '[0-9]+' <<<"$eng" | head -1)
    [[ -n "$emaj" && "$imaj" -lt "$emaj" ]] \
      && flags+=("node $inst is below the engines floor '$eng'")
  fi
  locks=()
  [[ -f package-lock.json ]] && locks+=("package-lock.json")
  [[ -f yarn.lock ]] && locks+=("yarn.lock")
  [[ -f pnpm-lock.yaml ]] && locks+=("pnpm-lock.yaml")
  [[ -f bun.lock || -f bun.lockb ]] && locks+=("bun.lock")
  case ${#locks[@]} in
    0) flags+=("package.json with NO lockfile — installs are nondeterministic") ;;
    1) row "js lockfile" "—" "${locks[0]}" "filesystem" ;;
    *) flags+=("MULTIPLE js lockfiles (${locks[*]}) — resolver choice is nondeterministic") ;;
  esac
  [[ -f package.json && -n "${locks[0]:-}" && package.json -nt "${locks[0]}" ]] \
    && flags+=("package.json is newer than ${locks[0]} — lock may be stale")
  # Top framework floors worth pinning advice to.
  for dep in react vue nuxt next vite express fastify "@nestjs/core" livewire; do
    req=$(jq -r --arg d "$dep" '.dependencies[$d] // .devDependencies[$d] // empty' package.json 2>/dev/null)
    [[ -z "$req" ]] && continue
    res="—"
    if [[ -f node_modules/$dep/package.json ]]; then
      res=$(jq -r '.version // "—"' "node_modules/$dep/package.json" 2>/dev/null)
    elif [[ -f package-lock.json ]]; then
      res=$(jq -r --arg d "$dep" '.packages["node_modules/"+$d].version // "—"' package-lock.json 2>/dev/null)
    fi
    row "$dep" "$req" "$res" "package.json / lock"
  done
fi

# ---------------- PHP ----------------
if [[ -f composer.json ]] && j; then
  req=$(jq -r '.require.php // "—"' composer.json 2>/dev/null)
  inst=$(have php && php -r 'echo PHP_VERSION;' 2>/dev/null || echo "not installed")
  row "php runtime" "$req" "$inst" "composer.json require.php"
  [[ -f composer.lock ]] || flags+=("composer.json with NO composer.lock — installs are nondeterministic")
  for dep in laravel/framework livewire/livewire inertiajs/inertia-laravel symfony/framework-bundle; do
    creq=$(jq -r --arg d "$dep" '.require[$d] // empty' composer.json 2>/dev/null)
    [[ -z "$creq" ]] && continue
    res="—"
    [[ -f composer.lock ]] && res=$(jq -r --arg d "$dep" '[.packages[]?, ."packages-dev"[]? | select(.name==$d)][0].version // "—"' composer.lock 2>/dev/null)
    row "$dep" "$creq" "$res" "composer.json / lock"
  done
fi

# ---------------- Python ----------------
if [[ -f pyproject.toml ]]; then
  req=$(grep -E '^\s*requires-python' pyproject.toml | head -1 | sed 's/.*=\s*//; s/["'"'"']//g')
  inst=$(have python3 && python3 -V 2>&1 | awk '{print $2}' || echo "not installed")
  row "python runtime" "${req:-—}" "$inst" "pyproject.toml"
elif [[ -f requirements.txt ]]; then
  inst=$(have python3 && python3 -V 2>&1 | awk '{print $2}' || echo "not installed")
  row "python runtime" "requirements.txt (no floor)" "$inst" "requirements.txt"
fi

# ---------------- Containers ----------------
for df in Dockerfile Dockerfile.*; do
  [[ -f "$df" ]] || continue
  while IFS= read -r img; do
    row "container base" "$img" "—" "$df FROM"
    [[ "$img" == *:latest || "$img" != *:* ]] \
      && flags+=("$df uses unpinned image '$img' — pin a digest or version tag")
  done < <(grep -iE '^FROM ' "$df" | awk '{print $2}' | sort -u)
done
for cf in docker-compose.yml docker-compose.yaml compose.yml compose.yaml; do
  [[ -f "$cf" ]] || continue
  while IFS= read -r img; do
    row "compose image" "$img" "—" "$cf"
  done < <(grep -E '^\s*image:' "$cf" | sed 's/.*image:\s*//; s/["'"'"']//g' | sort -u)
done

# ---------------- Not covered ----------------
for f in go.mod Cargo.toml global.json build.gradle pom.xml Gemfile; do
  [[ -f "$f" ]] && flags+=("$f present — ecosystem not covered by scan.sh; apply references/ecosystems.md by hand")
done
j || flags+=("jq not installed — node/php sections skipped")

echo
if [[ ${#flags[@]} -gt 0 ]]; then
  echo "## Red flags"
  for f in "${flags[@]}"; do echo "- $f"; done
else
  echo "## Red flags"; echo "- none detected by the mechanical pass"
fi
exit 0
