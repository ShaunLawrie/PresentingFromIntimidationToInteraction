Write-Host ""

Read-PresentationPause
Write-PokemonSpeechBubble -CharacterName "Generic Experienced IT Wizard" -CharacterImage $global:CharacterImageOak -Text @"
[White]Hi Shaun, we've received an alert for testsrv01 running low on disk space.
You can use the clean up script CleanUpScript.ps1 on the shared drive to clear some space out.
Run the script in a PowerShell terminal. Good Luck![/]
"@
Read-PresentationPause

Write-PokemonSpeechBubble -CharacterName "Shaun" -CharacterImage $global:CharacterImageShaun -Color $global:PresentationAccentColor -Text @"
[White]Don't worry prof!
I've got this![/]
"@
Read-PresentationPause

[Console]::CursorVisible = $true
Write-SpectreHost "  PS> [yellow]./CleanUpScript.ps1[/]" -NoNewline

Read-PresentationPause -Terminal

Write-Host "`n"

$ErrorActionPreference = "Continue"
$InformationPreference = "Continue"
$global:ErrorView = 'ConciseView'

Set-Location ".\logs"
Write-Information "Finding files to remove in .\logs directory"
$cleanup = Get-ChildItem -Recurse
Write-Information "Removing $($cleanup.Count) files"
Write-Progress -Id 1 -Activity "Removing Files" -PercentComplete 1
0..($cleanup.Count) | Foreach-Object {
    $percentComplete = [int]($_ / $cleanup.Count * 100)
    Write-Progress -Id 1 -Activity "Removing Files" -Status "Deleting $($cleanup[$_].Name)" -PercentComplete $percentComplete
    Start-Sleep -Milliseconds 50
}
Write-Progress -Id 1 -Activity "Removing Files" -Completed
Write-Information "Completed log cleanup"