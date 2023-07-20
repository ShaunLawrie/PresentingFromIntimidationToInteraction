Write-Host ""
Write-PokemonSpeechBubble -CharacterName "Shaun" -CharacterImage $global:CharacterImageShaunOlder -Color $global:PresentationAccentColor -Text @"
[White]Number 2 in the challenges I still face when writing PowerShell.
Output.
The fact that anything that isn't redirected can be returned from the function causes havoc when there is conditional logic.[/]
"@

$codeblock = @'

  function Save-CurrentDate {
    $logPath = "$env:TEMP\logs"
    
    if(-not (Test-Path $logPath)) {
        New-Item $logPath -ItemType "Directory"
    }
  
    $currentDateTime = Get-Date
    Add-Content -Path "$logPath\log.txt" -Value "Current datetime is $currentDateTime"
  
    return $currentDateTime
  }

'@

Write-PresentationCodeBlockTabs @("ImplicitReturns.ps1") -ActiveTab 0 -Padding 3
Write-CodeBlock $codeblock -SyntaxHighlight -ShowLineNumbers -Theme "Presentation"

Start-PresentationPrompt -Command $codeblock
