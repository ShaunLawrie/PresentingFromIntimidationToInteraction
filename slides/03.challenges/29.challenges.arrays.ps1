Write-Host ""
Write-PokemonSpeechBubble -CharacterName "Shaun" -CharacterImage $global:CharacterImageShaunOlder -Color $global:PresentationAccentColor -Text @"
[White]Number 1 in the challenges I still face when writing PowerShell.
Arrays.
The flattening and collapsing behaviour I believe is intended to make things easier but it's unpredictable.[/]
"@

Write-PresentationCodeBlockTabs @("ArrayCollapsing.ps1") -ActiveTab 0 -Padding 2
Write-CodeBlock @'

  $users = @("shaun", "jenny", "oak")

  $group = @{ Name = "Admins"; Members = @() }

  $group.Members = $users | Where-Object { $_ -notlike "*a*" }

'@ -SyntaxHighlight -ShowLineNumbers -Theme "Presentation"

Start-PresentationPrompt
