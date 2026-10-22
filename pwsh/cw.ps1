# cw and the desktop project panel share these: find a project, then open it as a herdr workspace with Claude.
# profile.ps1 and project-panel.ps1 dot-source this file.

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

$CwSteps = 'audit', 'benchmark', 'build', 'fix', 'item-review', 'new', 'next', 'skills', 'strategy-review'

# A leading tri-design step name becomes /tri-design:<step>; anything else is sent as typed.
function ConvertTo-CwPrompt {
    param([string[]]$Words)
    if (-not $Words) { return $null }
    if ($Words[0] -in $CwSteps) { $Words = @("/tri-design:$($Words[0])") + @($Words | Select-Object -Skip 1) }
    ($Words -join ' ').Trim()
}

# Needs a running herdr server. Creates the workspace, starts Claude, sends the prompt; returns whether Claude started.
function Start-CwAgent {
    param([string]$Dir, [string]$Prompt)
    $name = Split-Path $Dir -Leaf
    $agent = (($name.ToLower() -replace '[^a-z0-9_-]', '-') -replace '^[^a-z]+', '')
    if ($agent.Length -gt 32) { $agent = $agent.Substring(0, 32) }
    if (-not $agent) { $agent = 'claude' }
    $out = herdr workspace create --cwd $Dir --label $name --focus | ConvertFrom-Json
    $pane = $out.result.root_pane.pane_id
    $ws = $out.result.workspace.workspace_id
    if (-not $pane) { return $false }
    # Let herdr-sidebar dock first: starting Claude while it splits/swaps races the layout on Windows.
    for ($i = 0; $i -lt 25; $i++) {
        $panes = (herdr pane list | ConvertFrom-Json).result.panes | Where-Object { $_.workspace_id -eq $ws }
        if ($panes | Where-Object { $_.label -in 'Sidebar', 'Explorer' }) { break }
        Start-Sleep -Milliseconds 200
    }
    herdr agent start $agent --kind claude --pane $pane | Out-Null
    if ($LASTEXITCODE -ne 0) { return $false }
    if ($Prompt) { herdr agent prompt $pane $Prompt | Out-Null }
    $true
}

# cw [project] [step|prompt...]: open a herdr workspace for a project and start Claude in it.
#   project  a path or part of a project name; defaults to the current directory.
#   step     a tri-design step (benchmark, audit, ...) is sent as /tri-design:<step> plus the rest;
#            any other words are sent as the first prompt.
function cw {
    param([string]$Project, [Parameter(ValueFromRemainingArguments)][string[]]$Rest)
    $dir = Resolve-CwProject $Project
    if (-not $dir) { return }
    $prompt = ConvertTo-CwPrompt $Rest
    herdr status server *> $null
    if ($LASTEXITCODE -ne 0) {
        if ($prompt) { Write-Host "herdr 没在运行，先打开 herdr；进入 Claude 后手动输入：$prompt" }
        Push-Location $dir; herdr; Pop-Location; return
    }
    Start-CwAgent $dir $prompt | Out-Null
}
