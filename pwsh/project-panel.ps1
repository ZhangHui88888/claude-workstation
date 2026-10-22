# Desktop "tri-design" panel: pick a project (and optionally a tri-design step), then open it in the Windows herdr
# tab of WezTerm as a workspace with Claude. The desktop shortcut (install-project-panel.ps1) runs this hidden.
#   -Snapshot <png>  render the panel off-screen to a PNG and exit, for checking the layout.
param([string]$Snapshot)

# Started from Explorer, the environment can predate tools installed since login; reload it like windows-herdr.ps1.
$machine = [Environment]::GetEnvironmentVariables('Machine')
$user = [Environment]::GetEnvironmentVariables('User')
foreach ($k in $machine.Keys) { if ($k -ne 'Path') { Set-Item "env:$k" $machine[$k] } }
foreach ($k in $user.Keys) { if ($k -ne 'Path') { Set-Item "env:$k" $user[$k] } }
$env:Path = $machine['Path'] + ';' + $user['Path']

. (Join-Path $PSScriptRoot 'cw.ps1')
Add-Type -AssemblyName System.Windows.Forms, System.Drawing
[System.Windows.Forms.Application]::SetHighDpiMode('PerMonitorV2') | Out-Null
[System.Windows.Forms.Application]::EnableVisualStyles()

# --- recent projects (per machine, outside the repo) ---
$recentFile = Join-Path $env:LOCALAPPDATA 'claude-project-panel\recent.json'
function Get-Recent { try { @(Get-Content $recentFile -Raw -ErrorAction Stop | ConvertFrom-Json) } catch { @() } }
function Save-Recent([string]$Dir) {
    $list = @($Dir) + @(Get-Recent | Where-Object { $_ -ne $Dir }) | Select-Object -First 10
    New-Item -ItemType Directory -Force (Split-Path $recentFile) | Out-Null
    ConvertTo-Json -InputObject @($list) | Set-Content $recentFile -Encoding utf8
}

# --- WezTerm / herdr ---
# The Windows herdr tab is the one WezTerm opened in E:/projects (windows_herdr in wezterm.lua).
$herdrTabArgs = 'powershell.exe', '-NoLogo', '-NoExit', '-ExecutionPolicy', 'Bypass', '-File', 'E:/projects/_claude-config/wezterm/windows-herdr.ps1'
# Started outside WezTerm there is no WEZTERM_UNIX_SOCKET, and `wezterm cli` then fails to connect; point it
# at the running GUI's socket.
function Connect-Wezterm {
    $sockets = Get-Process wezterm-gui -ErrorAction SilentlyContinue |
        ForEach-Object { Join-Path $env:USERPROFILE ".local\share\wezterm\gui-sock-$($_.Id)" } | Where-Object { Test-Path $_ }
    if (-not $sockets) { return $false }
    if ($env:WEZTERM_UNIX_SOCKET -notin @($sockets)) { $env:WEZTERM_UNIX_SOCKET = @($sockets)[0] }
    $true
}
function Find-HerdrTab {
    if (-not (Connect-Wezterm)) { return }
    wezterm cli list --format json 2>$null | ConvertFrom-Json | Where-Object { $_.cwd -like 'file:///E:/projects*' } | Select-Object -First 1
}
function Show-HerdrTab {
    $tab = Find-HerdrTab
    if (-not $tab) {
        if (Connect-Wezterm) { wezterm cli spawn --cwd E:/projects -- @herdrTabArgs | Out-Null }
        else { Start-Process wezterm-gui.exe -ArgumentList (@('start', '--cwd', 'E:/projects', '--') + $herdrTabArgs) }
        for ($i = 0; $i -lt 50 -and -not ($tab = Find-HerdrTab); $i++) { Start-Sleep -Milliseconds 300 }
    }
    if ($tab) { wezterm cli activate-tab --tab-id $tab.tab_id 2>$null | Out-Null }
    $gui = Get-Process wezterm-gui -ErrorAction SilentlyContinue | Where-Object MainWindowHandle -ne 0 | Select-Object -First 1
    if ($gui) { (New-Object -ComObject WScript.Shell).AppActivate($gui.Id) | Out-Null }
    [bool]$tab
}
function Wait-HerdrServer {
    for ($i = 0; $i -lt 50; $i++) { herdr status server *> $null; if ($LASTEXITCODE -eq 0) { return $true }; Start-Sleep -Milliseconds 300 }
    $false
}

# --- form ---
$bg = [Drawing.Color]::FromArgb(30, 30, 46); $panel = [Drawing.Color]::FromArgb(49, 50, 68)
$fg = [Drawing.Color]::FromArgb(205, 214, 244); $dim = [Drawing.Color]::FromArgb(166, 173, 200)
$accent = [Drawing.Color]::FromArgb(137, 180, 250)  # blue, to match tri-design.ico
$font = New-Object Drawing.Font('Microsoft YaHei UI', 10)

# Layout is in 96-dpi units; the scale settings must land before ClientSize and the controls (a hashtable
# passed to -Property applies keys in no fixed order), and ResumeLayout below scales everything once.
$form = New-Object Windows.Forms.Form
$form.SuspendLayout()
$form.AutoScaleDimensions = [Drawing.SizeF]::new(96, 96)
$form.AutoScaleMode = 'Dpi'
$form.ClientSize = [Drawing.Size]::new(520, 560)
$form.Text = 'tri-design'; $form.Icon = [Drawing.Icon]::new((Join-Path $PSScriptRoot 'tri-design.ico')); $form.StartPosition = 'CenterScreen'; $form.FormBorderStyle = 'FixedSingle'
$form.MaximizeBox = $false; $form.BackColor = $bg; $form.ForeColor = $fg; $form.Font = $font; $form.KeyPreview = $true
function Add-Control($type, $props) { $c = New-Object "Windows.Forms.$type" -Property $props; $form.Controls.Add($c); $c }

Add-Control Label @{ Text = '选择项目'; Location = '16,14'; AutoSize = $true; ForeColor = $dim } | Out-Null
$search = Add-Control TextBox @{ Location = '16,38'; Size = '488,28'; PlaceholderText = '搜索项目名…'; BackColor = $panel; ForeColor = $fg; BorderStyle = 'FixedSingle' }
$list = Add-Control ListBox @{ Location = '16,72'; Size = '488,280'; BackColor = $panel; ForeColor = $fg; BorderStyle = 'None'; IntegralHeight = $false; DrawMode = 'OwnerDrawFixed' }
$list.ItemHeight = [Math]::Ceiling($font.Height * 1.2)  # pixels at the current DPI, so a fixed number would clip descenders
Add-Control Label @{ Text = '打开后先执行'; Location = '16,364'; AutoSize = $true; ForeColor = $dim } | Out-Null
$step = Add-Control ComboBox @{ Location = '16,388'; Size = '488,28'; DropDownStyle = 'DropDownList'; BackColor = $panel; ForeColor = $fg; FlatStyle = 'Flat' }
$note = Add-Control TextBox @{ Location = '16,426'; Size = '488,28'; PlaceholderText = '附加说明（可选）：接在命令后面；选“普通对话”时就是第一句话'; BackColor = $panel; ForeColor = $fg; BorderStyle = 'FixedSingle' }
$browse = Add-Control Button @{ Text = '其他文件夹…'; Location = '16,472'; Size = '150,36'; FlatStyle = 'Flat'; BackColor = $panel; ForeColor = $fg }
$open = Add-Control Button @{ Text = '打开'; Location = '384,472'; Size = '120,36'; FlatStyle = 'Flat'; BackColor = $accent; ForeColor = $bg }
$status = Add-Control Label @{ Text = '双击项目或按回车打开'; Location = '16,524'; Size = '488,24'; ForeColor = $dim }
$browse.FlatAppearance.BorderColor = $panel; $open.FlatAppearance.BorderColor = $accent
$form.AcceptButton = $open
$form.ResumeLayout($false)

$steps = @(
    @{ Label = '普通对话（不走 tri-design）'; Step = '' }
    @{ Label = '走 tri-design：接着上次的步骤'; Step = 'next' }
    @{ Label = 'benchmark · 对标调研，产出三份设计文档'; Step = 'benchmark' }
    @{ Label = 'strategy-review · 战略复盘，定方向与技术栈'; Step = 'strategy-review' }
    @{ Label = 'item-review · 逐条审核'; Step = 'item-review' }
    @{ Label = 'skills · 装技能与风格规范'; Step = 'skills' }
    @{ Label = 'build · 按审定的需求开发'; Step = 'build' }
    @{ Label = 'audit · 老项目体检'; Step = 'audit' }
    @{ Label = 'fix · 修复体检发现'; Step = 'fix' }
)
$steps | ForEach-Object { [void]$step.Items.Add($_.Label) }
$step.SelectedIndex = 0

# Recent projects first (marked ★), then by category: the places real projects live before tooling and sources.
$order = 'games', 'software', 'experiments', 'learning', 'external'
function New-Item-Row($Path, $Recent) {
    $rel = $Path.Substring(12) -split '\\'
    $cat = if ($rel.Count -gt 1) { $rel[0] } else { '' }
    $rank = $order.IndexOf($cat); if ($rank -lt 0) { $rank = $order.Count + [int]($cat -like '_*') }
    [pscustomobject]@{ Name = $rel[-1]; Category = $cat; Path = $Path; Recent = $Recent; Rank = $rank }
}
$recent = @(Get-Recent | Where-Object { Test-Path $_ })
$items = @($recent | ForEach-Object { New-Item-Row $_ $true }) +
    @(Get-CwProjects | Where-Object { $_.FullName -notin $recent } | ForEach-Object { New-Item-Row $_.FullName $false } | Sort-Object Rank, Category, Name)
$shown = @()
function Update-List {
    $q = $search.Text.Trim()
    $script:shown = @($items | Where-Object { -not $q -or "$($_.Category)/$($_.Name)" -like "*$q*" })
    $list.BeginUpdate(); $list.Items.Clear(); $script:shown | ForEach-Object { [void]$list.Items.Add($_.Name) }; $list.EndUpdate()
    if ($list.Items.Count) { $list.SelectedIndex = 0 }
}
$flags = [Windows.Forms.TextFormatFlags]'VerticalCenter, EndEllipsis, NoPrefix, SingleLine'
$list.add_DrawItem({
    param($s, $e)
    if ($e.Index -lt 0) { return }
    $it = $script:shown[$e.Index]; $sel = ($e.State -band [Windows.Forms.DrawItemState]::Selected) -ne 0
    $b = $e.Bounds
    $e.Graphics.FillRectangle((New-Object Drawing.SolidBrush($(if ($sel) { [Drawing.Color]::FromArgb(69, 71, 90) } else { $panel }))), $b)
    $s8 = [int]($b.Height / 3)
    if ($it.Recent) { [Windows.Forms.TextRenderer]::DrawText($e.Graphics, '★', $font, ([Drawing.Rectangle]::new($b.X + 6, $b.Y, $s8 * 2, $b.Height)), $accent, $flags) }
    $catW = [int]($b.Width * 0.32)
    [Windows.Forms.TextRenderer]::DrawText($e.Graphics, $it.Name, $font, ([Drawing.Rectangle]::new($b.X + $s8 * 3, $b.Y, $b.Width - $catW - $s8 * 3, $b.Height)), $(if ($sel) { $accent } else { $fg }), $flags)
    [Windows.Forms.TextRenderer]::DrawText($e.Graphics, $it.Category, $font, ([Drawing.Rectangle]::new($b.Right - $catW, $b.Y, $catW - 8, $b.Height)), $dim, $flags -bor 'Right')
})
# DropDownList ignores BackColor under visual styles, so the combo box draws its own rows (and its closed face).
$step.DrawMode = 'OwnerDrawFixed'; $step.ItemHeight = $font.Height + 2
$step.add_DrawItem({
    param($s, $e)
    if ($e.Index -lt 0) { return }
    $sel = ($e.State -band [Windows.Forms.DrawItemState]::Selected) -ne 0 -and ($e.State -band [Windows.Forms.DrawItemState]::ComboBoxEdit) -eq 0
    $e.Graphics.FillRectangle((New-Object Drawing.SolidBrush($(if ($sel) { [Drawing.Color]::FromArgb(69, 71, 90) } else { $panel }))), $e.Bounds)
    $r = [Drawing.Rectangle]::new($e.Bounds.X + 6, $e.Bounds.Y, $e.Bounds.Width - 6, $e.Bounds.Height)
    [Windows.Forms.TextRenderer]::DrawText($e.Graphics, $step.Items[$e.Index], $font, $r, $fg, $flags)
})
$search.add_TextChanged({ Update-List })
$search.add_KeyDown({
    param($s, $e)
    if ($e.KeyCode -eq 'Down' -and $list.SelectedIndex -lt $list.Items.Count - 1) { $list.SelectedIndex++; $e.Handled = $true }
    if ($e.KeyCode -eq 'Up' -and $list.SelectedIndex -gt 0) { $list.SelectedIndex--; $e.Handled = $true }
})
$form.add_KeyDown({ param($s, $e) if ($e.KeyCode -eq 'Escape') { $form.Close() } })

function Set-Status([string]$Text) { $status.Text = $Text; [Windows.Forms.Application]::DoEvents() }
function Open-Project([string]$Dir) {
    $s = $steps[$step.SelectedIndex].Step; $extra = $note.Text.Trim()
    $prompt = if ($s) { ("/tri-design:$s $extra").Trim() } elseif ($extra) { $extra } else { $null }
    $form.Enabled = $false
    try {
        Set-Status '正在打开 WezTerm 里的 Windows herdr…'
        if (-not (Show-HerdrTab)) { throw '找不到 WezTerm 里的 Windows herdr 标签页' }
        if (-not (Wait-HerdrServer)) { throw 'Windows herdr 没有启动起来' }
        Set-Status "正在为 $(Split-Path $Dir -Leaf) 启动 Claude…"
        if (-not (Start-CwAgent $Dir $prompt)) { throw 'herdr 没能启动 Claude' }
        Show-HerdrTab | Out-Null
        Save-Recent $Dir
        $form.Close()
    } catch {
        [Windows.Forms.MessageBox]::Show("打开失败：$_", 'tri-design', 'OK', 'Error') | Out-Null
        $form.Enabled = $true; Set-Status '双击项目或按回车打开'
    }
}
$open.add_Click({ if ($list.SelectedIndex -ge 0) { Open-Project $script:shown[$list.SelectedIndex].Path } else { Set-Status '先选一个项目' } })
$list.add_DoubleClick({ if ($list.SelectedIndex -ge 0) { Open-Project $script:shown[$list.SelectedIndex].Path } })
$browse.add_Click({
    $dlg = New-Object Windows.Forms.FolderBrowserDialog -Property @{ Description = '选择要打开的项目文件夹'; InitialDirectory = 'E:\projects'; UseDescriptionForTitle = $true }
    if ($dlg.ShowDialog($form) -eq 'OK') { Open-Project $dlg.SelectedPath }
})

Update-List
$form.add_Shown({ $search.Focus() })

if ($Snapshot) {
    $form.StartPosition = 'Manual'; $form.Location = New-Object Drawing.Point(-3000, -3000); $form.ShowInTaskbar = $false
    $form.Show(); [Windows.Forms.Application]::DoEvents()
    $bmp = New-Object Drawing.Bitmap($form.Width, $form.Height)
    $form.DrawToBitmap($bmp, ([Drawing.Rectangle]::new(0, 0, $form.Width, $form.Height)))
    $bmp.Save($Snapshot, [Drawing.Imaging.ImageFormat]::Png); $form.Close(); return
}
[void]$form.ShowDialog()
