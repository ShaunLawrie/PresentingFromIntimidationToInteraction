[Console]::CursorVisible = $false

$codeblock = @'

  function Enter-WindowsPowerShell {
      if($PSVersionTable.PSVersion.Major -gt 5) {
          $script = "-File $($PSCommandPath -replace "^/mnt/([a-z])/", "`$1:/")"
          $argstring = ""
          $PsBoundParameters.GetEnumerator() | Foreach-Object {
              if($_.Value.GetType().Name -eq "SwitchParameter") {
                  $argstring += " -$($_.Key)"
              } else {
                  $argstring += " -$($_.Key):`"$($_.Value)`""
              }
          }

          Write-Verbose "Relaunching in PowerShell for Windows"

          Start-Process -FilePath "powershell.exe" `
                        -ArgumentList ($script + $argstring) `
                        -LoadUserProfile -UseNewEnvironment -NoNewWindow -Wait
          
          exit 0
      }
  }

'@

[Console]::CursorVisible = $false

Write-Host ""

Write-PokemonSpeechBubble -CharacterName "10x Engineer" -CharacterImage $global:CharacterImage10x -Text @"
[White]I'm off to lunch now.
I need you to update the app pool configs on the dev server, the default site keeps going to sleep and people are complaining it's slow.
Use DisableIdleTimeout.ps1, It's in the shared docs on my PC.[/]
"@

Write-PokemonSpeechBubble -CharacterName "Shaun" -CharacterImage $global:CharacterImageShaun -Color $global:PresentationAccentColor -Text @"
[White]Hey,
Is that it?
Oh they're gone. I guess I'll figure it out myself.[/]
"@

Write-PresentationCodeBlockTabs @("DisableIdleTimeout.ps1", "DisableIdleTimeout2.ps1", "Enter-WindowsPowerShell.ps1") -ActiveTab 2 -Padding 3
Write-CodeBlock -Text $codeblock -SyntaxHighlight -ShowLineNumbers -Theme "Presentation"

Start-PresentationPrompt -Commands $codeblock