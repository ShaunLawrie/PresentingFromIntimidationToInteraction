[Console]::CursorVisible = $false

Write-Host ""
Write-PokemonSpeechBubble -CharacterName "Shaun" -CharacterImage $global:CharacterImageShaun -Color $global:PresentationAccentColor -Text @"
[White]Ok so I've got this script to clean up the logs dir.
What actually happens when I run it?[/]
"@

Write-PresentationCodeBlockTab "CleanUpScript.ps1" -Padding 3
Write-CodeBlock @'

  Set-Location ".\logs"
  $cleanup = Get-ChildItem -Recurse
  $cleanup | Remove-Item -Force

'@ -SyntaxHighlight -ShowLineNumbers -Theme "Presentation"