param([string]$Kind = 'done', [string]$Project = '')
$titles = @{
  done  = 'Claude Code 完成了'
  input = 'Claude Code 在等你'
  fail  = 'Claude Code 验证没通过'
}
$title = $titles[$Kind]; if (-not $title) { $title = 'Claude Code' }
[Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] > $null
$tpl = [Windows.UI.Notifications.ToastNotificationManager]::GetTemplateContent([Windows.UI.Notifications.ToastTemplateType]::ToastText02)
$text = $tpl.GetElementsByTagName('text')
$text.Item(0).AppendChild($tpl.CreateTextNode($title)) > $null
$text.Item(1).AppendChild($tpl.CreateTextNode($Project)) > $null
$appId = '{1AC14E77-02E7-4E5D-B744-2EB1AE5198B7}\WindowsPowerShell\v1.0\powershell.exe'
[Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($appId).Show([Windows.UI.Notifications.ToastNotification]::new($tpl))
