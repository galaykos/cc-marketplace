#!/usr/bin/env bash
# Smoke tests for comment-discipline/hooks/density.sh (comment VOLUME) and the shared
# worktree path scoping in hooks/paths.sh that both file guards now use.
#
# The two properties worth defending, because getting either wrong makes the hook
# useless in the exact situation it was written for:
#
#   1. THE BASELINE IS PRE-EXISTING CODE. A fan-out writing many uniformly dense files
#      into a new subtree must not compute its baseline from its own output. Asserted
#      both ways: dense-file-vs-committed-house-style fires, and the same dense file
#      surrounded only by its own untracked siblings must ALSO fire.
#   2. WORKTREE PATHS ARE IN SCOPE. This marketplace places worktrees at
#      `.claude/worktrees/<branch>`, and the `*/.claude/*` exemption was silently
#      excluding every file a track run wrote.
#   3. THE CEILING IS ABSOLUTE AND THE SIBLING TEST SURVIVES IT. A file with no
#      tracked siblings is judged against the ceiling; a file under the ceiling but
#      2x its lean siblings still fires; `COMMENT_DISCIPLINE_CEILING_TENTHS=0`
#      restores the sibling-only behaviour; and the PreToolUse lane denies a whole
#      Write over the ceiling exactly once per file.
#
# Scratch git repos throughout; never the live repo, never real .claude state.
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
HOOK="$ROOT/plugins/code-review/hooks/density.sh"
SCAN="$ROOT/plugins/code-review/hooks/scan.sh"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
rc=0
export HOME="$TMP/home"   # keep the ledger out of the real ~/.claude
unset CLAUDE_PLUGIN_DATA   # the cases read hook state under <root>/.claude

# ---- 0. THE CLASSIFIER (paths.sh): golden prose / comment / code triples ----------
# Expected numbers, not a second awk: BSD awk here and the awk CI ships answer to one table.
. "$ROOT/plugins/code-review/hooks/paths.sh"
same() { # $1 label, $2 got, $3 want
  if [ "$2" = "$3" ]; then echo "PASS: $1"; else echo "FAIL: $1 — got: ${2:-<nothing>} want: $3"; rc=1; fi
}
gold() { same "$1" "$(cd_classify "$2")" "$3"; } # $1 label, $2 language key, $3 expected triple; fixture on stdin

gold "classify: c01 js // lines are prose, a trailing // is code" js "2 2 2" <<'FIX'
// why
const a = 1;
const b = 2; // x
    // why
FIX
gold "classify: c02 ts a docblock's text lines are prose, its delimiters are not" ts "2 4 1" <<'FIX'
/**
 * text one
 * text two
 */
const a = 1;
FIX
gold "classify: c03 php bare text lines inside /* */ are prose" php "2 5 1" <<'FIX'
<?php
/*
text one
text two
*/
$a = 1;
FIX
gold "classify: c04 php #[Attribute] is code, # why is prose" php "1 2 2" <<'FIX'
<?php
#[Attribute]
# why
class A {}
FIX
gold "classify: c05 rs #[derive] is code, /// is prose" rs "1 1 2" <<'FIX'
#[derive(Debug)]
struct A;
/// why
FIX
gold "classify: c06 c #include, #define and a leading * are code" c "0 0 4" <<'FIX'
#include <x.h>
#define N 4
* p = 0;
int main(void) { return N; }
FIX
gold "classify: c07 js a #private field and --i are code" js "0 0 4" <<'FIX'
class A {
  #count = 0;
}
--i;
FIX
gold "classify: c07 cs #region and #endregion are code" cs "0 0 3" <<'FIX'
#region F
int a;
#endregion
FIX
gold "classify: c08 py a module docstring and a function docstring are comments" py "2 4 3" <<'FIX'
"""
text
"""
import os
def f(x):
    """Doc."""
    return x
FIX
gold "classify: c09 py a triple-quoted string that is no docstring is code, with the # line inside it" py "0 0 10" <<'FIX'
import os
S = """
# x
select 1
"""
def f():
    x = 1
    """
    text
    """
FIX
gold "classify: c10 py a docstring after a def header spanning lines is a comment" py "2 4 5" <<'FIX'
# why
def g(
    a,
    b,
):
    """
    text
    """
    return a
FIX
gold "classify: c11 sh a line-1 shebang is not prose and a heredoc body is code" sh "1 2 4" <<'FIX'
#!/bin/bash
# why
cat <<EOF
# body
EOF
echo ok
FIX
gold "classify: c12 sql -- and /* */ are prose" sql "2 2 1" <<'FIX'
-- why
/* why */
SELECT 1;
FIX
gold "classify: c12 lua -- is prose and --[[ ]] is a block" lua "2 4 1" <<'FIX'
-- why
--[[
text
]]
local x = 1
FIX
gold "classify: c13 vue <!-- --> and // are comments" vue "3 5 5" <<'FIX'
<template>
  <!-- why -->
  <!--
    text
  -->
  <div/>
</template>
<script>
// why
</script>
FIX
gold "classify: c14 blade {{-- --}} is a comment and // is code" blade "2 4 3" <<'FIX'
{{-- why --}}
{{--
  text
--}}
<div>
  // text
</div>
FIX
gold "classify: c15 tsx {/* */} is a comment" tsx "1 1 5" <<'FIX'
const A = () => (
  <div>
    {/* why */}
    <span />
  </div>
);
FIX
gold "classify: c16 css /* */ is a comment, #header and // are code" css "1 1 3" <<'FIX'
/* why */
#header { color: red; }
// x
.a { color: blue; }
FIX
gold "classify: c16 scss // is prose" scss "1 1 1" <<'FIX'
// why
.a { color: blue; }
FIX
gold "classify: c17 rb =begin/=end is a block and #{ is code" rb "2 4 2" <<'FIX'
# why
=begin
text
=end
#{x}
x = 1
FIX
gold "classify: c17 pl POD is a block" pl "2 4 1" <<'FIX'
# why
=pod
text
=cut
my $x = 1;
FIX
gold "classify: c18 ex a @moduledoc heredoc is a block" ex "2 4 3" <<'FIX'
defmodule A do
  @moduledoc """
  text
  """
  # why
  def f, do: 1
end
FIX
gold "classify: c19 dockerfile # is prose and a quoted # is code" dockerfile "1 1 2" <<'FIX'
# why
FROM a
RUN echo "# x"
FIX
printf '# why\n.PHONY: all\nall:\n\t# why\n\techo ok\n' > "$TMP/c19.mk"
gold "classify: c19 make # is prose in a recipe too" make "2 2 3" < "$TMP/c19.mk"
gold "classify: c20 tf #, // and /* */ are prose" tf "3 3 1" <<'FIX'
# why
// why
/* why */
resource "x" "y" {}
FIX
gold "classify: c20 graphql # is prose" graphql "1 1 1" <<'FIX'
# why
type A { id: ID }
FIX
gold "classify: c21 js a closer followed by code makes the line code" js "1 2 3" <<'FIX'
/* why */ const a = 1;
const b = /* x */ 2;
/*
 why
*/ const c = 3;
FIX
gold "classify: c22 js a block comment never closed is code" js "0 0 4" <<'FIX'
const a = 1;
/*
 text one
 text two
FIX
gold "classify: c22 py a docstring never closed is code" py "0 0 3" <<'FIX'
"""
text
x = 1
FIX
gold "classify: c23 ts delimiters alone are comments, not prose" ts "0 4 0" <<'FIX'
/**
 */
/*
*/
FIX
printf '\357\273\277// why\r\n\r\nconst a = 1;\r\n   \r\n' > "$TMP/c24.js"
gold "classify: c24 js a BOM, CRLF endings and blank lines" js "1 1 1" < "$TMP/c24.js"
printf '// caf\351 \377\376 why\n$x = "\377";\n' > "$TMP/c25.php"
gold "classify: c25 php invalid UTF-8 bytes" php "1 1 1" < "$TMP/c25.php"
gold "classify: c26 md an unknown key is all code" md "0 0 2" <<'FIX'
# heading
text
FIX
gold "classify: c26 empty stdin prints 0 0 0" js "0 0 0" < /dev/null

printf '%s\n' '// why' 'const a = 1;' 'const b = 2; // x' '    // why' > "$TMP/c27a.js"
: > "$TMP/c27b.js"
printf '%s\n' 'const a = 1;' 'const b = 2;' 'const c = 3;' 'const d = 4;' > "$TMP/c27c.js"
same "classify: c27 js three operands, one empty, print two lines in operand order" \
  "$(cd_classify js "$TMP/c27a.js" "$TMP/c27b.js" "$TMP/c27c.js")" "2 2 2
0 0 4"

timed() { # $1 file, $2 language key (default js) -> the triple, with the time appended only when it is over 5 s
  local t0=$SECONDS got
  got=$(cd_classify "${2:-js}" "$1")
  [ $((SECONDS - t0)) -le 5 ] || got="$got (took $((SECONDS - t0)) s)"
  printf '%s' "$got"
}
for i in $(seq 1 6000); do printf '// why %s\nconst a%s = %s;\n' "$i" "$i" "$i"; done > "$TMP/c28a.js"
same "classify: c28 js 12,000 lines within 5 s" "$(timed "$TMP/c28a.js")" "6000 6000 6000"
{ printf '// '; head -c 200000 /dev/zero | tr '\0' 'x'; echo; } > "$TMP/c28b.js"
same "classify: c28 js one 200 kB line within 5 s" "$(timed "$TMP/c28b.js")" "0 0 1"

got=
for p in Dockerfile Dockerfile.prod Containerfile Containerfile.dev api.dockerfile Makefile GNUmakefile rules.mk x.blade.php a/b.c.ts Dockerfile.js Containerfile.ts Makefile.py LICENSE; do
  cd_lang "/w/$p"; got="$got$p=$cd_lang_key:$? "
done
same "classify: c29 cd_lang keys build files, Blade and the last extension" "$got" \
  "Dockerfile=dockerfile:0 Dockerfile.prod=dockerfile:0 Containerfile=dockerfile:0 Containerfile.dev=dockerfile:0 api.dockerfile=dockerfile:0 Makefile=make:0 GNUmakefile=make:0 rules.mk=make:0 x.blade.php=blade:0 a/b.c.ts=ts:0 Dockerfile.js=js:0 Containerfile.ts=ts:0 Makefile.py=py:0 LICENSE=:1 "

# ---- 0b. WHAT IS NOT PROSE: the first number of the triple -------------------------
gold "prose: p01 php typed @param, @return, @var and @throws lines with descriptions are not prose" php "0 7 1" <<'FIX'
<?php
/**
 * @param int $id the user id
 * @return Foo<Bar> the thing
 * @var string|null $n
 * @throws RuntimeException when down
 */
function f($id) {}
FIX
gold "prose: p02 js untyped described tags are prose" js "3 5 1" <<'FIX'
/**
 * @param id the user id
 * @return the user id
 * @throws when x
 */
function f(id) {}
FIX
gold "prose: p03 ts braced types, bare and one-operand tags and structural tags are not prose" ts "0 11 0" <<'FIX'
/**
 * @param {string} id the id
 * @returns {Promise<void>}
 * @deprecated
 * @see Foo
 * @template T
 * @extends Base<T> why
 * @method string name() x
 * @property int $x the x
 * @phpstan-return list<int> x
 */
FIX
gold "prose: p04 php a first operand that only resembles a type name is prose" php "1 8 0" <<'FIX'
/**
 * @return mixed x y
 * @param \App\User $u x
 * @param ?Foo $x x
 * @param array[] $r x
 * @return self for chaining
 * @return integerish value
 */
FIX
gold "prose: p05 js tool directives and a region marker are not prose" js "0 6 1" <<'FIX'
// eslint-disable-next-line x
// @ts-expect-error why
// prettier-ignore
/* istanbul ignore next */
// #region x
// noinspection X
const a = 1;
FIX
gold "prose: p06 py noqa after code is code; type: ignore, pragma and pylint lines are not prose" py "0 3 2" <<'FIX'
x = f()  # noqa
# type: ignore
# pragma: no cover
# pylint: disable=x
y = 1
FIX
gold "prose: p07 go go: counts only at the start of the body, so 'long ago:' is prose" go "1 4 1" <<'FIX'
//go:build linux
//go:generate x
//nolint:errcheck
// long ago: the API changed
package a
FIX
gold "prose: p08 sh a shellcheck directive is not prose" sh "0 2 1" <<'FIX'
#!/bin/sh
# shellcheck disable=SC2086
echo $x
FIX
gold "prose: p08 swift a MARK: line is not prose" swift "0 1 1" <<'FIX'
// MARK: - Lifecycle
let a = 1
FIX
gold "prose: p09 js a directive the list does not know is prose" js "1 1 0" <<'FIX'
// deno-lint-ignore no-explicit-any
FIX
gold "prose: p09 js a |-led line outside a block comment is prose" js "1 1 0" <<'FIX'
// | not a box
FIX
gold "prose: p10 js a first comment run holding 'All rights reserved' is not prose; a later licence line is" js "1 4 1" <<'FIX'
// Part of the build tooling.
// Do what you like with it.
// All rights reserved.
const a = 1;
// see the license file
FIX
gold "prose: p11 php an SPDX first block after the opening tag is not prose" php "0 5 1" <<'FIX'
<?php
/*
 * SPDX-License-Identifier: MIT
 * Redistribution permitted.
 */
$a = 1;
FIX
gold "prose: p12 js a licence sentence in the second comment run is prose" js "2 4 1" <<'FIX'
// why the module exists
const a = 1;
/*
 * This file is under the MIT license.
 */
FIX
gold "prose: p13 php a |-boxed config block is not prose" php "0 9 3" <<'FIX'
<?php
return [
    /*
    |-----
    | Application Name
    |-----
    |
    | This value is the name.
    |
    */
    'name' => 'x',
];
FIX
gold "prose: p14 py Args: and Returns: headings, :type: and :rtype: are not prose; :param: is" py "4 9 2" <<'FIX'
def f(x):
    """Double x.
    Args:
        x: the value.
    Returns:
        the doubled value.
    :param x: the value
    :type x: int
    :rtype: int
    """
    return x
FIX
gold "prose: p15 cs a lone XML doc tag is not prose; a tag with text is" cs "2 4 1" <<'FIX'
/// <summary>
/// Explains the handler.
/// </summary>
/// <param name="x">The x.</param>
void H(int x) {}
FIX
gold "prose: p16 js comment lines with no letter or digit are not prose" js "0 6 1" <<'FIX'
// -----
//
/*
 *
 * ===
 */
const a = 1;
FIX
gold "prose: p17 kt untyped described tags are prose" kt "2 4 1" <<'FIX'
/**
 * @param name the display name
 * @return the greeting
 */
fun greet(name: String) = "hi $name"
FIX
gold "prose: p17 java @throws with an exception class is not prose; an untyped @param is" java "1 4 0" <<'FIX'
/**
 * @throws IOException if the read fails
 * @param name the name
 */
FIX
alt=$(sed -n '/function exempt(/,/return 0/p' "$SCAN" | grep 'x ~ /' | sed -n '2p' | sed 's|^[^/]*/||; s|/) return 1.*$||')
same "prose: p18 the directive alternation of scan.sh's exempt() appears verbatim in paths.sh" \
  "${alt:+$(grep -cF -- "\"$alt\"" "$ROOT/plugins/code-review/hooks/paths.sh")}" 1

# ---- 0c. REVIEW: shapes a five-awk review found miscounted, and lists no case pinned -
each() { # $1 fixture file, then language keys -> "key=triple" per key
  local f="$1" k out=; shift
  for k in "$@"; do out="$out$k=$(cd_classify "$k" "$f") "; done
  printf '%s' "${out% }"
}
printf '// a%200000sb\n' '' > "$TMP/r01a.js"
same "review: 01 js a line comment holding 200,000 blanks within 5 s" "$(timed "$TMP/r01a.js")" "0 0 1"
printf '/*\n a%200000sb\n*/\n' '' > "$TMP/r01b.js"
same "review: 01 js a block comment line holding 200,000 blanks within 5 s" "$(timed "$TMP/r01b.js")" "0 0 3"
printf 'import os\ndef f(\n    a,%200000s\n):\n    """Doc."""\n    return 1\n' '' > "$TMP/r01c.py"
same "review: 01 py a def header holding 200,000 blanks within 5 s, its docstring still found" "$(timed "$TMP/r01c.py" py)" "1 1 5"

gold "review: 02 php lines outside <?php … ?> are code; a comment after re-entry counts" php "1 1 9" <<'FIX'
<?php $title = 'x'; ?>
<style>
#header { color: red; }
#footer,
#nav { margin: 0; }
* { box-sizing: border-box; }
</style>
<div id="header"><?= $title ?></div>
<?php require 'footer.php';
// why
FIX
gold "review: 03 ex #{ at line start is code" ex "1 1 5" <<'FIX'
# why
msg = """
#{name} did it
"""
x = "a
#{b} c"
FIX
cat > "$TMP/r04.rb" <<'FIX'
# why
text = <<~EOS
  # Heading
  #{name} said
  # frozen_string_literal: true
EOS
code = <<-RUBY
# comment in a generated file
RUBY
FIX
cat > "$TMP/r04.pl" <<'FIX'
# why
print <<~EOT;
  # not a comment
  EOT
my $x = <<"END";
# nor this
END
my $y = 1;
FIX
cat > "$TMP/r04.tf" <<'FIX'
# why
resource "aws_instance" "a" {
  user_data = <<-EOF
#!/bin/bash
# install things
#cloud-config
apt-get update
EOF
}
FIX
same "review: 04 heredoc bodies are code in rb, pl and tf" \
  "$(each "$TMP/r04.rb" rb) $(each "$TMP/r04.pl" pl) $(each "$TMP/r04.tf" tf)" "rb=1 1 8 pl=1 1 7 tf=1 1 8"
cat > "$TMP/r05.go" <<'FIX'
// why
package a
const tmpl = `
// Code generated. DO NOT EDIT.
/* x */
package {{.Pkg}}
`
var x = 1
FIX
cat > "$TMP/r05.kt" <<'FIX'
// why
val s = """
// not a comment
/* nor this */
"""
val x = 1
FIX
same "review: 05 a Go raw string and a \"\"\" block in kt kts java swift scala dart groovy are code" \
  "$(each "$TMP/r05.go" go) $(each "$TMP/r05.kt" kt kts java swift scala dart groovy)" \
  "go=1 1 7 kt=1 1 5 kts=1 1 5 java=1 1 5 swift=1 1 5 scala=1 1 5 dart=1 1 5 groovy=1 1 5"

gold "review: 06 js pragma and region count as whole words only" js "2 4 1" <<'FIX'
// A pragmatic choice: the retry is capped at three.
// Regional pricing applies after the tax step.
// pragma: no cover
// region Setup
const a = 1;
FIX
gold "review: 07 py a # inside a string in a def header does not hide the docstrings" py "2 2 5" <<'FIX'
import os
def color(c="#fff"):
    """Doc one."""
    return c
def other(x):
    """Doc two."""
    return x
FIX
gold "review: 08 sh <<!, a shift inside \$((, two heredocs on one line and a quoted terminator holding -" sh "1 1 13" <<'FIX'
cat <<!
# body bang
!
x=$(( 1 << SHIFT ))
# why
cat <<A <<B
# in A
A
# in B
B
cat <<'END-OF-FILE'
# in quoted
END-OF-FILE
echo done
FIX
cat > "$TMP/r09yard.rb" <<'FIX'
# @param name [String] the name
# @return [Integer] the count
# @raise [ArgumentError] when empty
def f(name); end
FIX
cat > "$TMP/r09.r" <<'FIX'
#' Title line
#' @param x the value
#' @export
f <- function(x) x
FIX
cat > "$TMP/r09.pl" <<'FIX'
=head1 NAME
tool - does a thing
=over 4
=item *
first point
=back
=cut
my $x = 1;
=pod extra
FIX
cat > "$TMP/r09begin.rb" <<'FIX'
=begin rdoc
why the module exists
=end
x = 1
FIX
same "review: 09 YARD [Type] tags, a roxygen tag, POD command lines and a =begin format name are not prose" \
  "yard:$(each "$TMP/r09yard.rb" rb) $(each "$TMP/r09.r" r) $(each "$TMP/r09.pl" pl) begin:$(each "$TMP/r09begin.rb" rb)" \
  "yard:rb=0 3 1 r=2 3 1 pl=2 7 2 begin:rb=1 3 1"
cat > "$TMP/r10.dockerfile" <<'FIX'
# syntax=docker/dockerfile:1
# escape=\
# check=skip=JSONArgsRecommended
# hadolint ignore=DL3008
FROM a
FIX
printf '%s\n' '# frozen_string_literal: true' 'x = 1' > "$TMP/r10.rb"
same "review: 10 Dockerfile parser directives, hadolint and frozen_string_literal are not prose" \
  "$(each "$TMP/r10.dockerfile" dockerfile) $(each "$TMP/r10.rb" rb)" "dockerfile=0 4 1 rb=0 1 1"
gold "review: 11 sql /*+ hints and /*! versioned comments are code; /* why */ is still prose" sql "1 1 4" <<'FIX'
SELECT
  /*+ INDEX(t idx) PARALLEL(4) */
  a FROM t;
/*!40101 SET @OLD_CS=@@CHARACTER_SET_CLIENT */;
/* why */
FIX

gold "review: keys svelte reads <!-- --> and //" svelte "2 2 2" <<'FIX'
<!-- why -->
<script>
// why
</script>
FIX
printf '%s\n' '# why' 'x = 1' > "$TMP/rk-hash.txt"
same "review: keys jl and r read #" "$(each "$TMP/rk-hash.txt" jl r)" "jl=1 1 1 r=1 1 1"
printf '%s\n' '// why' '/* why */' 'x = 1;' > "$TMP/rk-slash.txt"
same "review: keys mjs cjs kts scala dart h cpp hpp cc m mm groovy less read // and /* */" \
  "$(each "$TMP/rk-slash.txt" mjs cjs kts scala dart h cpp hpp cc m mm groovy less)" \
  "mjs=2 2 1 cjs=2 2 1 kts=2 2 1 scala=2 2 1 dart=2 2 1 h=2 2 1 cpp=2 2 1 hpp=2 2 1 cc=2 2 1 m=2 2 1 mm=2 2 1 groovy=2 2 1 less=2 2 1"
printf '%s\n' '{/* why */}' '<b />' > "$TMP/rk-jsx.txt"
same "review: keys js jsx ts read {/* */}" "$(each "$TMP/rk-jsx.txt" js jsx ts)" "js=1 1 1 jsx=1 1 1 ts=1 1 1"
printf '%s\n' '#!/bin/bash' '# why' 'cat <<EOF' '# body' 'EOF' 'echo ok' > "$TMP/rk-shell.txt"
same "review: keys bash zsh read # and keep a heredoc body as code" "$(each "$TMP/rk-shell.txt" bash zsh)" "bash=1 2 4 zsh=1 2 4"
gold "review: keys exs reads #, a @doc heredoc and #{ as code" exs "2 4 2" <<'FIX'
# why
@doc """
text
"""
#{x}
x = 1
FIX

gold "review: tags the structural list and the \$, backslash, ?, [ ] and type-name tests each decide a line" php "0 8 0" <<'FIX'
/**
 * @extends base_thing because why
 * @param mytype $x the description
 * @param \app\thing x the description
 * @param ?foo x y
 * @param string[] names the names
 * @return iterable x y
 */
FIX
printf '%s\n' '// Copyright 2024 Example' '// why the module exists' 'const a = 1;' > "$TMP/rl1.js"
printf '%s\n' '// spdx-short-id MIT' '// why the module exists' 'const a = 1;' > "$TMP/rl2.js"
printf '%s\n' '// MIT License' '// why the module exists' 'const a = 1;' > "$TMP/rl3.js"
same "review: licence copyright, spdx- and license each exempt a first run on their own" \
  "copyright:$(each "$TMP/rl1.js" js) spdx:$(each "$TMP/rl2.js" js) license:$(each "$TMP/rl3.js" js)" \
  "copyright:js=0 2 1 spdx:js=0 2 1 license:js=0 2 1"
printf 'def f(x):\n    """Double.\n    Args:   \n    """\n    return x\n' > "$TMP/r-args.py"
same "review: Args: followed by blanks is still a heading" "$(each "$TMP/r-args.py" py)" "py=1 3 2"

# ---- 0d. RED-TEAM: long lines, build-file names with a source extension, shape types, PHP tags ----
run() { head -c "${2:-2000000}" /dev/zero | tr '\0' "$1"; } # $1 byte, $2 count (default 2 MB)
{ run x; echo ' ?>'; } > "$TMP/rt-long1.php"
same "rt: php a 2 MB line ending in ?> is one code line, within 5 s" "$(timed "$TMP/rt-long1.php" php)" "0 0 1"
{ printf '// x'; run ' '; echo; } > "$TMP/rt-long2.js"
same "rt: js // x followed by 2 MB of blanks is one code line, within 5 s" "$(timed "$TMP/rt-long2.js")" "0 0 1"
{ run '"'; echo; } > "$TMP/rt-long3.py"
same "rt: py a 2 MB run of double quotes is one code line, within 5 s" "$(timed "$TMP/rt-long3.py" py)" "0 0 1"
{ run '`'; echo; } > "$TMP/rt-long4.go"
same "rt: go a 2 MB run of backquotes is one code line, within 5 s" "$(timed "$TMP/rt-long4.go" go)" "0 0 1"
{ printf 'def f'; run '('; echo; } > "$TMP/rt-long5.py"
same "rt: py def f followed by 2 MB of ( is one code line, within 5 s" "$(timed "$TMP/rt-long5.py" py)" "0 0 1"
{ printf '// '; run x 3997; echo; } > "$TMP/rt-edge-at.js"; { printf '// '; run x 3998; echo; } > "$TMP/rt-edge-over.js"
same "rt: js a comment line of 4,000 bytes is still read as prose, and one of 4,001 bytes is code" \
  "$(cd_classify js "$TMP/rt-edge-at.js" "$TMP/rt-edge-over.js" | tr '\n' ' ')" "1 1 0 0 0 1 "

{ echo 'class A {'; for i in $(seq 1 58); do echo "  #f$i = $i;"; done; echo '}'; } > "$TMP/rt-private.txt"
got=
for p in src/Dockerfile.js Containerfile.ts; do cd_lang "/w/$p"; got="$got$p=$(cd_classify "$cd_lang_key" "$TMP/rt-private.txt") "; done
same "rt: 60 lines of #private fields in src/Dockerfile.js and Containerfile.ts hold no comment line" "$got" \
  "src/Dockerfile.js=0 0 60 Containerfile.ts=0 0 60 "

gold "rt: php a tag typed with a shape or a callable signature is not prose, like the array<string, int> control" php "0 6 0" <<'FIX'
/**
 * @return array{id: int, name: string}
 * @param array{id: int, name: string} $row
 * @param callable(int): string $fn
 * @return array<string, int> the totals
 */
FIX
gold "rt: php the lines of a shape spanning lines are not prose, nested or under @phpstan-param too, and the line after its last brace is" php "2 14 0" <<'FIX'
/**
 * @return array{
 *   id: int,
 *   name: string,
 * }
 * the row as stored
 * @phpstan-param array{
 *   id: int,
 *   meta: array{
 *     tag: string,
 *   },
 * } $row
 * why the row is copied
 */
FIX
gold "rt: js a shape never closed ends at the next code line: the comment after it is prose" js "1 2 1" <<'FIX'
// @return array{
const a = 1;
// why the cache is warmed here
FIX
printf '%s\n' '// @return array{' > "$TMP/rt-open.js"; printf '%s\n' '// why the cache is warmed here' > "$TMP/rt-next.js"
same "rt: js a shape left open at the end of one operand does not reach the next: its comment is prose" \
  "$(cd_classify js "$TMP/rt-open.js" "$TMP/rt-next.js" | tr '\n' ' ')" "0 1 0 1 1 0 "
printf '<?php  \n// a\n// b\n// c\n// d\n// e\n?>\t\n<?\n' > "$TMP/rt-tags.php"
same "rt: php a file of comments and the tag-only lines <?php, ?> and <?, two of them followed by blanks, has no code line" \
  "$(cd_classify php "$TMP/rt-tags.php")" "5 8 0"
gold "rt: php declare(strict_types=1); is the only code line of a file that is otherwise comments" php "5 6 1" <<'FIX'
<?php
declare(strict_types=1);
// a
// b
// c
// d
// e
FIX
gold "rt: py an Emacs -*- line and vim: and vi: modelines are not prose; a line that only begins with decoding: is" py "1 5 1" <<'FIX'
# -*- coding: utf-8 -*-
# -*- mode: python; indent-tabs-mode: nil -*-
# vim: set fileencoding=utf-8 :
# vi: set ts=8 :
# decoding: the payload arrives base64
x = 1
FIX
gold "rt: c an expanded and an empty \$Id\$ keyword are not prose; a line that mentions \$Id later is" c "1 3 1" <<'FIX'
/* $Id$ */
// $Id: x.c,v 1.2 2020/01/01 user Exp $
// the $Id keyword is expanded on checkout
int a;
FIX
gold "rt: c an SCCS @(#) what-string is not prose; a line that mentions @(#) later is" c "1 3 1" <<'FIX'
/* @(#)x.c 8.1 (Berkeley) 6/2/93 */
// @(#)x.h 1.1
// what(1) prints the @(#) strings
int a;
FIX
gold "rt: rb :stopdoc:, :startdoc: and :nodoc: lines are not prose; a sentence naming :nodoc: is" rb "1 5 1" <<'FIX'
# :stopdoc:
# :startdoc:
# :nodoc:
# :nodoc: all
# the :nodoc: marker hides a method
x = 1
FIX
gold "rt: java {@inheritDoc} alone on a line is not prose; followed by text it is" java "1 7 3" <<'FIX'
/**
 * {@inheritDoc}
 */
void f() {}
/** {@inheritDoc} */
void g() {}
/**
 * {@inheritDoc} Also flushes the buffer.
 */
void h() {}
FIX

# ---- 0e. FIX 2: what a line over 4,000 bytes leaves behind, and directives in their whole shape ----
wide=$(run x 5000)
rest() { # $1 label, $2 language key, $3 expected triple; fixture on stdin
  cat > "$TMP/fix2.$2"; same "$1" "$(cd_classify "$2" "$TMP/fix2.$2")" "$3"
}
{ echo '/*!'; echo ' * why the bundle is vendored'; echo " */ var lib=\"$wide\";"; printf 'var a%s = 1;\n' $(seq 1 30); echo '/* end */'; } |
  rest "fix2: js a banner closed on a line over 4,000 bytes leaves the rest of the file code, never prose" js "0 0 34"
{ echo "<?php \$cfg = json_decode('$wide'); ?>"; printf '#item%s { color: red; }\n' $(seq 1 20); } |
  rest "fix2: php CSS after a ?> on a line over 4,000 bytes is code, never prose" php "0 0 21"
{ echo "TEMPLATE = \"\"\"$wide"; printf '# line %s of the template\n' $(seq 1 10); echo '"""'; echo 'x = 1'; } |
  rest "fix2: py a string opened on a line over 4,000 bytes leaves its # lines code" py "0 0 13"
{ echo 'package a'; echo "var data = \`$wide"; printf '// line %s\n' $(seq 1 10); echo '`'; echo 'var y = 1'; } |
  rest "fix2: go a raw string opened on a line over 4,000 bytes leaves its // lines code" go "0 0 14"
{ echo "X=\"$wide\"; cat <<EOF"; printf '# body %s\n' $(seq 1 10); echo 'EOF'; echo 'echo ok'; } |
  rest "fix2: sh a heredoc opened on a line over 4,000 bytes leaves its # lines code" sh "0 0 13"
{ echo "DATA = \"$wide\""; echo '"""'; printf 'text %s\n' $(seq 1 6); echo '"""'; } |
  rest "fix2: py a line over 4,000 bytes ends the module top: a string after it is no docstring" py "0 0 9"
{ echo '// Copyright 2026 Example'; echo "var big = \"$wide\";"; printf '// why %s\n' $(seq 1 6); echo 'var z = 1;'; } |
  rest "fix2: js a line over 4,000 bytes ends a licence run: the comments after it are prose" js "6 7 2"

got=
for spec in 'php||x| ?>' 'php|<?php |?|' 'js|// x| |' 'py||"|' 'go||`|' 'py|def f|(|'; do # key|head|filler byte|tail
  IFS='|' read -r key head pad tail <<< "$spec"
  printf '%s%s%s\n' "$head" "$(run "$pad" $((3999 - ${#head} - ${#tail})))" "$tail" | awk '{ for (n = 0; n < 500; n++) print }' > "$TMP/fix2-2mb"
  got="$got$key=$(timed "$TMP/fix2-2mb" "$key") "
done
same "fix2: 2 MB of 3,999-byte lines of each pathological shape is classified within 5 s" "$got" \
  "php=0 0 500 php=0 0 500 js=500 500 0 py=0 0 500 go=0 0 500 py=0 0 500 "

gold "fix2: php a { opens a shape only in the tag's type operand, after the alias name of a -type tag, and the shape ends with its block" php "3 11 1" <<'FIX'
/**
 * @param string $fmt the format, e.g. "{name"
 * why one
 * @phpstan-type Row array{
 *   id: int,
 * }
 * why two
 * @return array{
 *   id: int,
 */
// why three
$a = 1;
FIX
printf '<?PHP\n// a\n// b\n// c\n// d\n// e\n?>\n' > "$TMP/fix2-upper.php"; printf '# a\n# b\n<?PHP $x = 1;\n' > "$TMP/fix2-html.php"
same "fix2: php an open tag in capitals is an open tag: a comment-only file has no code line, and text before it is code" \
  "$(cd_classify php "$TMP/fix2-upper.php" "$TMP/fix2-html.php" | tr '\n' ' ')" "5 7 0 0 0 3 "
gold "fix2: rb sentences that begin with \$Id\$, vi:, @(#) or :nodoc:, or end in -*-, are prose" rb "5 5 1" <<'FIX'
# $Id$ is expanded by CVS on checkout
# vi: is the editor this file was tuned for
# @(#) strings are printed by what(1)
# :nodoc: hides this helper because it is internal
# the emacs header line ends with -*-
x = 1
FIX
printf '%s\n' '# encoding: utf-8' '# coding: utf-8' '# coding: utf-8' 'x = 1' > "$TMP/fix2-enc.rb"
printf '%s\n' '#!/usr/bin/env python3' '# coding=latin-1' 'x = 1' > "$TMP/fix2-enc.py"
printf '%s\n' '// clang-format off' '/* clang-format on */' '// clang-format runs in CI' 'int a;' > "$TMP/fix2-clang.c"
same "fix2: an encoding comment on line 1 or 2 of rb or py and a clang-format switch are not prose; the same encoding comment on line 3 is" \
  "$(each "$TMP/fix2-enc.rb" rb) $(each "$TMP/fix2-enc.py" py) $(each "$TMP/fix2-clang.c" c)" "rb=1 3 1 py=0 2 1 c=1 3 1"

command -v jq  >/dev/null 2>&1 || { echo "SKIP: jq not available";  exit "$rc"; }
command -v git >/dev/null 2>&1 || { echo "SKIP: git not available"; exit "$rc"; }

expect() { # $1 label, $2 out, $3 must-contain ('' = must be silent)
  local label="$1" out="$2" want="$3" ok=1
  if [ -n "$want" ]; then case "$out" in *"$want"*) ;; *) ok=0 ;; esac
  else [ -n "$out" ] && ok=0; fi
  if [ "$ok" -eq 1 ]; then echo "PASS: $label"; else echo "FAIL: $label — got: ${out:-<silent>}"; rc=1; fi
}

# ---- generators: N lines of body at a chosen comment:code ratio ----------------
house() { # $1 path — ~1:1, the house style
  { echo '<?php'; echo "class $(basename "$1" .php) {"
    for i in $(seq 1 30); do
      echo "    // why $i: the upstream API returns a bare id here, not an object"
      echo "    public function m$i(): int { return $i; }"
    done; echo '}'; } > "$1"
}
dense() { # $1 path — ~5:1, the shape the observed run produced
  { echo '<?php'; echo "class $(basename "$1" .php) {"
    for i in $(seq 1 30); do
      for j in 1 2 3 4 5; do echo "    // reasoning line $j for member $i, restating the design decision at length"; done
      echo "    public function m$i(): int { return $i; }"
    done; echo '}'; } > "$1"
}

lean() { # $1 path — ~0.1:1, a repo that comments almost nothing
  { echo '<?php'; echo "class $(basename "$1" .php) {"
    for i in $(seq 1 30); do
      [ $((i % 10)) -eq 0 ] && echo "    // why $i: the upstream API returns a bare id here, not an object"
      echo "    public function m$i(): int { return $i; }"
    done; echo '}'; } > "$1"
}
mid() { # $1 path — 20 prose / 43 code, 0.47:1: over the default ceiling; 5x a lean house
  { echo '<?php'; echo "class $(basename "$1" .php) {"
    for i in $(seq 1 40); do
      [ $((i % 2)) -eq 0 ] && echo "    // why $i: the upstream API returns a bare id here, not an object"
      echo "    public function m$i(): int { return $i; }"
    done; echo '}'; } > "$1"
}
calm() { # $1 path — 6 prose / 63 code: long enough for the ratio rule, under the default ceiling
  { echo '<?php'; echo "class $(basename "$1" .php) {"
    for i in $(seq 1 60); do
      [ $((i % 10)) -eq 0 ] && echo "    // why $i: the upstream API returns a bare id here, not an object"
      echo "    public function m$i(): int { return $i; }"
    done; echo '}'; } > "$1"
}

fire() { # $1 cwd, $2 file, $3 session, $4 tool (default Write)
  jq -n --arg fp "$2" --arg cwd "$1" --arg s "$3" --arg t "${4:-Write}" \
    '{hook_event_name:"PostToolUse",tool_name:$t,session_id:$s,cwd:$cwd,tool_input:{file_path:$fp}}' \
    | bash "$HOOK" 2>/dev/null | jq -r '.hookSpecificOutput.additionalContext // ""' 2>/dev/null
}
pre() { # $1 cwd, $2 file, $3 session, $4 content-file -> raw stdout
  jq -n --arg fp "$2" --arg cwd "$1" --arg s "$3" --rawfile c "$4" \
    '{hook_event_name:"PreToolUse",tool_name:"Write",session_id:$s,cwd:$cwd,tool_input:{file_path:$fp,content:$c}}' \
    | bash "$HOOK" 2>/dev/null
}

# ---- 1. dense file against COMMITTED house style ------------------------------
R="$TMP/r1"; mkdir -p "$R/app/Svc"
for n in A B C D; do house "$R/app/Svc/$n.php"; done
git -C "$R" init -q; git -C "$R" add -A
git -C "$R" -c user.email=t@t -c user.name=t commit -qm base
mkdir -p "$R/app/Svc/New/Deep"; dense "$R/app/Svc/New/Deep/Fat.php"
expect "dense file vs committed house style fires" "$(fire "$R" "$R/app/Svc/New/Deep/Fat.php" s1)" "comment-to-code"
expect "  …and the walk-up found the tracked baseline" "$(fire "$R" "$R/app/Svc/New/Deep/Fat.php" s1b)" "its siblings run"

# ---- 2. a house-style file: over the ceiling, matching its siblings ------------
# The 1:1 house style is what the observed run's repo looked like; the marketplace's
# default says that is too much, so the ceiling names itself, and switching the
# ceiling off restores the sibling-only verdict (silent).
house "$R/app/Svc/New/Deep/Normal.php"
expect "house-style file is over the ceiling (limit named)" \
  "$(fire "$R" "$R/app/Svc/New/Deep/Normal.php" s2)" "the limit here is 0.3:1"
expect "house-style file is silent with the ceiling off" \
  "$(COMMENT_DISCIPLINE_CEILING_TENTHS=0 fire "$R" "$R/app/Svc/New/Deep/Normal.php" s2b)" ""
expect "house-style file is silent under a 1:1 project override" \
  "$(COMMENT_DISCIPLINE_CEILING_TENTHS=10 fire "$R" "$R/app/Svc/New/Deep/Normal.php" s2c)" ""

# ---- 2b. the sibling test survives the ceiling: under 0.4, 3x a lean house -----
RL="$TMP/rl"; mkdir -p "$RL/app/Svc"
for n in A B C D; do lean "$RL/app/Svc/$n.php"; done
git -C "$RL" init -q; git -C "$RL" add -A
git -C "$RL" -c user.email=t@t -c user.name=t commit -qm base
mid "$RL/app/Svc/Mid.php"
expect "with the ceiling at 0.4, 5x lean siblings fires at the 0.3 floor" \
  "$(COMMENT_DISCIPLINE_CEILING_TENTHS=4 fire "$RL" "$RL/app/Svc/Mid.php" s2d)" "the limit here is 0.3:1"
lean "$RL/app/Svc/Lean.php"
expect "lean file in a lean repo is silent" "$(fire "$RL" "$RL/app/Svc/Lean.php" s2e)" ""

# ---- 3. THE REGRESSION THAT MATTERS: the run must not become its own baseline --
# Same dense file, but now every sibling in the new subtree is equally dense and
# untracked. Drawing the baseline from the working tree would find no outlier.
R2="$TMP/r2"; mkdir -p "$R2/app/Svc"
for n in A B C D; do house "$R2/app/Svc/$n.php"; done
git -C "$R2" init -q; git -C "$R2" add -A
git -C "$R2" -c user.email=t@t -c user.name=t commit -qm base
mkdir -p "$R2/app/Svc/New"; for n in F1 F2 F3 F4 F5; do dense "$R2/app/Svc/New/$n.php"; done
expect "uniformly dense NEW subtree still fires (baseline is tracked code)" \
  "$(fire "$R2" "$R2/app/Svc/New/F3.php" s3)" "comment-to-code"

# ---- 4. files this session already wrote are excluded from the baseline --------
S=s4
fire "$R2" "$R2/app/Svc/New/F1.php" "$S" >/dev/null
fire "$R2" "$R2/app/Svc/New/F2.php" "$S" >/dev/null
expect "a third dense file in the same session still fires" \
  "$(fire "$R2" "$R2/app/Svc/New/F4.php" "$S")" "comment-to-code"

# ---- 5. bounded: at most 3 warnings per session --------------------------------
expect "4th dense file in one session is silent (MAX_WARN)" \
  "$(fire "$R2" "$R2/app/Svc/New/F5.php" "$S")" ""

# ---- 6. same file twice in a session warns once --------------------------------
S6=s6
fire "$R2" "$R2/app/Svc/New/F1.php" "$S6" >/dev/null
expect "same file re-written in one session does not re-warn" \
  "$(fire "$R2" "$R2/app/Svc/New/F1.php" "$S6")" ""

# ---- 6b. THE SAME TWO BOUNDS, ON THE PAYLOAD THE HOST ACTUALLY SENDS ------------
# Cases 5 and 6 send session_id and nothing else, so they only ever exercised the
# FALLBACK branch of `.transcript_path // .session_id`. With transcript_path present —
# which is the normal case — the key is an absolute PATH, `density-$sid` named a nested
# file whose parents are never created, every state write failed, and MAX_WARN plus the
# per-file dedup both disengaged: the hook warned on every edit forever. Both bounds
# above stayed green throughout. Re-assert them with the real payload shape.
fire_tp() { # $1 cwd, $2 file — session_id AND a path-shaped transcript_path
  jq -n --arg fp "$2" --arg cwd "$1" \
    '{hook_event_name:"PostToolUse",tool_name:"Write",
      session_id:"11111111-2222-3333-4444-555555555555",
      transcript_path:"/Users/x/.claude/projects/-Users-x-proj/abcdef01-2345-6789.jsonl",
      cwd:$cwd,tool_input:{file_path:$fp}}' \
    | bash "$HOOK" 2>/dev/null | jq -r '.hookSpecificOutput.additionalContext // ""' 2>/dev/null
}
R2B="$TMP/r2b"; mkdir -p "$R2B/app/Svc"
for n in A B C D; do house "$R2B/app/Svc/$n.php"; done
git -C "$R2B" init -q; git -C "$R2B" add -A
git -C "$R2B" -c user.email=t@t -c user.name=t commit -qm base
mkdir -p "$R2B/app/Svc/New"; for n in G1 G2 G3 G4 G5; do dense "$R2B/app/Svc/New/$n.php"; done
expect "transcript_path: first dense file fires" \
  "$(fire_tp "$R2B" "$R2B/app/Svc/New/G1.php")" "comment-to-code"
expect "transcript_path: same file re-written does not re-warn (per-file dedup)" \
  "$(fire_tp "$R2B" "$R2B/app/Svc/New/G1.php")" ""
fire_tp "$R2B" "$R2B/app/Svc/New/G2.php" >/dev/null
fire_tp "$R2B" "$R2B/app/Svc/New/G3.php" >/dev/null
expect "transcript_path: 4th dense file is silent (MAX_WARN engages)" \
  "$(fire_tp "$R2B" "$R2B/app/Svc/New/G4.php")" ""
if [ -n "$(find "$R2B/.claude/comment-discipline" -name 'density-*' -type f 2>/dev/null)" ]
then echo "PASS: transcript_path: the state file actually landed on disk"
else echo "FAIL: transcript_path: the state file actually landed on disk — none under $R2B"; rc=1; fi

# ---- 7. too few tracked siblings -> the ceiling judges, never a guessed baseline -
R3="$TMP/r3"; mkdir -p "$R3/app"; git -C "$R3" init -q
dense "$R3/app/Only.php"
expect "no tracked baseline: the ceiling applies" "$(fire "$R3" "$R3/app/Only.php" s7)" "no committed siblings"
expect "no tracked baseline, ceiling off: silent" \
  "$(COMMENT_DISCIPLINE_CEILING_TENTHS=0 fire "$R3" "$R3/app/Only.php" s7b)" ""
lean "$R3/app/Lean.php"
expect "no tracked baseline, lean file: silent" "$(fire "$R3" "$R3/app/Lean.php" s7c)" ""

# ---- 7b. PreToolUse lane: a whole Write over the ceiling is denied ONCE per file -
R4="$TMP/r4"; mkdir -p "$R4/app"; git -C "$R4" init -q
dense "$TMP/dense.txt"; house "$TMP/house.txt"; lean "$TMP/lean.txt"
denied() { printf '%s' "$1" | jq -e '.hookSpecificOutput.permissionDecision == "deny"' >/dev/null 2>&1; }
out=$(pre "$R4" "$R4/app/Fat.php" p1 "$TMP/dense.txt")
denied "$out" && echo "PASS: PreToolUse denies a dense Write" || { echo "FAIL: PreToolUse denies a dense Write — got: ${out:-<silent>}"; rc=1; }
expect "  …and the reason names the ceiling" "$(printf '%s' "$out" | jq -r '.hookSpecificOutput.permissionDecisionReason // ""')" "the ceiling is 0.3:1"
# The bound is TWO denies, not one (2026-09-15): a sibling PreToolUse hook denying the
# same call blocks the write too, so a one-shot spent on attempt 1 left the next write
# of that file unchecked. Attempt 2 denies; attempt 3 is silent, which bounds the session.
out=$(pre "$R4" "$R4/app/Fat.php" p1 "$TMP/dense.txt")
denied "$out" && echo "PASS: bound is TWO denies: the same file again still denies" || { echo "FAIL: second dense Write should deny — got: ${out:-<silent>}"; rc=1; }
expect "bound is TWO denies: the same file a third time is allowed" "$(pre "$R4" "$R4/app/Fat.php" p1 "$TMP/dense.txt")" ""
out=$(pre "$R4" "$R4/app/Other.php" p1 "$TMP/house.txt")
denied "$out" && echo "PASS: the bound is per FILE: a 1:1 Write to a new file still denies" || { echo "FAIL: per-file bound — got: ${out:-<silent>}"; rc=1; }
expect "lean Write is allowed" "$(pre "$R4" "$R4/app/Lean.php" p1 "$TMP/lean.txt")" ""
expect "ceiling off: dense Write is allowed" "$(COMMENT_DISCIPLINE_CEILING_TENTHS=0 pre "$R4" "$R4/app/Fat2.php" p2 "$TMP/dense.txt")" ""
out=$(jq -n --arg fp "$R4/app/Fat3.php" --arg cwd "$R4" --rawfile c "$TMP/dense.txt" \
  '{hook_event_name:"PreToolUse",tool_name:"Edit",session_id:"p3",cwd:$cwd,tool_input:{file_path:$fp,new_string:$c}}' | bash "$HOOK" 2>/dev/null)
expect "PreToolUse ignores an Edit (a fragment has no file ratio)" "$out" ""
printf '// @generated by tool — do not edit\n%s' "$(cat "$TMP/dense.txt")" > "$TMP/gen.txt"
expect "generated header exempts the Write" "$(pre "$R4" "$R4/app/Gen.php" p4 "$TMP/gen.txt")" ""
{ head -20 "$TMP/dense.txt"; echo '}'; } > "$TMP/short.txt"
expect "15 prose / 5 code is refused by the short rule" "$(pre "$R4" "$R4/app/Short.php" p5 "$TMP/short.txt")" \
  "(15 comment lines, 5 code); the ceiling is 1.0:1"
out=$(jq -n --arg fp "$R4/app/Fat4.php" --rawfile c "$TMP/dense.txt" \
  '{hook_event_name:"PreToolUse",tool_name:"Write",session_id:"p6",tool_input:{file_path:$fp,content:$c}}' | bash "$HOOK" 2>/dev/null)
expect "missing cwd withholds the deny (bound cannot be recorded)" "$out" ""

# ---- 8. WORKTREE SCOPING (paths.sh), both hooks ---------------------------------
WT="$R/.claude/worktrees/feature-x"; mkdir -p "$WT/app/Svc/New" "$WT/.claude"
cp -R "$R/app/Svc/A.php" "$R/app/Svc/B.php" "$R/app/Svc/C.php" "$R/app/Svc/D.php" "$WT/app/Svc/"
git -C "$WT" init -q; git -C "$WT" add -A
git -C "$WT" -c user.email=t@t -c user.name=t commit -qm base
dense "$WT/app/Svc/New/Fat.php"
expect "density: file inside .claude/worktrees IS measured" \
  "$(fire "$WT" "$WT/app/Svc/New/Fat.php" s8)" "comment-to-code"

NOISY='// increment the counter
$counter++;'
scan() { # $1 path
  jq -n --arg fp "$1" --arg c "$WT" --arg x "$NOISY" \
    '{hook_event_name:"PostToolUse",tool_name:"Write",session_id:"s9",cwd:$c,tool_input:{file_path:$fp,content:$x}}' \
    | bash "$SCAN" 2>/dev/null | jq -r '.hookSpecificOutput.additionalContext // ""' 2>/dev/null
}
expect "scan: file inside .claude/worktrees IS scanned" "$(scan "$WT/app/Svc/New/w.php")" "comment-discipline:"
expect "scan: .claude/ INSIDE a worktree is still exempt" "$(scan "$WT/.claude/w.php")" ""
expect "scan: .claude/ in the main tree is still exempt"  "$(scan "$R/.claude/w.php")"  ""
expect "scan: vendored path is still exempt" "$(scan "$WT/vendor/x/w.php")" ""

# ---- 9. fail-open: no paths.sh, and a missing file ------------------------------
NOLIB="$TMP/nolib"; mkdir -p "$NOLIB"
cp "$HOOK" "$SCAN" "$NOLIB/"
out=$(jq -n --arg fp "$R2/app/Svc/New/F1.php" --arg cwd "$R2" \
  '{hook_event_name:"PostToolUse",tool_name:"Write",session_id:"s10",cwd:$cwd,tool_input:{file_path:$fp}}' \
  | bash "$NOLIB/density.sh" 2>/dev/null); e=$?
[ "$e" -eq 0 ] && echo "PASS: density exits 0 without paths.sh" || { echo "FAIL: density exit $e without paths.sh"; rc=1; }
out=$(printf '{"hook_event_name":"PostToolUse","tool_name":"Write","session_id":"s11","cwd":"%s","tool_input":{"file_path":"%s/nope.php"}}' "$R2" "$R2" \
  | bash "$HOOK" 2>/dev/null); e=$?
[ "$e" -eq 0 ] && [ -z "$out" ] && echo "PASS: missing file is silent, exit 0" || { echo "FAIL: missing file (exit $e, out '$out')"; rc=1; }
out=$(printf '' | bash "$HOOK" 2>/dev/null); e=$?
[ "$e" -eq 0 ] && echo "PASS: empty stdin exits 0" || { echo "FAIL: empty stdin exit $e"; rc=1; }

# ---- 10. PATH SCOPING AND THE GENERATED PROBE (paths.sh) ------------------------
# Non-git roots: the marketplace test is a file at the state root, here the payload cwd.
PI="$TMP/inst"; PM="$TMP/mkt"; mkdir -p "$PI" "$PM/.claude-plugin"; : > "$PM/.claude-plugin/marketplace.json"
DENY='"permissionDecision":"deny"'
expect "paths: installer src/templates/EmailTemplate.tsx is judged" \
  "$(pre "$PI" "$PI/src/templates/EmailTemplate.tsx" q1 "$TMP/dense.txt")" "$DENY"
expect "paths: installer wp-content/plugins/shop/hooks/cart.php is judged" \
  "$(pre "$PI" "$PI/wp-content/plugins/shop/hooks/cart.php" q2 "$TMP/dense.txt")" "$DENY"
expect "paths: marketplace templates/x.js is exempt" \
  "$(pre "$PM" "$PM/templates/x.js" q3 "$TMP/dense.txt")" ""
expect "paths: marketplace plugins/x/hooks/h.php is exempt" \
  "$(pre "$PM" "$PM/plugins/x/hooks/h.php" q4 "$TMP/dense.txt")" ""
expect "paths: migrations are judged in an installer root" \
  "$(pre "$PI" "$PI/database/migrations/2026_10_01_create_users.php" q5 "$TMP/dense.txt")" "$DENY"
expect "paths: migrations are judged in a marketplace root" \
  "$(pre "$PM" "$PM/database/migrations/2026_10_01_create_users.php" q6 "$TMP/dense.txt")" "$DENY"
expect "paths: build/app.js at the root is exempt" \
  "$(pre "$PI" "$PI/build/app.js" q7 "$TMP/dense.txt")" ""
expect "paths: packages/build/index.ts is judged" \
  "$(pre "$PI" "$PI/packages/build/index.ts" q8 "$TMP/dense.txt")" "$DENY"
expect "paths: build/ inside a worktree is exempt" \
  "$(pre "$PI" "$PI/.claude/worktrees/b/build/x.js" q9 "$TMP/dense.txt")" ""

out=$(HOOK="$NOLIB/density.sh" pre "$PI" "$PI/app/NoLib.php" q10 "$TMP/dense.txt"); e=$?
[ "$e" -eq 0 ] && [ -z "$out" ] && echo "PASS: paths: a dense Write with paths.sh absent exits 0, silent" \
  || { echo "FAIL: paths: a dense Write with paths.sh absent (exit $e, out '$out')"; rc=1; }
expect "paths: missing cwd on PostToolUse stays silent" "$(fire "$TMP/gone" "$R3/app/Only.php" q11)" ""

gen() { # $1 session and file stem, $2 header -> pre() output for the header above a dense body
  { printf '%s\n' "$2"; cat "$TMP/dense.txt"; } > "$TMP/gen-$1.txt"
  pre "$PI" "$PI/app/$1.php" "$1" "$TMP/gen-$1.txt"
}
expect "paths: generated marker: a sentence that mentions a generator is judged" \
  "$(gen g1 '// This is not generated by a tool')" "$DENY"
expect "paths: generated marker: @generated exempts" "$(gen g2 '// @generated by tool — do not edit')" ""
expect "paths: generated marker: Code generated by … DO NOT EDIT exempts" \
  "$(gen g3 '// Code generated by protoc. DO NOT EDIT.')" ""
expect "paths: generated marker: <auto-generated> exempts" "$(gen g4 '// <auto-generated>')" ""
expect "paths: generated marker: a docblock line This file was auto-generated exempts" "$(gen g5 '/**
 * This file was auto-generated by openapi-typescript.
 */')" ""
expect "paths: generated marker: This file was automatically generated exempts" \
  "$(gen g6 '// This file was automatically generated by json-schema-to-typescript.')" ""
expect "paths: generated marker: GENERATED CODE - DO NOT MODIFY exempts" \
  "$(gen g7 '// GENERATED CODE - DO NOT MODIFY BY HAND')" ""

# cwd != root: the cases above post from the root itself, so a hook handing the classifier
# the payload cwd would pass them all.
PG="$TMP/gitroot"; mkdir -p "$PG/packages"; git -C "$PG" init -q
expect "probe: from cwd <root>/packages, packages/build/index.ts is judged against the git root" \
  "$(pre "$PG/packages" "$PG/packages/build/index.ts" qg1 "$TMP/dense.txt")" "$DENY"

# ---- 11. BASH LANE: heredocs before the write, targets on disk after it ----------
BW="$TMP/bw"; mkdir -p "$BW/src"
for i in $(seq 1 20); do
  printf '// why %s: one\n// why %s: two\n// why %s: three\nfunction f%s() { return %s; }\n' "$i" "$i" "$i" "$i" "$i"
done > "$TMP/d6020.txt"   # 60 comment lines, 20 code
SUFFIX=' Written by a Bash command:'
bash_hook() { # $1 event, $2 cwd, $3 session, $4 command -> raw stdout
  jq -n --arg e "$1" --arg cwd "$2" --arg s "$3" --arg c "$4" \
    '{hook_event_name:$e,tool_name:"Bash",session_id:$s,cwd:$cwd,tool_input:{command:$c}}' \
    | bash "$HOOK" 2>/dev/null
}
heredoc() { # $1 writer, $2 body file (default d6020.txt), $3 terminator (default EOF)
  printf "%s <<'%s'\n%s\n%s\n" "$1" "${3:-EOF}" "$(cat "${2:-$TMP/d6020.txt}")" "${3:-EOF}"
}
reason_of() { printf '%s' "$1" | jq -r '.hookSpecificOutput.permissionDecisionReason // ""' 2>/dev/null; }
verdict() { # $1 status of the test before it, $2 label, $3 detail
  if [ "$1" -eq 0 ]; then echo "PASS: $2"; else echo "FAIL: $2 — $3"; rc=1; fi
}

w_reason=$(reason_of "$(pre "$BW" "$BW/src/Fat.js" bw1 "$TMP/d6020.txt")")
b_reason=$(reason_of "$(bash_hook PreToolUse "$BW" bb1 "$(heredoc 'cat > src/Fat.js')")")
case "$w_reason" in *"(60 comment lines, 20 code)"*) [ "$b_reason" = "$w_reason$SUFFIX Fat.js." ] ;; *) false ;; esac
verdict $? "bash: a truncating cat heredoc of 60 comment / 20 code lines is denied with the Write reason plus the file suffix" \
  "write=[$w_reason] bash=[$b_reason]"
D2="$TMP/bw2"; mkdir -p "$D2/src"
out=$(bash_hook PreToolUse "$D2" bb2 "$(heredoc 'cat >> src/Fat.js')")
[ -z "$out" ] && [ ! -e "$D2/.claude" ]
verdict $? "bash: the same text appended with >> is not denied pre-write and leaves no state dir" \
  "out=[$out] state=[$(ls -A "$D2/.claude" 2>/dev/null)]"
expect "bash: tee -a is an append, not denied pre-write" \
  "$(bash_hook PreToolUse "$BW" bb3 "$(heredoc 'tee -a src/Fat.js')")" ""
expect "bash: a heredoc fed to a writer that is not cat or tee is silent" \
  "$(bash_hook PreToolUse "$BW" bb4 "$(heredoc 'python3 - > src/Fat.js')")" ""
expect "bash: a command that writes nothing is silent on PreToolUse" \
  "$(bash_hook PreToolUse "$BW" bb5 'ls -la && git status')" ""

D6="$TMP/bw6"; mkdir -p "$D6/src"; cp "$TMP/d6020.txt" "$D6/src/Disk.js"
w_warn=$(fire "$D6" "$D6/src/Disk.js" bw6)
b_warn=$(bash_hook PostToolUse "$D6" bb6 "echo '// tail' >> src/Disk.js" | jq -r '.hookSpecificOutput.additionalContext // ""' 2>/dev/null)
[ -n "$w_warn" ] && [ "$b_warn" = "$w_warn$SUFFIX Disk.js." ]
verdict $? "bash: PostToolUse warns for a target on disk with the Write warning plus the file suffix" \
  "write=[$w_warn] bash=[$b_warn]"

D7="$TMP/bw7"; mkdir -p "$D7/src"; for k in 1 2 3 4; do calm "$D7/src/T$k.php"; done
bash_hook PostToolUse "$D7" bb7 \
  'echo 1 >> src/T1.php; echo 2 >> src/T2.php; echo 3 >> src/T3.php; echo 4 >> src/T4.php' >/dev/null
st=$(cat "$D7"/.claude/comment-discipline/density-* 2>/dev/null)
case "$st" in *"/src/T3.php"*) case "$st" in *"/src/T4.php"*) false ;; *) true ;; esac ;; *) false ;; esac
verdict $? "bash: PostToolUse measures three targets: the 4th target's name is absent from the state file" "state=[$st]"

D8="$TMP/bw8"; mkdir -p "$D8/src"
{ echo '// Code generated by protoc. DO NOT EDIT.'; cat "$TMP/d6020.txt"; } > "$D8/src/api.js"
expect "bash: a generated marker on disk silences the PostToolUse warning" \
  "$(bash_hook PostToolUse "$D8" bb8 'protoc --js_out=. api.proto > src/api.js')" ""
expect "bash: a command that writes nothing is silent on PostToolUse" \
  "$(bash_hook PostToolUse "$BW" bb9 'ls -la && git status')" ""

w1=$(pre "$BW" "$BW/src/S1.js" sb1 "$TMP/d6020.txt"); w2=$(pre "$BW" "$BW/src/S1.js" sb1 "$TMP/d6020.txt")
b3=$(bash_hook PreToolUse "$BW" sb1 "$(heredoc 'cat > src/S1.js')")
denied "$w1" && denied "$w2" && [ -z "$b3" ]
verdict $? "bash: two Write denies spend the budget of a relative heredoc to that file" \
  "write1=[$w1] write2=[$w2] bash=[$b3] (want deny, deny, silence)"
b1=$(bash_hook PreToolUse "$BW" sb2 "$(heredoc 'cat > src/S2.js')"); b2=$(bash_hook PreToolUse "$BW" sb2 "$(heredoc 'cat > src/S2.js')")
w3=$(pre "$BW" "$BW/src/S2.js" sb2 "$TMP/d6020.txt")
denied "$b1" && denied "$b2" && [ -z "$w3" ]
verdict $? "bash: two heredoc denies spend the budget of a Write to that file" \
  "bash1=[$b1] bash2=[$b2] write=[$w3] (want deny, deny, silence)"

# A payload piped to the script cannot prove the matcher, so this one reads the manifest.
jq -e '[.hooks[][] | select(any(.hooks[]; .command | test("/(scan|density)\\.sh")))
        | .matcher // "" | test("(^|\\|)Bash(\\||$)")] | length > 0 and all' \
  "$ROOT/plugins/code-review/hooks/hooks.json" >/dev/null 2>&1
verdict $? "wiring: every hooks.json entry that runs scan.sh or density.sh matches Bash" \
  "$(jq -c '[.hooks[][] | {matcher, run: [.hooks[].command]}]' "$ROOT/plugins/code-review/hooks/hooks.json" 2>&1)"

# ---- 12. BASH LANE: more than one chunk or target in a command --------------------
DM="$TMP/bwm"; mkdir -p "$DM/src"
one_json() { [ "$(printf '%s' "$1" | jq -s 'length' 2>/dev/null)" = 1 ]; }
names() { case "$(reason_of "$1")" in *"$SUFFIX $2.") ;; *) false ;; esac; } # $1 hook output, $2 file the suffix must name
for i in $(seq 1 30); do echo "function g$i() { return $i; }"; done > "$TMP/thin.txt"
{ for i in $(seq 1 40); do echo "// why $i: the upstream API returns a bare id here"; done
  for i in $(seq 1 15); do echo "function h$i() { return $i; }"; done; } > "$TMP/top.txt"   # 40 comment, 15 code
for i in $(seq 1 200); do echo "function t$i() { return $i; }"; done > "$TMP/tail.txt"

out=$(bash_hook PreToolUse "$DM" m1 "$(heredoc 'cat > src/thin.js' "$TMP/thin.txt"; heredoc 'cat > src/fat.js')")
one_json "$out" && denied "$out" && names "$out" fat.js
verdict $? "multi: a thin first heredoc and a dense second draw one deny naming the second file" "out=[$out]"

D9="$TMP/bw9"; mkdir -p "$D9/src"; cp "$TMP/d6020.txt" "$D9/src/c.js"; cp "$TMP/d6020.txt" "$D9/src/d.js"
out=$(bash_hook PostToolUse "$D9" m2 'echo x >> src/c.js; echo y >> src/d.js')
rows=$(cat "$D9"/.claude/comment-discipline/density-* 2>/dev/null | grep -c '^warn ')
one_json "$out" && [ "$rows" = 1 ]
verdict $? "multi: two over-limit targets on disk draw one JSON object and one warn row in the state file" \
  "warn rows=$rows out=[$out]"

# The dense file sits where the target would resolve if the cd were ignored.
DC="$TMP/bwc"; mkdir -p "$DC/src"; cp "$TMP/d6020.txt" "$DC/x.js"
out=$(bash_hook PostToolUse "$DC" m3 'cd src && echo y >> x.js')
[ -z "$out" ] && ! grep -q 'x\.js' "$DC"/.claude/comment-discipline/density-* 2>/dev/null
verdict $? "multi: a relative target after an in-command cd is not measured on the disk lane" "out=[$out]"

expect "multi: a truncating heredoc followed by an append to the same file is not denied pre-write" \
  "$(bash_hook PreToolUse "$DM" m4 "$(heredoc 'cat > src/a.js' "$TMP/top.txt" A; heredoc 'cat >> src/a.js' "$TMP/tail.txt" B)")" ""

out=$(bash_hook PreToolUse "$DM" m5 "$(heredoc 'tee src/T.js')")
one_json "$out" && denied "$out" && names "$out" T.js
verdict $? "multi: a truncating tee heredoc is denied" "out=[$out]"

out=$(HOOK="$NOLIB/density.sh" bash_hook PreToolUse "$D6" m6 "$(heredoc 'cat > src/Disk.js')"); e=$?
out2=$(HOOK="$NOLIB/density.sh" bash_hook PostToolUse "$D6" m6 "$(heredoc 'cat > src/Disk.js')"); e2=$?
[ "$e" -eq 0 ] && [ -z "$out" ] && [ "$e2" -eq 0 ] && [ -z "$out2" ]
verdict $? "multi: with paths.sh absent a dense cat heredoc exits 0 with no output on both events" \
  "PreToolUse exit $e [$out] PostToolUse exit $e2 [$out2]"

# ---- 13. RED-TEAM: a wrong file and a false deny on the Bash lane -------------------
DR="$TMP/rt"; mkdir -p "$DR/src" "$DR/sub"; cp "$TMP/d6020.txt" "$DR/big.js"
expect "redteam: with a dense big.js in the payload cwd, a heredoc to big.js after \`if cd sub; then\` draws no warning" \
  "$(bash_hook PostToolUse "$DR" rt1 'if cd sub; then
cat > big.js <<EOF
const a = 1;
EOF
fi')" ""
expect "redteam: a dense truncating heredoc followed by cat src/body.js >> src/qb.js is not denied pre-write" \
  "$(bash_hook PreToolUse "$DR" rt2 "$(heredoc 'cat > src/qb.js')
cat src/body.js >> src/qb.js")" ""
expect "redteam: a dense heredoc under cat <<EOF | tee src/h.js -a is not denied" \
  "$(bash_hook PreToolUse "$DR" rt3 "$(printf "cat <<'EOF' | tee src/h.js -a\n%s\nEOF" "$(cat "$TMP/d6020.txt")")")" ""
expect "redteam: a dense heredoc under cat src/other.js > src/a.js is not denied" \
  "$(bash_hook PreToolUse "$DR" rt4 "$(heredoc 'cat src/other.js > src/a.js')")" ""
b1=$(bash_hook PreToolUse "$DR" rt5 "$(heredoc 'cat > src/f.js')"); b2=$(bash_hook PreToolUse "$DR" rt5 "$(heredoc 'cat > src/f.js')")
b3=$(bash_hook PreToolUse "$DR" rt5 "$(heredoc 'cat > src//f.js')")
denied "$b1" && denied "$b2" && [ -z "$b3" ]
verdict $? "redteam: after two denies on src/f.js a dense heredoc to src//f.js passes" \
  "bash1=[$b1] bash2=[$b2] bash3=[$b3] (want deny, deny, silence)"

# ---- 14. RE-TEST: counting a command's writes once ----------------------------------
many=$(for i in $(seq 1 120); do printf "cat > src/f%s.js <<'EOF'\nconst a%s = 1;\nEOF\n" "$i" "$i"; done)
t0=$SECONDS; out=$(bash_hook PreToolUse "$DR" rq1 "$many"); took=$((SECONDS - t0))
[ "$took" -le 5 ] && [ -z "$out" ]
verdict $? "retest: 120 one-line heredocs to distinct files return within 5 s" "took $took s, out=[$out]"
out=$(bash_hook PreToolUse "$DR" rq2 "$(heredoc 'cat > src/x.js')
echo x > src/other.js")
denied "$out" && names "$out" x.js
verdict $? "retest: a dense truncating heredoc is still denied when a different file is also written" "out=[$out]"

# ---- 15. THE RULE: exact compare, the short rule and the printed numbers, on every lane ----
RD="$TMP/rule"; mkdir -p "$RD/src"
mix() { # $1 prose lines, $2 code lines -> JavaScript on stdout
  local i=0
  while [ "$i" -lt "$1" ]; do i=$((i + 1)); echo "// why $i: the upstream API returns a bare id here"; done
  i=0
  while [ "$i" -lt "$2" ]; do i=$((i + 1)); echo "function f$i() { return $i; }"; done
}
wr() { # $1 prose, $2 code -> the hook's reply to a Write of that mix; one session per mix and ceiling
  mix "$1" "$2" > "$TMP/mix-$1-$2.txt"
  pre "$RD" "$RD/src/m$1x$2.js" "w-$1-$2-${COMMENT_DISCIPLINE_CEILING_TENTHS:-default}" "$TMP/mix-$1-$2.txt"
}

expect "rule: 30 prose / 100 code passes at the default" "$(wr 30 100)" ""
expect "rule: 31 prose / 100 code is refused at the default" "$(wr 31 100)" "$DENY"
expect "rule: with the ceiling at 0.4, 40 prose / 100 code passes" "$(COMMENT_DISCIPLINE_CEILING_TENTHS=4 wr 40 100)" ""
expect "rule: with the ceiling at 0.4, 41 prose / 100 code is refused" "$(COMMENT_DISCIPLINE_CEILING_TENTHS=4 wr 41 100)" "$DENY"

out=$(wr 5 4)
denied "$out"
verdict $? "rule: a short Write with 5 prose / 4 code is refused" "out=[$out]"
expect "rule: …and its reason names the short limit, 1.0:1" "$(reason_of "$out")" "(5 comment lines, 4 code); the ceiling is 1.0:1"
expect "rule: 5 prose / 5 code passes, and 10 / 20 too: under 50 lines only more prose than code is refused" "$(wr 5 5)$(wr 10 20)" ""
expect "rule: 4 prose / 1 code passes: under five prose lines" "$(wr 4 1)" ""
expect "rule: 5 prose / 0 code passes: a file with no code line is a document" "$(wr 5 0)" ""
expect "rule: 44 prose / 5 code, 49 lines, is refused by the short rule" "$(wr 44 5)" "(44 comment lines, 5 code); the ceiling is 1.0:1"
expect "rule: 45 prose / 5 code, 50 lines but under 8 code, is refused by the short rule too" "$(wr 45 5)" \
  "(45 comment lines, 5 code); the ceiling is 1.0:1"
expect "rule: with the ceiling at 2.0, 12 prose / 7 code passes" "$(COMMENT_DISCIPLINE_CEILING_TENTHS=20 wr 12 7)" ""
expect "rule: with the ceiling at 2.0, 15 prose / 7 code is refused at 2.0:1" "$(COMMENT_DISCIPLINE_CEILING_TENTHS=20 wr 15 7)" \
  "(15 comment lines, 7 code); the ceiling is 2.0:1"

RS="$TMP/rule-short"; mkdir -p "$RS/src"; mix 5 4 > "$RS/src/short.js"
z54=$(COMMENT_DISCIPLINE_CEILING_TENTHS=0 wr 5 4); z21=$(COMMENT_DISCIPLINE_CEILING_TENTHS=0 wr 21 100)
zdisk=$(COMMENT_DISCIPLINE_CEILING_TENTHS=0 fire "$RS" "$RS/src/short.js" z0 Edit)
[ -z "$z54$z21$zdisk" ]
verdict $? "rule: with the ceiling at 0, Writes of 5 / 4 and 21 / 100 pass and the 5 / 4 file on disk draws no warning" \
  "5/4=[$z54] 21/100=[$z21] on disk=[$zdisk]"
mix 5 5 > "$RS/src/short.js"; w_under=$(fire "$RS" "$RS/src/short.js" e1 Edit)
mix 5 4 > "$RS/src/short.js"; w_alone=$(fire "$RS" "$RS/src/short.js" e1 Edit)
{ echo '<?php'; mix 5 4; } > "$RL/app/Svc/Short.php"
w_sibs=$(fire "$RL" "$RL/app/Svc/Short.php" e2 Edit)
[ -z "$w_under" ] && case "$w_alone" in *"(5 comment lines, 4 code); no committed siblings to compare against, so the ceiling of 1.0:1 applies."*)
  case "$w_sibs" in *"(5 comment lines, 4 code); its siblings run 0.1:1 and the limit here is 1.0:1."*) true ;; *) false ;; esac ;;
  *) false ;; esac
verdict $? "rule: after an Edit the short file on disk is silent at 5 / 5 and, in that session, warns at 5 / 4 with the 1.0:1 limit, alone and among committed siblings" \
  "5/5=[$w_under] alone=[$w_alone] siblings=[$w_sibs]"
out=$(bash_hook PreToolUse "$RD" h54 "$(heredoc 'cat > src/short.js' "$RS/src/short.js")")
denied "$out" && names "$out" short.js && case "$(reason_of "$out")" in *"the ceiling is 1.0:1"*) true ;; *) false ;; esac
verdict $? "rule: a truncating heredoc of the 5 / 4 file is refused at 1.0:1" "out=[$out]"

expect "rule: 35 prose / 100 code prints its ratio rounded up, 0.4:1 against the 0.3:1 ceiling" "$(reason_of "$(wr 35 100)")" \
  "would be 0.4:1 comment-to-code (35 comment lines, 100 code); the ceiling is 0.3:1"
expect "rule: the refusal names COMMENT_DISCIPLINE_CEILING_TENTHS for a heavier house style, ahead of its unchanged bound" "$(reason_of "$(wr 36 100)")" \
  "sets COMMENT_DISCIPLINE_CEILING_TENTHS in its settings env (5 for 0.5:1). Blocked at most twice per file;"

mix 31 100 > "$TMP/m31.txt"
out=$(bash_hook PreToolUse "$RD" h31 "$(heredoc 'cat > src/h31.js' "$TMP/m31.txt")")
denied "$out" && names "$out" h31.js && case "$(reason_of "$out")" in *"(31 comment lines, 100 code); the ceiling is 0.3:1"*) true ;; *) false ;; esac
verdict $? "rule: a truncating heredoc of 31 prose / 100 code is refused at the default" "out=[$out]"
RT="$TMP/rule-disk"; mkdir -p "$RT/src"; cp "$TMP/m31.txt" "$RT/src/d31.js"
expect "rule: a Bash target on disk at 31 prose / 100 code draws the warning at the default" \
  "$(bash_hook PostToolUse "$RT" t31 'echo x >> src/d31.js')" \
  "(31 comment lines, 100 code); no committed siblings to compare against, so the ceiling of 0.3:1 applies."

# A silent reply alone cannot tell a judged pass from a skipped file, so each countable input is also sent one prose line over the limit.
pair() { # $1 label, $2 content at the limit, $3 content one prose line over it, $4 target name, $5 counts the refusal prints (default 31 / 100)
  local t0=$SECONDS at over took
  at=$(pre "$RD" "$RD/src/$4" "$4-at" "$2"); over=$(reason_of "$(pre "$RD" "$RD/src/$4" "$4-over" "$3")")
  took=$((SECONDS - t0))
  [ "$took" -le 5 ] && [ -z "$at" ] && case "$over" in *"(${5:-31 comment lines, 100 code})"*) true ;; *) false ;; esac
  verdict $? "$1" "took $took s, at the limit=[$at] over it=[$over]"
}
quiet() { # $1 label, $2 content, $3 target name
  local t0=$SECONDS out took
  out=$(pre "$RD" "$RD/src/$3" "$3-q" "$2"); took=$((SECONDS - t0))
  [ "$took" -le 5 ] && [ -z "$out" ]
  verdict $? "$1" "took $took s, out=[$out]"
}
mix 2769 9231 > "$TMP/p-big-at.txt"; mix 2770 9230 > "$TMP/p-big-over.txt"
pair "rule: a 12,000-line Write within 5 s: 2,769 prose / 9,231 code passes and 2,770 / 9,230 is refused" \
  "$TMP/p-big-at.txt" "$TMP/p-big-over.txt" big.js "2770 comment lines, 9230 code"
long=$(head -c 200000 /dev/zero | tr '\0' 'x')
{ mix 30 0; echo "// $long"; mix 0 99; } > "$TMP/p-long-at.txt"; { mix 31 0; echo "// $long"; mix 0 99; } > "$TMP/p-long-over.txt"
pair "rule: a comment line over 20,000 bytes is one code line, within 5 s: with a 200 kB one, 30 / 100 passes and 31 / 100 is refused" \
  "$TMP/p-long-at.txt" "$TMP/p-long-over.txt" long.js
for i in $(seq 1 30); do printf '/**\n */\n'; done > "$TMP/p-delims.txt"
quiet "rule: a Write of 60 delimiter-only lines passes, within 5 s" "$TMP/p-delims.txt" delims.js
crlf() { awk '{ printf "%s\r\n\r\n", $0 }'; }   # a CR-only line after each: counted as code, it would hide the 21st prose line
mix 30 100 | crlf > "$TMP/p-crlf-at.txt"; mix 31 100 | crlf > "$TMP/p-crlf-over.txt"
pair "rule: CRLF endings and CR-only blank lines, within 5 s: 30 / 100 passes and 31 / 100 is refused" \
  "$TMP/p-crlf-at.txt" "$TMP/p-crlf-over.txt" crlf.js
{ printf '\357\273\277'; mix 30 100; } > "$TMP/p-bom-at.txt"; { printf '\357\273\277'; mix 31 100; } > "$TMP/p-bom-over.txt"
pair "rule: a BOM before a first-line comment, within 5 s: 30 / 100 passes and 31 / 100 is refused" \
  "$TMP/p-bom-at.txt" "$TMP/p-bom-over.txt" bom.js
{ mix 0 10; echo '/*'; mix 60 0 | sed 's|^// ||'; } > "$TMP/p-open.txt"
quiet "rule: 60 lines in a block comment never closed are code: the Write passes, within 5 s" "$TMP/p-open.txt" open.js
{ echo '"""'; mix 60 0 | sed 's|^// ||'; mix 0 10; } > "$TMP/p-doc.txt"
quiet "rule: 60 lines in a docstring never closed are code: the Write passes, within 5 s" "$TMP/p-doc.txt" open.py
# jq turns an invalid byte in a payload into U+FFFD, so only a file on disk brings one to the classifier.
RB="$TMP/rule-bytes"; mkdir -p "$RB/src"
for n in 30 31; do mix "$n" 100 | while IFS= read -r l; do printf '%s caf\351 \377\376\n' "$l"; done > "$RB/src/b$n.js"; done
t0=$SECONDS; at=$(fire "$RB" "$RB/src/b30.js" b30); over=$(fire "$RB" "$RB/src/b31.js" b31); took=$((SECONDS - t0))
[ "$took" -le 5 ] && [ -z "$at" ] && case "$over" in *"(31 comment lines, 100 code)"*) true ;; *) false ;; esac
verdict $? "rule: invalid UTF-8 bytes in a file on disk after a Write, within 5 s: 30 / 100 is silent and 31 / 100 warns" \
  "took $took s, at the limit=[$at] over it=[$over]"

expect "rule: among lean siblings at the default the limit named is the ceiling, 0.3:1" \
  "$(fire "$RL" "$RL/app/Svc/Mid.php" sib1)" "its siblings run 0.1:1 and the limit here is 0.3:1"
{ echo '<?php'; mix 40 20; } > "$RL/app/Svc/Sixty.php"
expect "rule: with the ceiling at 0 a dense 60-line file among lean siblings still warns, at the 0.3 floor" \
  "$(COMMENT_DISCIPLINE_CEILING_TENTHS=0 fire "$RL" "$RL/app/Svc/Sixty.php" sib2)" \
  "(40 comment lines, 20 code); its siblings run 0.1:1 and the limit here is 0.3:1"

# ---- 16. EACH LANGUAGE THROUGH THE HOOK: what counts as prose decides the verdict ------
LG="$TMP/lang"; mkdir -p "$LG/src"
WHY='why %s: the upstream API returns a bare id here'
rep() { # $1 count, $2 printf format taking the line number once
  local i=0
  while [ "$i" -lt "$1" ]; do i=$((i + 1)); printf -- "$2\n" "$i"; done
}
free() { # $1 label, $2 target name; fixture on stdin -> a Write is silent, and on disk the file is measured and silent
  local w d
  cat > "$TMP/f-$2"; cp "$TMP/f-$2" "$LG/src/$2"
  w=$(pre "$LG" "$LG/src/$2" "f-$2" "$TMP/f-$2"); d=$(fire "$LG" "$LG/src/$2" "f-$2")
  [ -z "$w$d" ] && grep -qxF "file $LG/src/$2" "$LG"/.claude/comment-discipline/density-* 2>/dev/null
  verdict $? "$1" "write=[$w] on disk=[$d]"
}
deny60() { # $1 label, $2 target name; fixture on stdin -> a Write is refused at 60 prose / 20 code
  cat > "$TMP/l-$2"
  expect "$1" "$(pre "$LG" "$LG/src/$2" "l-$2" "$TMP/l-$2")" "(60 comment lines, 20 code)"
}
hush() { cat > "$TMP/h-$2"; quiet "$1" "$TMP/h-$2" "$2"; } # $1 label, $2 target name; fixture on stdin -> a Write passes

rep 30 '#[derive(Debug)]\nstruct S%s;' | free "lang: rs 60 lines of #[derive] and code are comment-free" free.rs
rep 20 '#include <x%s.h>\n#define N 1\nint f(void) { return N; }' | free "lang: c 60 lines of #include, #define and code are comment-free" free.c
{ echo '<?php'; rep 29 '#[Attribute]\nclass A%s {}'; echo 'return 1;'; } | free "lang: php 60 lines of #[Attribute] and code are comment-free" free.php
{ echo 'class A {'; rep 58 '  #f%s = 1;'; echo '}'; } | free "lang: js 60 lines of #private fields are comment-free" free.js
rep 20 '#region R%s\nint a;\n#endregion' | free "lang: cs 60 lines of #region and code are comment-free" free.cs

{ echo '"""'; rep 60 "$WHY"; echo '"""'; rep 20 'x%s = 1'; } | deny60 "lang: py a module docstring of 60 lines over 20 code is refused" mod.py
{ echo 'def f(x):'; echo '    """'; rep 60 "    $WHY"; echo '    """'; rep 19 '    y%s = x'; } |
  deny60 "lang: py a function docstring of 60 lines over 20 code is refused" fn.py
{ echo '/*'; rep 60 "$WHY"; echo '*/'; rep 20 'const a%s = 1;'; } | deny60 "lang: js 60 bare lines inside a block comment are refused" bare.js
{ echo '<template>'; rep 60 "  <!-- $WHY -->"; rep 18 '  <p>%s</p>'; echo '</template>'; } | deny60 "lang: vue 60 <!-- --> lines are refused" x.vue
{ rep 60 "{{-- $WHY --}}"; rep 20 '<p>%s</p>'; } | deny60 "lang: blade 60 {{-- --}} lines are refused" x.blade.php
{ rep 60 "{/* $WHY */}"; rep 20 '<p>%s</p>'; } | deny60 "lang: tsx 60 {/* */} lines are refused" x.tsx
{ rep 60 "-- $WHY"; rep 20 'SELECT %s;'; } | deny60 "lang: sql 60 -- lines are refused" x.sql
{ rep 60 "# $WHY"; rep 20 'echo %s'; } | deny60 "lang: sh 60 # lines are refused" run.sh

{ echo 'S = """'; rep 60 "$WHY"; echo '"""'; rep 18 'x%s = 1'; } | hush "lang: py 60 lines in a triple-quoted string assigned to a name are code" str.py
{ echo '<?php'; rep 20 '/**\n * @param int $id the user id\n * @return Foo<Bar> the thing\n * @throws RuntimeException when down\n */\nfunction f%s($id) {}'; } |
  hush "lang: php 60 typed doc tags with descriptions are not prose" tags.php
{ rep 30 '/**\n */'; rep 20 'const a%s = 1;'; } | hush "lang: js 60 delimiter-only lines are not prose" delims60.js
{ rep 60 '// eslint-disable-next-line no-console -- %s'; rep 20 'const a%s = 1;'; } | hush "lang: js 60 tool directives are not prose" directives.js
{ echo '// Copyright 2026 Example Ltd. All rights reserved.'; rep 59 '// clause %s: redistribution is permitted under the terms above'; rep 20 'const a%s = 1;'; } |
  hush "lang: js a 60-line licence block that opens the file is not prose" licence.js
{ echo '<?php'; echo 'return ['; echo '/*'; rep 60 '| line %s: this value is the name of the application'; echo '*/'; rep 17 "'k%s' => 1,"; echo '];'; } |
  hush "lang: php 60 |-boxed lines in a config block are not prose" box.php

{ echo '// why the module exists'; echo 'const first = 1;'; rep 59 '// clause %s: this file is under the MIT license'; rep 19 'const a%s = 1;'; } |
  deny60 "lang: js a licence block that is not the first comment run is prose, and refused" licence2.js
{ echo '/**'; rep 60 ' * @param id%s the user id'; echo ' */'; rep 20 'const a%s = 1;'; } |
  deny60 "lang: js 60 untyped doc tags with descriptions are prose, and refused" untyped.js

# ---- 17. ONE GOVERNED LIST, AND SIBLINGS BY LANGUAGE ------------------------------------
GV="$TMP/gov"
govern() { # $1 target under $GV, $2 comment line format, $3 code line format -> 60 prose / 20 code on all three lanes
  local f="$TMP/g-${1##*/}" w h d want="(60 comment lines, 20 code)"
  { rep 60 "$2"; rep 20 "$3"; } > "$f"; mkdir -p "$GV/${1%/*}"; cp "$f" "$GV/$1"
  w=$(pre "$GV" "$GV/$1" "gw-$1" "$f")
  h=$(bash_hook PreToolUse "$GV" "gh-$1" "$(heredoc "cat > $1" "$f")")
  d=$(bash_hook PostToolUse "$GV" "gd-$1" "echo x >> $1")
  case "$w" in *"$want"*) case "$h" in *"$want"*) case "$d" in *"$want"*) true ;; *) false ;; esac ;; *) false ;; esac ;; *) false ;; esac
  verdict $? "gov: a dense ${1##*/} is refused through a Write and a truncating heredoc, and draws the warning on disk" \
    "write=[$w] heredoc=[$h] on disk=[$d]"
}
govern src/x.css "/* $WHY */" '.a%s { color: red; }'
govern src/x.scss "// $WHY" '.a%s { color: red; }'
govern src/x.lua "-- $WHY" 'local a%s = 1'
govern src/x.ex "# $WHY" 'x%s = 1'
govern src/x.pl "# $WHY" 'my $a%s = 1;'
govern src/x.tf "# $WHY" 'variable "v%s" {}'
govern src/x.graphql "# $WHY" 'type A%s { id: ID }'
build_file() { # $1 target, $2 comment line format, $3 code line format -> 60 prose / 20 code is silent on all three lanes and leaves no state
  local root="$TMP/build-${1##*/}" f="$TMP/b-${1##*/}" w h d
  { rep 60 "$2"; rep 20 "$3"; } > "$f"; mkdir -p "$root/${1%/*}"; cp "$f" "$root/$1"
  w=$(pre "$root" "$root/$1" "bw-$1" "$f")
  h=$(bash_hook PreToolUse "$root" "bh-$1" "$(heredoc "cat > $1" "$f")")
  d=$(bash_hook PostToolUse "$root" "bd-$1" "echo x >> $1")
  [ -z "$w$h$d" ] && [ ! -e "$root/.claude" ]
  verdict $? "gov: a dense ${1##*/} is not judged for volume: a Write, a truncating heredoc and the file on disk are silent and leave no state" \
    "write=[$w] heredoc=[$h] on disk=[$d] state=[$(ls -A "$root/.claude" 2>/dev/null)]"
}
build_file ops/Dockerfile "# $WHY" 'RUN echo %s'
build_file ops/Makefile "# $WHY" 'V%s = 1'

ungov() { # $1 file name -> a Write and the file on disk are silent, and the hook keeps no state for it
  local f="$TMP/u-$1" root="$TMP/ungov-$1" w d
  mkdir -p "$root/src"; { rep 60 "# $WHY"; rep 20 'key%s: 1'; } > "$f"; cp "$f" "$root/src/$1"
  w=$(pre "$root" "$root/src/$1" u "$f"); d=$(fire "$root" "$root/src/$1" u)
  [ -z "$w$d" ] && [ ! -e "$root/.claude" ]
  verdict $? "gov: $1 is not governed: a Write and the file on disk are silent and leave no state" \
    "write=[$w] on disk=[$d] state=[$(ls -A "$root/.claude" 2>/dev/null)]"
}
ungov notes.md; ungov data.json; ungov conf.yaml

commit_all() { git -C "$1" init -q; git -C "$1" add -A; git -C "$1" -c user.email=t@t -c user.name=t commit -qm base; }
half() { { rep 5 "$2"; rep 10 "$3"; } > "$1"; } # $1 path, $2 comment format, $3 code format -> 5 prose / 10 code, 0.5:1
SD="$TMP/sib-lua"; mkdir -p "$SD/svc/a" "$SD/svc/b" "$SD/svc/c" "$SD/svc/new"
for n in a b c; do half "$SD/svc/$n/m.lua" "-- $WHY" 'local a%s = 1'; done
commit_all "$SD"; { rep 60 "-- $WHY"; rep 20 'local a%s = 1'; } > "$SD/svc/new/m.lua"
SM="$TMP/sib-perl"; mkdir -p "$SM/a" "$SM/b" "$SM/c" "$SM/new"
for n in a b c; do half "$SM/$n/m.pl" "# $WHY" 'my $a%s = 1;'; done
{ rep 60 "# $WHY"; rep 20 'my $a%s = 1;'; } > "$SM/new/m.pl"
w_lua=$(fire "$SD" "$SD/svc/new/m.lua" sd); w_perl=$(fire "$SM" "$SM/new/m.pl" sm)
case "$w_lua" in *"its siblings run 0.5:1"*) case "$w_perl" in *"its siblings run 0.5:1"*) true ;; *) false ;; esac ;; *) false ;; esac
verdict $? "gov: a .lua file finds its tracked siblings through git, and a .pl file outside git finds its own through find" \
  "lua=[$w_lua] perl=[$w_perl]"

SB="$TMP/sib-blade"; mkdir -p "$SB/views"
for n in a b c; do half "$SB/views/$n.blade.php" "{{-- $WHY --}}" '<p>%s</p>'; done
for n in d e f; do { echo '<?php'; rep 10 "// $WHY"; rep 10 '$v%s = 1;'; } > "$SB/views/$n.php"; done
commit_all "$SB"
{ rep 60 "{{-- $WHY --}}"; rep 20 '<p>%s</p>'; } > "$SB/views/new.blade.php"
{ echo '<?php'; rep 60 "// $WHY"; rep 19 '$v%s = 1;'; } > "$SB/views/new.php"
w_blade=$(fire "$SB" "$SB/views/new.blade.php" sb); w_php=$(fire "$SB" "$SB/views/new.php" sb)
case "$w_blade" in *"its siblings run 0.5:1"*) case "$w_php" in *"its siblings run 1.0:1"*) true ;; *) false ;; esac ;; *) false ;; esac
verdict $? "gov: in one directory and one session a Blade file is compared with Blade siblings only, and a .php file with .php siblings only" \
  "blade=[$w_blade] php=[$w_php]"

mkdir -p "$TMP/shim"; printf '#!/bin/bash\necho x >> "$AWK_COUNT"\nexec %s "$@"\n' "$(command -v awk)" > "$TMP/shim/awk"; chmod +x "$TMP/shim/awk"
awks() { # $1 sibling count -> how many awk processes one on-disk judgment among that many siblings starts; 0 when no sibling was found
  local r="$TMP/awks-$1" s=0 out   # not `i`: house and dense count with it
  mkdir -p "$r/app"; while [ "$s" -lt "$1" ]; do s=$((s + 1)); house "$r/app/S$s.php"; done
  commit_all "$r"; dense "$r/app/New.php"; : > "$TMP/awk-count-$1"
  out=$(AWK_COUNT="$TMP/awk-count-$1" PATH="$TMP/shim:$PATH" fire "$r" "$r/app/New.php" "awks$1")
  case "$out" in *"its siblings run 1.0:1"*) grep -c x "$TMP/awk-count-$1" ;; *) echo 0 ;; esac
}
n4=$(awks 4); n12=$(awks 12)
[ "$n4" -gt 0 ] && [ "$n4" = "$n12" ]
verdict $? "gov: judging a file among 12 siblings starts as many awk processes as among 4" "4 siblings: $n4, 12 siblings: $n12"

SX="$TMP/sib-gone"; mkdir -p "$SX/app"; for n in A B C D; do house "$SX/app/$n.php"; done
commit_all "$SX"; rm "$SX/app/A.php"; dense "$SX/app/New.php"   # the first operand: BSD awk stops there with nothing printed
expect "gov: a sibling that is tracked but gone from disk is skipped, and the other three still set the baseline" \
  "$(fire "$SX" "$SX/app/New.php" sx)" "its siblings run 1.0:1"

# ---- 18. RED-TEAM: the hook's ceiling, its bounds, awkward names and build files ----------
ceiling() { # $1 ceiling as written, $2 prose lines at the limit over 100 code, $3 the limit as printed
  local over_by_one=$(($2 + 1)) at over
  at=$(COMMENT_DISCIPLINE_CEILING_TENTHS=$1 wr "$2" 100)
  over=$(reason_of "$(COMMENT_DISCIPLINE_CEILING_TENTHS=$1 wr "$over_by_one" 100)")
  [ -z "$at" ] && case "$over" in *"($over_by_one comment lines, 100 code); the ceiling is $3:1"*) true ;; *) false ;; esac
  verdict $? "rt: a ceiling written $1 is $3: $2 prose / 100 code passes and $over_by_one / 100 is refused at $3:1" \
    "at the limit=[$at] over it=[$over]"
}
ceiling 010 100 1.0
ceiling 08 80 0.8
ceiling 0002 20 0.2

SG="$TMP/rt-big"; mkdir -p "$SG/src"
for n in 1 2 3; do half "$SG/src/a$n.js" "// $WHY" 'const a%s = 1;'; done
{ rep 15000 "// $WHY"; rep 15000 'const b%s = 1;'; } > "$TMP/rt-1mb.js"
for n in $(seq 10 34); do cp "$TMP/rt-1mb.js" "$SG/src/b$n.js"; done
commit_all "$SG"; { rep 60 "// $WHY"; rep 20 'const a%s = 1;'; } > "$SG/src/new.js"
t0=$SECONDS; out=$(fire "$SG" "$SG/src/new.js" big Edit); took=$((SECONDS - t0))
[ "$took" -le 5 ] && case "$out" in *"its siblings run 0.5:1"*) true ;; *) false ;; esac
verdict $? "rt: an Edit beside 25 tracked 1 MB siblings returns within 5 s, and only the three small siblings set the baseline" \
  "took $took s, out=[$out] ($(wc -c < "$TMP/rt-1mb.js") bytes each)"

thin() { printf "cat > src/f%s.js <<'EOF'\nconst a%s = 1;\nEOF\n" "$1" "$1"; }
heredocs() { # $1 the one heredoc of 400 that is dense -> the command
  local i=0
  while [ "$i" -lt 400 ]; do i=$((i + 1)); if [ "$i" = "$1" ]; then heredoc "cat > src/f$i.js"; else thin "$i"; fi; done
}
t0=$SECONDS; out41=$(bash_hook PreToolUse "$DR" rt41 "$(heredocs 41)"); took41=$((SECONDS - t0))
t0=$SECONDS; out40=$(bash_hook PreToolUse "$DR" rt40 "$(heredocs 40)"); took40=$((SECONDS - t0))
[ "$took41" -le 5 ] && [ "$took40" -le 5 ] && [ -z "$out41" ] && denied "$out40" && names "$out40" f40.js
verdict $? "rt: a command of 400 heredocs returns within 5 s: a dense 41st is left to the disk lane, a dense 40th is refused" \
  "41st: took $took41 s, out=[$out41]; 40th: took $took40 s, out=[$out40]"

SN="$TMP/rt-newline"; mkdir -p "$SN/src"; newline_name=$(printf 'a\nb.js'); mix 40 60 > "$SN/src/$newline_name"
w=$(reason_of "$(pre "$SN" "$SN/src/$newline_name" nl "$SN/src/$newline_name")"); d=$(fire "$SN" "$SN/src/$newline_name" nl Edit)
case "$w" in "comment-discipline: a"*) case "$d" in "comment-discipline: a"*) true ;; *) false ;; esac ;; *) false ;; esac
verdict $? "rt: a file name holding a newline draws a full reason on a Write and a full warning on disk, never an empty one" \
  "write=[$w] on disk=[$d]"

SU="$TMP/rt-names"; mkdir -p "$SU/src"
for n in 'файл.js' 'q"uote.js' 'back\slash.js'; do half "$SU/src/$n" "// $WHY" 'const a%s = 1;'; done
commit_all "$SU"; { rep 60 "// $WHY"; rep 20 'const a%s = 1;'; } > "$SU/src/new.js"
expect "rt: tracked siblings named with Cyrillic letters, a double quote and a backslash are all found" \
  "$(fire "$SU" "$SU/src/new.js" names)" "its siblings run 0.5:1"

if locale -a 2>/dev/null | grep -qix 'de_DE\.utf-\{0,1\}8'; then
  SL="$TMP/rt-locale"; mkdir -p "$SL/src"; mix 35 100 > "$SL/src/de.js"
  w=$(reason_of "$(LC_ALL=de_DE.UTF-8 pre "$SL" "$SL/src/de.js" de "$SL/src/de.js")"); d=$(LC_ALL=de_DE.UTF-8 fire "$SL" "$SL/src/de.js" de Edit)
  case "$w" in *"would be 0.4:1 comment-to-code (35 comment lines, 100 code); the ceiling is 0.3:1"*)
    case "$d" in *"is 0.4:1 comment-to-code (35 comment lines, 100 code); no committed siblings to compare against, so the ceiling of 0.3:1 applies."*) true ;; *) false ;; esac ;;
    *) false ;; esac
  verdict $? "rt: under LC_ALL=de_DE.UTF-8 the refusal and the warning print their ratios with a dot" "write=[$w] on disk=[$d]"
else echo "SKIP: rt: under LC_ALL=de_DE.UTF-8 the refusal and the warning print their ratios with a dot — no de_DE UTF-8 locale"; fi

build_and_scan() { # $1 file name, $2 comment format, $3 code format, $4 a comment restating $5, the line after it
  local root="$TMP/rt-build-$1" f="$TMP/rt-b-$1" w h d s
  { rep 60 "$2"; rep 20 "$3"; printf '%s\n%s\n' "$4" "$5"; } > "$f"; mkdir -p "$root"; cp "$f" "$root/$1"
  w=$(pre "$root" "$root/$1" rtb "$f"); h=$(bash_hook PreToolUse "$root" rtb "$(heredoc "cat > $1" "$f")")
  d=$(bash_hook PostToolUse "$root" rtb "echo x >> $1"); s=$(HOOK="$SCAN" pre "$root" "$root/$1" rts "$f")
  [ -z "$w$h$d" ] && denied "$s" && case "$(reason_of "$s")" in *"restating the next line"*) true ;; *) false ;; esac
  verdict $? "rt: a $1 of 60 prose / 20 code draws nothing from density.sh on any lane, while scan.sh refuses its restating comment" \
    "write=[$w] heredoc=[$h] on disk=[$d] scan=[$s]"
}
build_and_scan Dockerfile "# $WHY" 'RUN echo %s' '# install curl' 'RUN apt-get install -y curl'
build_and_scan Makefile "# $WHY" 'V%s = 1' '# build the app' 'build: app'

FU="$TMP/fix2-cap"; mkdir -p "$FU/src"; missed=""; s=0
for unjudged in "echo 'const e = 1;' > src/e%s.js" "python3 - > src/p%s.js <<'PY'\nprint(1)\nPY" \
  "cat >> src/a%s.js <<'EOF'\nconst a = 1;\nEOF" "cat > d%s/Dockerfile <<'EOF'\nRUN true\nEOF"; do
  s=$((s + 1)); out=$(bash_hook PreToolUse "$FU" "cap$s" "$(rep 40 "$unjudged"; heredoc 'cat > src/d41.js')")
  denied "$out" && names "$out" d41.js || missed="$missed [${unjudged%%%*}: $out]"
done
[ -z "$missed" ]
verdict $? "fix2: 40 echo, python3, append or Dockerfile chunks do not fill the 40-chunk cap: a dense 41st heredoc is still refused" "missed:$missed"

SY="$TMP/fix2-links"; mkdir -p "$SY/src" "$SY/data"; cp "$TMP/rt-1mb.js" "$SY/data/big.txt"
for n in 1 2 3; do half "$SY/src/a$n.js" "// $WHY" 'const a%s = 1;'; done
for n in $(seq 10 34); do ln -s ../data/big.txt "$SY/src/b$n.js"; done
commit_all "$SY"; { rep 60 "// $WHY"; rep 20 'const a%s = 1;'; } > "$SY/src/new.js"
t0=$SECONDS; out=$(fire "$SY" "$SY/src/new.js" links Edit); took=$((SECONDS - t0))
[ "$took" -le 5 ] && case "$out" in *"its siblings run 0.5:1"*) true ;; *) false ;; esac
verdict $? "fix2: 25 tracked symlinks to a 1 MB file are over the byte cap like the file: within 5 s only the three small siblings set the baseline" \
  "took $took s, out=[$out]"

SC="$TMP/fix2-count"; mkdir -p "$SC/src"; { rep 1 "// $WHY"; rep 20 'const a%s = 1;'; } > "$SC/src/a.js"
cp "$TMP/rt-1mb.js" "$SC/src/b1.js"; cp "$TMP/rt-1mb.js" "$SC/src/b2.js"
commit_all "$SC"; { rep 60 "// $WHY"; rep 20 'const a%s = 1;'; } > "$SC/src/new.js"
expect "fix2: siblings the byte cap drops do not count toward the three a baseline needs: one small sibling left sets none" \
  "$(fire "$SC" "$SC/src/new.js" count Edit)" "no committed siblings to compare against, so the ceiling of 0.3:1 applies."

SV="$TMP/fix2-clamp"; mkdir -p "$SV/src"; mix 200 100 > "$SV/src/c.js"; got=""
for v in 9223372036854775807 99999999999999999999 18446744073709551619; do
  w=$(COMMENT_DISCIPLINE_CEILING_TENTHS=$v pre "$SV" "$SV/src/c.js" "cw$v" "$SV/src/c.js")
  COMMENT_DISCIPLINE_CEILING_TENTHS=$v fire "$SV" "$SV/src/c.js" "cd$v" Edit >/dev/null
  got="$got $v:write=[${w:+deny}] limit=$(tail -n 1 "$HOME/.claude/comment-discipline/density-ledger.jsonl" 2>/dev/null | jq -r '.limit_tenths' 2>/dev/null)"
done
[ "$got" = " 9223372036854775807:write=[] limit=10000 99999999999999999999:write=[] limit=10000 18446744073709551619:write=[] limit=10000" ]
verdict $? "fix2: a ceiling of 19 or 20 digits is clamped to 1000:1: a 2:1 Write passes and the disk lane applies 10000 tenths" "got:$got"

SW="$TMP/fix2-newline"; mkdir -p "$SW/src" "$SW/lib"
for n in a b "$(printf 'x\nc')"; do half "$SW/src/$n.js" "// $WHY" 'const a%s = 1;'; done
for n in 1 2 3; do { rep 10 "// $WHY"; rep 10 'const c%s = 1;'; } > "$SW/lib/c$n.js"; done
commit_all "$SW"; { rep 60 "// $WHY"; rep 20 'const a%s = 1;'; } > "$SW/src/new.js"
expect "fix2: a sibling name holding a newline adds no fragment to the count: two real siblings beside it send the walk up a level" \
  "$(fire "$SW" "$SW/src/new.js" newline Edit)" "its siblings run 1.0:1"

[ "$rc" -eq 0 ] && echo "comment-density-tests: all assertions passed"
exit "$rc"
