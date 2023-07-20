Write-Host ""

Write-PokemonSpeechBubble -CharacterName "Generic Experienced IT Wizard" -CharacterImage $global:CharacterImageOak -Text @"
[White]Hi Shaun, [DarkOrange]10x Engineer[/] is working on some of our interview questions.
Can you provide some feedback? It should be easy enough to read, if you need a hand reach out!
Check out FizzBuzzCondensed.ps1 on the shared drive.[/]
"@
Read-PresentationPause

Write-PokemonSpeechBubble -CharacterName "Shaun" -CharacterImage $global:CharacterImageShaun -Color $global:PresentationAccentColor -Text @"
[White]Ok,
I'm on it![/]
"@
Read-PresentationPause

[Console]::CursorVisible = $false

Write-PresentationCodeBlockTabs @("FizzBuzzCondensed.ps1", "FizzBuzzConcise.ps1") -ActiveTab 0 -Padding 3
Write-CodeBlock @'

  # Original Author: Professor
  # Updated: Yesterday
  # Note: Fizz buzz implementation in PowerShell

  # 10x Engineer: Explain why this is the best way to fizz your buzzes in PowerShell
  1..100|%{$x="Fizz"*!($_%3)+"Buzz"*!($_%5);$x ?$x :$_}











'@ -SyntaxHighlight -ShowLineNumbers -Theme "Presentation"

$global:SlideSettings = @{
  Overwrite = $true
}