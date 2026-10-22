# PowerShell 7 profile for native-Windows herdr panes.
# Documents\PowerShell\profile.ps1 dot-sources this file.

$env:EDITOR = 'micro'
$env:VISUAL = 'micro'

# Report the cwd to herdr (OSC 7) at every prompt so herdr-sidebar follows `cd`.
$global:__basePrompt = $function:prompt
function global:prompt {
    $loc = $executionContext.SessionState.Path.CurrentLocation
    if ($loc.Provider.Name -eq 'FileSystem') {
        $uri = 'file://' + $env:COMPUTERNAME + '/' + ($loc.ProviderPath -replace '\\', '/')
        [Console]::Write("$([char]27)]7;$uri$([char]27)\")
    }
    # A TUI (e.g. Claude Code) can exit with mouse tracking still on; herdr then forwards mouse
    # moves and ConPTY sometimes drops the ESC [ M prefix, typing coordinates as text. Turn it off.
    [Console]::Write("$([char]27)[?1000l$([char]27)[?1002l$([char]27)[?1003l$([char]27)[?1006l$([char]27)[?1015l")
    & $global:__basePrompt
}

# cw [project] [step|prompt...]: open a project as a herdr workspace with Claude (see cw.ps1).
. (Join-Path $PSScriptRoot 'cw.ps1')

if (Get-Module -ListAvailable PSReadLine) {
    Set-PSReadLineOption -EditMode Windows -BellStyle None
    # Ctrl+V pastes the Windows clipboard in the shell (WezTerm passes Ctrl+V through for Claude's image paste).
    Set-PSReadLineKeyHandler -Chord Ctrl+v -Function Paste
}
