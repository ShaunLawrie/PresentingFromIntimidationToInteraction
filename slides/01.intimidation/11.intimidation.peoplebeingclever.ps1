[Console]::CursorVisible = $false

Write-Host ""

Write-PokemonSpeechBubble -CharacterName "Generic Experienced IT Wizard" -CharacterImage $global:CharacterImageOak -Text @"
[White]Hi Shaun, [DarkOrange]10x Engineer[/] is working on some of our interview questions.
Can you provide some feedback? It should be easy enough to read, if you need a hand reach out!
Check out FizzBuzzCondensed.ps1 on the shared drive.[/]
"@

Write-PokemonSpeechBubble -CharacterName "Shaun" -CharacterImage $global:CharacterImageShaun -Color $global:PresentationAccentColor -Text @"
[White]Ok,
I'm on it![/]
"@

Write-PresentationCodeBlockTabs @("FizzBuzzCondensed.ps1", "FizzBuzzConcise.ps1") -ActiveTab 1 -Padding 3
Write-CodeBlock @'

  # 10x Engineer: Explain why this is the best way to fizz your buzzes in PowerShell
  # Author: It's not
  1..100|%{$x="Fizz"*!($_%3)+"Buzz"*!($_%5);$x ?$x :$_}

  # Author: Shaun Lawrie
  for($i = 1; $i -le 100; $i++) {
      if($i % 15 -eq 0) {
          Write-Output "FizzBuzz"
      } elseif($i % 3 -eq 0) {
          Write-Output "Fizz"
      } elseif($i % 5 -eq 0) {
          Write-Output "Buzz"
      } else {
          Write-Output $i
      }
  }

'@ -SyntaxHighlight -ShowLineNumbers -Theme "Presentation"

Start-PresentationPrompt