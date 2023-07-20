$script:Favicons = @{
    Edge = "$([char]0xdb80)$([char]0xdde9)"
    Atlassian = "$([char]0xdb82)$([char]0xdc04)"
}

function Write-BrowserChrome {
    param (
        [string] $Favicon = $script:Favicons.Atlassian,
        [string] $TabTitle,
        [string[]] $BackgroundTabTitles = @("Bing - How to pwsh", ".NET for dummies"),
        [string] $Url
    )

    # lolwtf
    $tabTop = $Host.UI.RawUI.CursorPosition.Y

    # First tab
    Write-SpectreHost "[grey23]$([char]0x0256D)$(([char]0x2500).ToString() * (4 + $TabTitle.Length))$([char]0x0256E)[/]"
    Write-SpectreHost "[grey23]$([char]0x2502) [/]" -NoNewline
    Write-Host -ForegroundColor Blue $Favicon -NoNewline
    Write-SpectreHost " $TabTitle [grey23]$([char]0x2502)[/]" -NoNewline
    $lastTabEnd = $Host.UI.RawUI.CursorPosition.X

    # Background tabs
    foreach($backgroundTabTitle in $BackgroundTabTitles) {
        [Console]::SetCursorPosition($lastTabEnd, $tabTop)
        Write-SpectreHost "[Grey15]$([char]0x0256D)$(([char]0x2500).ToString() * (4 + $TabTitle.Length))$([char]0x0256E)[/]"
        [Console]::SetCursorPosition($lastTabEnd, $tabTop + 1)
        Write-SpectreHost "[Grey15]$([char]0x2502)[/]" -NoNewline
        $backgroundTabTitle = $backgroundTabTitle.PadRight($TabTitle.Length)
        Write-SpectreHost " [Grey23]`u{f0219} $backgroundTabTitle[/] [Grey15]$([char]0x2502)[/]" -NoNewline
        $lastTabEnd = $Host.UI.RawUI.CursorPosition.X
    }

    [Console]::SetCursorPosition($Host.UI.RawUI.BufferSize.Width - 8, $Host.UI.RawUI.CursorPosition.Y)
    Write-Host " - $([char]0x25A1) " -NoNewline
    Write-Host -BackgroundColor Red " $([char]0x00D7) " -NoNewline
    Write-SpectreHost "[grey23 on black]$(([char]0x2584).ToString() * ($Host.UI.RawUI.BufferSize.Width))[/]"
    Write-SpectreHost "[default on grey23]  `u{1F808}  `u{1F80A}  `u{2B6F}  [/]" -NoNewline
    Write-SpectreHost "[black on grey23]$([char]0xE0B6)[/]" -NoNewline
    Write-SpectreHost "[default on black]$Url[/]" -NoNewline
    $positionX = $Host.UI.RawUI.CursorPosition.X
    Write-Host -BackgroundColor Black (" " * ($Host.UI.RawUI.BufferSize.Width - 2 - $positionX)) -NoNewline
    Write-SpectreHost "[black on grey23]$([char]0xE0B4) [/]"
    Write-SpectreHost "[grey23 on white]$(([char]0x2580).ToString() * ($Host.UI.RawUI.BufferSize.Width))[/]"
}