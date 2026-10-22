# Puts a "Claude 项目" shortcut on the desktop that opens project-panel.ps1 (re-run to repair it).
$pwsh = (Get-Command pwsh -ErrorAction Stop).Source
$panel = Join-Path $PSScriptRoot 'project-panel.ps1'
$claude = Get-Command claude -ErrorAction SilentlyContinue
$link = Join-Path ([Environment]::GetFolderPath('Desktop')) 'Claude 项目.lnk'

$sc = (New-Object -ComObject WScript.Shell).CreateShortcut($link)
$sc.TargetPath = $pwsh
$sc.Arguments = "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$panel`""
$sc.WorkingDirectory = 'E:\projects'
$sc.Description = '选择项目，在 herdr 里打开 Claude'
$sc.IconLocation = if ($claude) { "$($claude.Source),0" } else { 'C:\Program Files\WezTerm\wezterm-gui.exe,0' }
$sc.Save()
"已创建：$link"
