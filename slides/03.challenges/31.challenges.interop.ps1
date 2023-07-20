Write-Host ""
Write-PokemonSpeechBubble -CharacterName "Shaun" -CharacterImage $global:CharacterImageShaunOlder -Color $global:PresentationAccentColor -Text @"
[White]And lastly, interop with native binaries.
Trying to parse things can be difficult.
Unfortunately not everything in the terminal is PowerShell.[/]
"@

Write-PresentationCodeBlockTabs @("Interop.ps1") -ActiveTab 0 -Padding 2
Write-CodeBlock @'

  # Encoding issues
  $distros = wsl --list --all --verbose
  $ubuntu = $distros[2]

  # Exit statuses
  git checkout -b main

'@ -SyntaxHighlight -ShowLineNumbers -Theme "Presentation"

Start-PresentationPrompt -Command $codeblock