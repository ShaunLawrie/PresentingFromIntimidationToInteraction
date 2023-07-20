Write-Host ""

Write-Tweet -AuthorName "Steven Bucher" -AuthorHandle "@StevenBucher13" -ImagePath D:\Dev\PwshFromIntimidationToInteraction\slides\media\character-feedback.png -Content @'
New blog alert! :police_car_light: Feedback Providers!
What they are, why we made them and how to use them yourself! Check it out:
https://devblogs.microsoft.com/powershell/what-are-feedback-providers/
'@

Read-PresentationPause

Write-PokemonSpeechBubble -CharacterName "Shaun" -CharacterImage $global:CharacterImageShaunOlder -Color $global:PresentationAccentColor -Text @"
[White]These look cool.
I have some ideas but I'm still working on these.
At the moment I can see potential for slower feedback providers that don't ruin the terminal UX but I need to work more on them.[/]
"@

Read-PresentationPause

Start-PresentationPrompt -Prompt 'function prompt { "  PS> " } '
