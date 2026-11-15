Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
$workspace = Split-Path -Parent $PSScriptRoot
$dialog = New-Object System.Windows.Forms.Form
$dialog.Text = 'ZamMarket - private staging setup'
$dialog.Size = New-Object System.Drawing.Size(570,310)
$dialog.StartPosition = 'CenterScreen'
$dialog.TopMost = $true
$heading = New-Object System.Windows.Forms.Label
$heading.Text = 'Paste values from your STAGING project Connect dialog. No SQL will run.'
$heading.Location = New-Object System.Drawing.Point(20,15)
$heading.Size = New-Object System.Drawing.Size(520,38)
$dialog.Controls.Add($heading)
$urlLabel = New-Object System.Windows.Forms.Label
$urlLabel.Text = 'Staging project URL'
$urlLabel.Location = New-Object System.Drawing.Point(20,60)
$dialog.Controls.Add($urlLabel)
$urlBox = New-Object System.Windows.Forms.TextBox
$urlBox.Location = New-Object System.Drawing.Point(20,85)
$urlBox.Width = 510
$dialog.Controls.Add($urlBox)
$keyLabel = New-Object System.Windows.Forms.Label
$keyLabel.Text = 'Staging publishable key (sb_publishable_...)'
$keyLabel.Location = New-Object System.Drawing.Point(20,125)
$keyLabel.Width = 500
$dialog.Controls.Add($keyLabel)
$keyBox = New-Object System.Windows.Forms.TextBox
$keyBox.Location = New-Object System.Drawing.Point(20,150)
$keyBox.Width = 510
$keyBox.UseSystemPasswordChar = $true
$dialog.Controls.Add($keyBox)
$save = New-Object System.Windows.Forms.Button
$save.Text = 'Save staging values'
$save.Location = New-Object System.Drawing.Point(20,205)
$save.Width = 190
$dialog.Controls.Add($save)
$save.Add_Click({
 $save.Enabled = $false
 try {
  $start = New-Object System.Diagnostics.ProcessStartInfo
  $start.FileName = (Get-Command node).Source
  $start.Arguments = 'scripts/save-staging-private.mjs'
  $start.WorkingDirectory = $workspace
  $start.UseShellExecute = $false
  $start.CreateNoWindow = $true
  $start.RedirectStandardInput = $true
  $start.RedirectStandardOutput = $true
  $start.RedirectStandardError = $true
  $process = [System.Diagnostics.Process]::Start($start)
  $process.StandardInput.WriteLine((@{url=$urlBox.Text;key=$keyBox.Text} | ConvertTo-Json -Compress))
  $process.StandardInput.Close()
  $null = $process.StandardOutput.ReadToEnd()
  $null = $process.StandardError.ReadToEnd()
  $process.WaitForExit()
  if ($process.ExitCode -ne 0) { throw 'Not saved' }
  $keyBox.Clear()
  [System.Windows.Forms.MessageBox]::Show('Saved privately. Return to Codex and say saved so the staging check can run.','ZamMarket') | Out-Null
  $dialog.Close()
 } catch {
  [System.Windows.Forms.MessageBox]::Show('Not saved. Check the staging URL, publishable key, existing placeholders and file access. No values were logged.','ZamMarket') | Out-Null
  $save.Enabled = $true
 }
})
$null = $dialog.ShowDialog()
$keyBox.Clear()
$dialog.Dispose()
