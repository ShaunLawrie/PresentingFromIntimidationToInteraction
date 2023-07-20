Write-Host ""
Write-PokemonSpeechBubble -CharacterName "Shaun" -CharacterImage $global:CharacterImageShaunOlder -Color $global:PresentationAccentColor -Text @"
[White]What do I encourage as good ways to get into PowerShell?
Take a REST.
API consumption is so common in build pipelines but many people don't realise how good PowerShell is at doing it.[/]
"@

Write-PresentationCodeBlockTabs @("Invoke-RestMethod-Versus-JQ.ps1") -ActiveTab 0 -Padding 2
Write-CodeBlock @'

  $output = Invoke-RestMethod -Uri "https://wttr.in/NewYork?format=j1"

  output=$(curl "https://wttr.in/NewYork?format=j1")

  # get the current weather description or https://jsonplaceholder.typicode.com/todos

'@ -SyntaxHighlight -ShowLineNumbers -Theme "Presentation"

Start-PresentationPrompt