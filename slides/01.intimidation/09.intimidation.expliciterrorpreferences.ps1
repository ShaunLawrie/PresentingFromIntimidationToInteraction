[Console]::CursorVisible = $false

Write-Host ""
Write-SpectreParagraph "[White]The script didn't have a good time and neither did I.[/]" -Padding 2
Write-Host ""

$location = $Host.UI.RawUI.CursorPosition
Write-SpectreParagraph "[White]Should we expect people to know about error preference variables on day 1?[/]" -Padding 2 -NoNewline
Read-PresentationPause
[Console]::SetCursorPosition($location.X, $location.Y)
Write-PresentationTextStream "Should we expect people to know about error preference variables on day 1?" -Padding 2 -NoNewline -StrikeThrough
Write-Host -NoNewline "  "
Read-PresentationPause

Write-Host ""
Write-Host ""
Write-SpectreParagraph -Color "White" "My personal preference is to set an explicit error preference inside my scripts. There are enough things to think about and the script may be unsafe if it continues after non-terminating errors." -Padding 2

Write-Host ""
Write-PresentationCodeBlockTab "CleanUpScript.ps1" -Padding 3
Write-CodeBlock @'

  $ErrorActionPreference = "Stop"

  # Clean up all the files in the "logs" dir using the Valve cleanup algo
  # https://github.com/ValveSoftware/steam-for-linux/issues/3671

  Set-Location ".\logs"
  $cleanup = Get-ChildItem -Recurse
  $cleanup | Remove-Item -Force

'@ -SyntaxHighlight -ShowLineNumbers -Theme "Presentation"