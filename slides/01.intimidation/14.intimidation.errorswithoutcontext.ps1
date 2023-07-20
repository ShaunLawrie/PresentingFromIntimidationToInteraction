[Console]::CursorVisible = $false

Write-Host ""

Write-PokemonSpeechBubble -CharacterName "Generic Experienced IT Wizard" -CharacterImage $global:CharacterImageOak -Text @"
[White]Hey Shaun,
We need to check out the TriggerBuilds.ps1 script that kicks off the nightly project builds for some of the older apps.
It was working until an upgrade of the build server yesterday.[/]
"@

Write-PokemonSpeechBubble -CharacterName "Shaun" -CharacterImage $global:CharacterImageShaun -Color $global:PresentationAccentColor -Text @"
[White]...
Mhmm[/]
"@

$ErrorActionPreference = "Continue"
$WarningPreference = "SilentlyContinue" # Pretend to be powershell 5

Start-PresentationWebServer

Write-PresentationCodeBlockTabs @("TriggerBuilds.ps1", "TriggerBuildsWithContext.ps1") -ActiveTab 1 -Padding 3
$codeblock = @'

  $projects = Invoke-RestMethod -Method "GET" -Uri "http://localhost:18383/projects"

  $payload = @{
      ProjectsToBuild = $projects
  }

  $payloadJson = $payload | ConvertTo-Json -Compress

  Write-Verbose "Sending request 'POST http://localhost:18383/build'`n$payloadJson" -Verbose
  $result = Invoke-RestMethod -Method "POST" "http://localhost:18383/build" -Body $payloadJson

'@
Write-Codeblock -Text $codeblock -SyntaxHighlight -ShowLineNumbers -Theme "Presentation"

Write-Host ""
Write-SpectreHost "  PS> [yellow]./TriggerBuildsWithContext.ps1[/]" -NoNewline
Read-PresentationPause -Terminal
Write-Host "`n"

Invoke-Expression $codeblock

Start-PresentationPrompt

Stop-PresentationWebServer $server