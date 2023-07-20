Write-Host ""
Write-PokemonSpeechBubble -CharacterName "AI - 9001" -CharacterImage $global:CharacterImageAi -Text @"
[White]What about me...?

[/]
"@

Read-PresentationPause

Write-PokemonSpeechBubble -CharacterName "Shaun" -CharacterImage $global:CharacterImageShaunOlder -Color $global:PresentationAccentColor -Text @"
[White]AI, the better rubber duck.
PowerShellAI has been my playground.
[/]
"@

Read-PresentationPause

Write-PresentationCodeBlockTabs @("Invoke-AICodeInterpreter.ps1") -ActiveTab 0 -Padding 0
Write-CodeBlock @'

  Invoke-AICodeInterpreter -Start @"
   - Take a number and return another one
   - Given a number parameter of 140 the function returns 61575
   - Given a number parameter of 10 the function returns 314
  "@

'@ -SyntaxHighlight -Theme "Presentation"

Write-Host ""

Start-PresentationPrompt -Prompt 'function prompt { "  PS> " } ' -Command @"
Import-Module "$global:ModulesRoot\PwshSpectreConsole\PwshSpectreConsole\PwshSpectreConsole.psm1" -Force
Import-Module "$global:ModulesRoot\PowerShellAI\PowerShellAI.psm1" -Force
"@

