[Console]::CursorVisible = $false

Write-Host ""

Write-PokemonSpeechBubble -CharacterName "Developer" -CharacterImage $global:CharacterImageDev -Text @"
[White]Hi Shaun.
I'm having trouble with one of the scripts your team built, it's supposed to show me my file checksums.
It's not finding anything on my machine but It works on other ones :person_shrugging:[/]
"@
Read-PresentationPause

Write-PokemonSpeechBubble -CharacterName "Shaun" -CharacterImage $global:CharacterImageShaun -Color $global:PresentationAccentColor -Text @"
[White]Uhhh have you tried turning it off an on again?
Oh that works for a while and breaks again.
Yep I can take a look![/]
"@
Read-PresentationPause

Write-PresentationCodeBlockTab "CompanyCommands.ps1" -Padding 3
Write-CodeBlock @'

  function Get-FileHashes {
      param (
          [int] $Limit = 10
      )
  
      $files = Get-ChildItem "." -File -Recurse
      $output = @()
      foreach($file in $files) {
          if($processed -ge $Limit) {
              break
          }
          $output += [pscustomobject]@{
              Name = $file.FullName
              Hash = (Get-FileHash $file.FullName).Hash
          }
          $processed++
      }
      return $output
  }

'@ -SyntaxHighlight -Theme "Presentation" -ShowLineNumbers

Start-PresentationPrompt -Prompt 'function prompt { "`n  PS `e[38;2;236;0;140m(remote)`e[0m> " } ' -Commands @'
function Get-FileHashes {
    param (
        [int] $Limit = 10
    )

    $files = Get-ChildItem . -File -Recurse
    $output = @()
    foreach($file in $files) {
        if($processed -ge $Limit) {
            break
        }
        $output += [pscustomobject]@{
            Name = $file.FullName
            Hash = (Get-FileHash $file.FullName).Hash
        }
        $processed++
    }
    return $output
}
$Processed = 1000
'@

# scoping is confusing and causes errors when you don't realise you can access a variable in an external scope
