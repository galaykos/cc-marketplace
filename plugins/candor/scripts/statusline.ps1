# Statusline badge showing the active terse level, e.g. [TERSE:ULTRA].
# Windows twin of statusline.sh and level.sh — same order, same rules, same refusals.
#
# Opt-in. Wire it yourself in settings.json:
#   "statusLine": { "type": "command",
#     "command": "powershell -ExecutionPolicy Bypass -File <plugin>\\scripts\\statusline.ps1" }
#
# The level: CC_TERSE, then the level file's first word, then the cc_terse /config option
# (CLAUDE_PLUGIN_OPTION_CC_TERSE, else pluginConfigs["candor@*"] in managed-settings.json, then
# in the user settings.json), else off; a value outside the vocabulary is off. A reparse-point
# settings file is not read, and neither are --settings files or policy delivered another way.
#
# SECURITY: the level file is user-writable state rendered into a terminal on
# every keystroke. A reparse-point level file blanks the badge, and only a
# whitelisted level renders — anything unrecognized renders nothing rather than
# echoing bytes from a file this script does not own.

$ErrorActionPreference = 'SilentlyContinue'
try {
  $cfg = if ($env:CLAUDE_CONFIG_DIR) { $env:CLAUDE_CONFIG_DIR } else { Join-Path $env:USERPROFILE '.claude' }
  $flag = Join-Path $cfg 'terse-mode'

  function Test-PlainFile($path) {
    if (-not $path -or -not (Test-Path -LiteralPath $path -PathType Leaf)) { return $false }
    -not ((Get-Item -LiteralPath $path -Force).Attributes -band [IO.FileAttributes]::ReparsePoint)
  }

  $item = Get-Item -LiteralPath $flag -Force
  if ($item -and ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)) { exit 0 }

  $mode = $env:CC_TERSE
  if (-not $mode -and (Test-PlainFile $flag)) {
    # As bash `read`: first line, split on space/tab only, so a kept CR or BOM makes the level invalid.
    $line = [IO.File]::ReadAllText($flag, [Text.Encoding]::ASCII).Split([char]10)[0]
    $words = $line.Split([char[]]@(' ', "`t"), [StringSplitOptions]::RemoveEmptyEntries)
    if ($words.Count -gt 0) { $mode = $words[0] }
  }
  if (-not $mode) {
    $mode = $env:CLAUDE_PLUGIN_OPTION_CC_TERSE
    if ($mode -ceq 'true') { $mode = 'on' } elseif ($mode -ceq 'false') { $mode = 'off' }
  }
  if (-not $mode) {
    $managed = if ($env:ProgramFiles) { Join-Path $env:ProgramFiles 'ClaudeCode\managed-settings.json' }
    foreach ($s in @($managed, (Join-Path $cfg 'settings.json'))) {
      if (-not (Test-PlainFile $s)) { continue }
      $j = Get-Content -LiteralPath $s -Raw | ConvertFrom-Json
      foreach ($p in @($j.pluginConfigs.PSObject.Properties)) {
        $v = $p.Value.options.cc_terse
        if ($p.Name -clike 'candor@*' -and $v -is [string] -and $v) { $mode = $v; break }
      }
      if ($mode) { break }
    }
  }

  if ($mode -cnotin @('lite', 'full', 'ultra', 'wenyan-lite', 'wenyan-full', 'wenyan-ultra')) { exit 0 }

  $esc = [char]27
  Write-Host -NoNewline "$esc[2;36m[TERSE:$($mode.ToUpper())]$esc[0m"
} catch { exit 0 }
