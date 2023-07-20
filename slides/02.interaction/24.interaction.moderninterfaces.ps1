Write-Host ""
Write-PokemonSpeechBubble -CharacterName "Shaun" -CharacterImage $global:CharacterImageShaun -Color $global:PresentationAccentColor -Text @"
[White]A more recent example is the script I built to help my team acces resources in AWS.
Managing SSH tunneling is a pain and AWS SSM can do the heavy lifting.[/]
"@

Write-SpectreHost "  PS> [yellow]./SSMConnect.ps1[/]" -NoNewline
Read-PresentationPause -Terminal
Write-Host "`n"
Clear-Host

if($env:USERNAME -like "*shaun*") {
    if($global:AutoPlay) {
        Write-Warning "Live demo"
        Start-Sleep -Seconds 60
        return
    }
    & SsmConnect.ps1
} else {
    Write-SpectreHost "`n  [yellow]Sorry this was an internal tool I can't share.[/]"
    Read-PresentationPause
}

Start-PresentationPrompt -Command @"
Import-Module "$global:ModulesRoot\PwshSpectreConsole\PwshSpectreConsole\PwshSpectreConsole.psm1" -Force
"@