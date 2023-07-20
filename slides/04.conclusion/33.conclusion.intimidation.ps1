Write-PresentationMarginTop -MarginPercent 0.43

$cursorPosition = $Host.UI.RawUI.CursorPosition

Write-SpectreParagraph "1. [White]Intimidation[/][black][/]" -Alignment "Center"
Write-SpectreParagraph "2. [White]Interaction[/][black].[/]" -Alignment "Center"
Write-SpectreParagraph "3. [White]Challenges[/][black]..[/]" -Alignment "Center"

[Console]::SetCursorPosition($cursorPosition.X, $cursorPosition.Y)

Read-PresentationPause -Terminal
Write-SpectreParagraph "[steelblue1]1. Intimidation[/][black][/]" -Alignment "Center"

Read-PresentationPause -Terminal
Write-SpectreParagraph "[Magenta2_1]2. Interaction[/][black].[/]" -Alignment "Center"

Read-PresentationPause -Terminal
Write-SpectreParagraph "[Gold1]3. Challenges[/][black]..[/]" -Alignment "Center"
