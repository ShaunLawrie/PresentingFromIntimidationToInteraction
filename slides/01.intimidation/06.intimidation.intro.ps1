$sentences = @(
@"

  [White]Hello there! Welcome to the world of PowerShell![/]

"@,
@"

  [White]My name is [white]Generic Experienced IT Wizard[/]! People call me the PowerShell prof![/]

"@,
@"

  [White]This world is inhabited by creatures called Computers!
  For some people, Computers are pets. Other use them for fights. Myself… I study Computers as a profession![/]

"@
)

Get-SpectreImageExperimental -ImagePath "$global:MediaRoot\oakfade.gif" -MaxWidth 40 -Alignment center
$panelPosition = $Host.UI.RawUI.CursorPosition

foreach($sentence in $sentences) {
    [Console]::SetCursorPosition($panelPosition.X, $panelPosition.Y)
    Write-SpectrePanel -Title "[white]Generic Experienced IT Wizard[/]" -Data $sentence -Expand -Border Rounded -Color "Grey89"
    [Console]::SetCursorPosition($Host.UI.RawUI.BufferSize.Width - 2, $Host.UI.RawUI.CursorPosition.Y - 1)
    Read-PresentationPause
}

$sentences2 = @(
@"

  [White]So your name is [white]Shaun[/]! This is your new team mate.
  His name is [DarkOrange]The 10x Engineer[/]![/]

"@,
@"

  [White][white]Shaun[/]! Your very own PowerShell legend is about to unfold!
  A world of dreams and adventures with PowerShell awaits! Let's go![/]

"@
)

[Console]::SetCursorPosition(0, 0)
Write-Host -NoNewline "`n"

Get-SpectreImageExperimental -ImagePath "$global:MediaRoot\oak2.png" -MaxWidth 80 -Alignment center
$panelPosition = $Host.UI.RawUI.CursorPosition

foreach($sentence in $sentences2) {
    [Console]::SetCursorPosition($panelPosition.X, $panelPosition.Y)
    Write-SpectrePanel -Title "[white]Generic Experienced IT Wizard[/]" -Data $sentence -Expand -Border Rounded -Color "Grey89"
    [Console]::SetCursorPosition($Host.UI.RawUI.BufferSize.Width - 2, $Host.UI.RawUI.CursorPosition.Y - 1)
    Read-PresentationPause
}
