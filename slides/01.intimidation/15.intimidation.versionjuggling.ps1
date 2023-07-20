[Console]::CursorVisible = $false

Write-Host ""

Write-PokemonSpeechBubble -CharacterName "10x Engineer" -CharacterImage $global:CharacterImage10x -Text @"
[White]I'm off to lunch now.
I need you to update the app pool configs on the dev server, the default site keeps going to sleep and people are complaining it's slow.
Use DisableIdleTimeout.ps1, It's in the shared docs on my PC.[/]
"@
Read-PresentationPause

Write-PokemonSpeechBubble -CharacterName "Shaun" -CharacterImage $global:CharacterImageShaun -Color $global:PresentationAccentColor -Text @"
[White]Hey,
Is that it?
Oh they're gone. I guess I'll figure it out myself.[/]
"@
Read-PresentationPause

Write-PresentationCodeBlockTabs @("DisableIdleTimeout.ps1", "DisableIdleTimeout2.ps1", "Enter-WindowsPowerShell.ps1") -ActiveTab 0 -Padding 3
$codeblock = @'

  param (
    [string] $AppPoolName
  )

  # Import pre-req module
  Import-Module WebAdministration

  # Disable idle timeout on an app pool
  $appPool = Get-ChildItem IIS:\AppPools | Where-Object { $_.Name -eq $AppPoolName }
  $appPool.processModel.idleTimeout = [TimeSpan]::FromMinutes(0)
  $appPool | Set-Item
  Write-Host "Disabled idle timeout on '$($appPool.Name)' from PS v$($PSVersionTable.PSVersion.Major)"

'@

Write-CodeBlock -Text $codeblock -SyntaxHighlight -ShowLineNumbers -Theme "Presentation"

$endOfCodeBlock = $Host.UI.RawUI.CursorPosition.Y

Write-Host ""
Write-SpectreHost "  PS> [yellow]./DisableIdleTimeout.ps1[/] [Grey42]-AppPoolName[/] [$global:PresentationAccentColor]`"DemoAppPool`"[/]" -NoNewline
Read-PresentationPause -Terminal
Write-Host "`n"

$ErrorActionPreference = "Continue"
$global:ErrorView = 'CategoryView'
$WarningPreference = "SilentlyContinue"
Invoke-Expression $codeblock

$global:SlideSettings = @{
  ClearBelowLine = $endOfCodeBlock
  Overwrite = $true
}