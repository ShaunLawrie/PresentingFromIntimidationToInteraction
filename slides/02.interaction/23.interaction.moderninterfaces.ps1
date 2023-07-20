Write-Host ""
Write-PokemonSpeechBubble -CharacterName "Shaun" -CharacterImage $global:CharacterImageShaunOlder -Color $global:PresentationAccentColor -Text @"
[White]How am I trying to make PowerShell more of an obvious part of peoples lives at PartsTrader?
I'm really good at breaking machines.
After building my 5th dev machine I took to PowerShell to make things easier for the next people.[/]
"@

Write-SpectreHost "  PS> [yellow]DevSetup.ps1[/]" -NoNewline
Read-PresentationPause -Terminal
Write-Host "`n"

if($env:USERNAME -like "*shaun*") {
    if($global:AutoPlay) {
        Write-Warning "Live demo"
        Start-Sleep -Seconds 60
        return
    }
    & DevSetup.ps1
} else {
    Write-SpectreHost "`n  [yellow]Sorry this was an internal tool I can't share.[/]"
    Read-PresentationPause
}

Start-PresentationPrompt