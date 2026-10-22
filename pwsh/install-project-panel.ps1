# Puts a "tri-design" shortcut on the desktop that opens project-panel.ps1 (re-run to repair it).
$pwsh = (Get-Command pwsh -ErrorAction Stop).Source
$panel = Join-Path $PSScriptRoot 'project-panel.ps1'
$icon = Join-Path $PSScriptRoot 'tri-design.ico'   # make-tri-design-icon.ps1 draws it
$desktop = [Environment]::GetFolderPath('Desktop')
$link = Join-Path $desktop 'tri-design.lnk'

# The shortcut was called "Claude 项目" before; drop that copy so there is one entry point.
$old = Join-Path $desktop 'Claude 项目.lnk'
if (Test-Path $old) { Remove-Item -LiteralPath $old }

$sc = (New-Object -ComObject WScript.Shell).CreateShortcut($link)
$sc.TargetPath = $pwsh
$sc.Arguments = "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$panel`""
$sc.WorkingDirectory = 'E:\projects'
$sc.Description = '选择项目，在 herdr 里打开 Claude（可选走 tri-design 流程）'
$sc.IconLocation = "$icon,0"
$sc.Save()
"已创建：$link"
