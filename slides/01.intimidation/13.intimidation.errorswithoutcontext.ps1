[Console]::CursorVisible = $false

Write-Host ""

Write-PokemonSpeechBubble -CharacterName "Generic Experienced IT Wizard" -CharacterImage $global:CharacterImageOak -Text @"
[White]Hey Shaun,
We need to check out the TriggerBuilds.ps1 script that kicks off the nightly project builds for some of the older apps.
It was working until an upgrade of the build server yesterday.[/]
"@
Read-PresentationPause

Write-PokemonSpeechBubble -CharacterName "Shaun" -CharacterImage $global:CharacterImageShaun -Color $global:PresentationAccentColor -Text @"
[White]...
Mhmm[/]
"@
Read-PresentationPause

$ErrorActionPreference = "Continue"
$WarningPreference = "SilentlyContinue"

Start-PresentationWebServer

Write-PresentationCodeBlockTabs @("TriggerBuilds.ps1", "TriggerBuildsWithContext.ps1") -ActiveTab 0 -Padding 3
$codeblock = @'

  $projects = Invoke-RestMethod -Method "GET" -Uri "http://localhost:18383/projects"

  $payload = @{
      ProjectsToBuild = $projects
  }

  $payloadJson = $payload | ConvertTo-Json -Compress

  $result = Invoke-RestMethod -Method "POST" -Uri "http://localhost:18383/build" -Body $payloadJson

'@
Write-Codeblock -Text $codeblock -SyntaxHighlight -ShowLineNumbers -Theme "Presentation"

$endOfCodeBlock = $Host.UI.RawUI.CursorPosition.Y

Write-Host ""
Write-SpectreHost "  PS> [yellow]./TriggerBuilds.ps1[/]" -NoNewline
Read-PresentationPause -Terminal
Write-Host "`n"

Invoke-Expression $codeblock

Stop-PresentationWebServer

$global:SlideSettings = @{
    ClearBelowLine = $endOfCodeBlock
    Overwrite = $true
}