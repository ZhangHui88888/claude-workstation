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

# Projects cw finds by name: git repos at E:\projects\<name> or E:\projects\<category>\<name>.
# Copies left behind by the WSL migration carry MIGRATED.md and are skipped.
function Get-CwProjects {
    Get-ChildItem E:\projects -Directory | ForEach-Object { $_; Get-ChildItem $_.FullName -Directory -ErrorAction SilentlyContinue } |
        Where-Object { (Test-Path (Join-Path $_.FullName '.git')) -and -not (Test-Path (Join-Path $_.FullName 'MIGRATED.md')) }
}

# A path is used as is; anything else is matched against project names (an exact name wins, fzf picks among several).
function Resolve-CwProject {
    param([string]$Project)
    if (-not $Project) { return $PWD.Path }
    if (Test-Path $Project -PathType Container) { return (Resolve-Path $Project).ProviderPath }
    $projects = @(Get-CwProjects)
    $exact = @($projects | Where-Object { $_.Name -eq $Project })
    if ($exact.Count -eq 1) { return $exact[0].FullName }
    $lines = $projects | ForEach-Object { "$($_.FullName.Substring(12) -replace '\\', '/')`t$($_.FullName)" }
    if (Get-Command fzf -ErrorAction SilentlyContinue) {
        $pick = $lines | fzf --query $Project --select-1 --exit-0 --delimiter "`t" --with-nth 1 --height 40% --reverse
        if ($pick) { return ($pick -split "`t")[1] }
    } else {
        $hits = @($projects | Where-Object { $_.Name -like "*$Project*" })
        if ($hits.Count -eq 1) { return $hits[0].FullName }
        if ($hits.Count -gt 1) { Write-Warning "多个项目匹配 '$Project'：$($hits.Name -join ', ')"; return }
    }
    Write-Warning "没有匹配 '$Project' 的项目"
}

# cw [project] [step|prompt...]: open a herdr workspace for a project and start Claude in it.
#   project  a path or part of a project name; defaults to the current directory.
#   step     a tri-design step (benchmark, audit, ...) is sent as /tri-design:<step> plus the rest;
#            any other words are sent as the first prompt.
function cw {
    param([string]$Project, [Parameter(ValueFromRemainingArguments)][string[]]$Rest)
    $dir = Resolve-CwProject $Project
    if (-not $dir) { return }
    $prompt = $null
    if ($Rest) {
        $steps = 'audit', 'benchmark', 'build', 'fix', 'item-review', 'new', 'skills', 'strategy-review'
        $words = if ($Rest[0] -in $steps) { @("/tri-design:$($Rest[0])") + @($Rest | Select-Object -Skip 1) } else { $Rest }
        $prompt = $words -join ' '
    }
    $name = Split-Path $dir -Leaf
    $agent = (($name.ToLower() -replace '[^a-z0-9_-]', '-') -replace '^[^a-z]+', '')
    if ($agent.Length -gt 32) { $agent = $agent.Substring(0, 32) }
    if (-not $agent) { $agent = 'claude' }
    herdr status server *> $null
    if ($LASTEXITCODE -ne 0) {
        if ($prompt) { Write-Host "herdr 没在运行，先打开 herdr；进入 Claude 后手动输入：$prompt" }
        Push-Location $dir; herdr; Pop-Location; return
    }
    $out = herdr workspace create --cwd $dir --label $name --focus | ConvertFrom-Json
    $pane = $out.result.root_pane.pane_id
    $ws = $out.result.workspace.workspace_id
    if (-not $pane) { return }
    # Let herdr-sidebar dock first: starting Claude while it splits/swaps races the layout on Windows.
    for ($i = 0; $i -lt 25; $i++) {
        $panes = (herdr pane list | ConvertFrom-Json).result.panes | Where-Object { $_.workspace_id -eq $ws }
        if ($panes | Where-Object { $_.label -in 'Sidebar', 'Explorer' }) { break }
        Start-Sleep -Milliseconds 200
    }
    herdr agent start $agent --kind claude --pane $pane | Out-Null
    if ($LASTEXITCODE -eq 0 -and $prompt) { herdr agent prompt $pane $prompt | Out-Null }
}

if (Get-Module -ListAvailable PSReadLine) {
    Set-PSReadLineOption -EditMode Windows -BellStyle None
    # Ctrl+V pastes the Windows clipboard in the shell (WezTerm passes Ctrl+V through for Claude's image paste).
    Set-PSReadLineKeyHandler -Chord Ctrl+v -Function Paste
}
