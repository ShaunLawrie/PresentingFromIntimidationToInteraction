[Console]::CursorVisible = $false

Write-Host ""

Write-PokemonSpeechBubble -CharacterName "10x Engineer" -CharacterImage $global:CharacterImage10x -Text @"
[White]Nice work on the app pools, I knew you'd find it easy.
Here's another one for ya!
I have a runbook for setting up new Windows GitHub runners, see if you can fire one up.[/]
"@
Read-PresentationPause

Write-PokemonSpeechBubble -CharacterName "Shaun" -CharacterImage $global:CharacterImageShaun -Color $global:PresentationAccentColor -Text @"
[White]Alright,
How hard could it be.
Oh wow it's 32 chapters...[/]
"@
Read-PresentationPause

Write-BrowserChrome -TabTitle "Github Runner Setup" -Url "[SpringGreen1]$([char]0xea75)[/] [Grey42]https://[/]shaunlawrie.atlassian.net[Grey42]/wiki/github-runner-setup[/]"
Write-SpectreParagraph -Text @"
Github Runner Setup - [Grey35 italic]Chapter 1 of 32[/]
 
 1. Run [DodgerBlue3]Connect-AzAccount | Out-Null[/] to login.
 2. Load the latest template with [DodgerBlue3]`$template = Get-Content -Path slides\media\template.yml -Raw | ConvertFrom-Yaml[/].
 3. Update the template date [DodgerBlue3]`$template.Date = Get-Date[/] to make a change.
 4. Put the template into a secure string with [DodgerBlue3]`$val = ConvertTo-SecureString `$template -AsPlainText -Force[/].
 4. Upload the template data to Key Vault [DodgerBlue3]Set-AzKeyVaultSecret -VaultName "scrt" -Name "gh-run" -SecretValue `$val[/].
"@ -Color "black" -BackgroundColor "white" -Padding 2 -NoTrim

Start-PresentationPrompt