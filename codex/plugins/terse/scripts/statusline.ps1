# Statusline badge showing the active terse level, e.g. [TERSE:ULTRA].
# Windows twin of statusline.sh — same rules, same refusals.
#
# Opt-in. Wire it yourself in settings.json:
#   "statusLine": { "type": "command",
#     "command": "powershell -ExecutionPolicy Bypass -File <plugin>\\scripts\\statusline.ps1" }
#
# SECURITY: the level file is user-writable state rendered into a terminal on
# every keystroke. Refuse reparse points, cap the read, strip everything outside
# a tiny character class, and whitelist the result — anything unrecognized
# renders nothing rather than echoing bytes from a file this script does not own.

$cfg = if ($env:CLAUDE_CONFIG_DIR) { $env:CLAUDE_CONFIG_DIR } else { Join-Path $env:USERPROFILE '.claude' }
$flag = Join-Path $cfg 'terse-mode'

if (-not (Test-Path -LiteralPath $flag -PathType Leaf)) { exit 0 }

$item = Get-Item -LiteralPath $flag -Force
if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) { exit 0 }

$mode = (Get-Content -LiteralPath $flag -TotalCount 1 -ErrorAction SilentlyContinue)
if (-not $mode) { exit 0 }
$mode = ($mode.Trim().ToLower() -replace '[^a-z-]', '')
if ($mode.Length -gt 16) { exit 0 }

if ($mode -notin @('lite', 'full', 'ultra', 'wenyan-lite', 'wenyan-full', 'wenyan-ultra')) { exit 0 }

$esc = [char]27
Write-Host -NoNewline "$esc[2;36m[TERSE:$($mode.ToUpper())]$esc[0m"
