[Console]::CursorVisible = $false

Write-Host ""

Write-PokemonSpeechBubble -CharacterName "Shaun" -CharacterImage $global:CharacterImageShaun -Color $global:PresentationAccentColor -Text @"
[White]I miss C,
Back when everything made sense...[/]
"@

Write-SpectreParagraph "[White]Reading scripts can be especially difficult for those who have different primary languages.[/]" -Padding 2
Write-Host ""
Write-SpectreParagraph -Color "White" '[yellow]$_[/] and [yellow]$PSItem[/] (automatic variables), and shorthand aliases are great when working on the CLI but these were some of the most confusing items for me when inheriting scripts. They seem easy now but the cognitive overhead for people who are in-and-out of PowerShell is non-trivial.' -Padding 2
Write-Host ""

Write-SpectreHost "  [White]Even though aliases and shorthand is common (this is a bit on the extreme side):[/]`n"
Write-CodeBlock @'

  ls | % {
      ls $_ | ? { $_ -like "*.txt" } | % {
          echo $_.Name
      }
  }

'@ -SyntaxHighlight -Theme "Presentation" -ShowLineNumbers

Write-Host ""

Write-SpectreParagraph "  [White]I prefer the option that seems more familiar for someone coming from another language.[/]`n" -Padding 2
Write-Host ""

Write-CodeBlock @'

  $folders = Get-ChildItem "."
  foreach($folder in $folders) {
      $files = Get-ChildItem $folder
      foreach($file in $files) {
          Write-Host $file
      }
  }

'@ -SyntaxHighlight -Theme "Presentation" -ShowLineNumbers

# https://github.com/StartAutomating/Benchpress/blob/master/docs/Different_Ways_To_Iterate.benchmark.benchmarkOutput.md