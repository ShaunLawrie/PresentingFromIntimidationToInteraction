$global:AutoPlay = $false
$script:AutoPlayDelay = 25
$script:AutoPlayPromptDelay = 60

function Set-PresentationConfig {
    param (
        [bool] $AutoPlay,
        [int] $AutoPlayDelay = $script:AutoPlayDelay,
        [int] $AutoPlayPromptDelay = $script:AutoPlayPromptDelay
    )
    if($AutoPlay) {
        $global:AutoPlay = $true
    }
    $script:AutoPlayDelay = $AutoPlayDelay
    $script:AutoPlayPromptDelay = $AutoPlayPromptDelay
}

function Start-PresentationPrompt {
    param (
        [string] $Prompt = 'function prompt { "`n  PS> " } ',
        [string] $Commands = ''
    )

    if($global:AutoPlay) {
        Start-Sleep -Seconds $AutoPlayPromptDelay
        return
    }

    if($env:USERNAME -notlike "*shaun*") {
        Write-SpectreHost "`n  [yellow]Type [gold1 rapidblink]exit[/] to escape the presentation terminal[/]"
    }
    if($global:DisablePrompt) {
        return
    }
    [Console]::CursorVisible = $true
    $command = $Prompt + $Commands
    pwsh.exe -NoProfile -NoLogo -NoExit -Command $command
}

function Write-PresentationMarginTop {
    param (
        [float] $MarginPercent = 0.2
    )
    Write-Host ("`n" * ($MarginPercent * $Host.UI.RawUI.BufferSize.Height))
}

function Read-PresentationPause {
    param (
        [switch] $Terminal,
        [string] $Prompt = "[White]Press the [$global:PresentationAccentColor rapidblink]ANY[/] key[/]"
    )
    $currentPosition = $Host.UI.RawUI.CursorPosition
    $rawPrompt = [Spectre.Console.Markup]::Remove($Prompt)

    if(!$Terminal) {    
        [Console]::CursorVisible = $false
        [Console]::SetCursorPosition(($Host.UI.RawUI.BufferSize.Width - $rawPrompt.Length) / 2, $Host.UI.RawUI.BufferSize.Height - 1)
        Write-SpectreHost $Prompt -NoNewline
    }
    
    Wait-ForKeyPress | Out-Null

    if(!$Terminal) {
        [Console]::SetCursorPosition(($Host.UI.RawUI.BufferSize.Width - $rawPrompt.Length) / 2, $Host.UI.RawUI.BufferSize.Height - 1)
        Write-SpectreHost (" " * $rawPrompt.Length) -NoNewline
    }

    [Console]::SetCursorPosition($currentPosition.X, $currentPosition.Y)
}

function Write-PresentationCodeBlockTabs {
    param (
        [array] $Titles,
        [int] $ActiveTab = 0,
        [int] $Padding = 0,
        [hashtable] $BackgroundRgb = @{ R = 15; G = 33; B = 43 }
    )
    for($p = 0; $p -lt $Padding; $p++) {
        Write-Host -NoNewline " "
    }
    for($t = 0; $t -lt $Titles.Count; $t++) {
        if($ActiveTab -eq $t) {
            Write-Host -NoNewline ("$([Char]27)[3m$([Char]27)[38;2;130;130;130m$([Char]27)[48;2;$($BackgroundRgb.R);$($BackgroundRgb.G);$($BackgroundRgb.B)m " + $Titles[$t] + " $([Char]27)[0m")
        } else {
            Write-Host -NoNewline ("$([Char]27)[3m$([Char]27)[38;2;80;80;80m$([Char]27)[48;2;5;13;13m " + $Titles[$t] + " $([Char]27)[0m")
        }
    }
    Write-Host ""
}

function Get-LastKeyPressed {

    if($global:AutoPlay) {
        Start-Sleep -Seconds $AutoPlayDelay
        return @{
            Key = "Enter"
        }
    }

    [Console]::TreatControlCAsInput = $true
    while([Console]::KeyAvailable) {
        $key = [Console]::ReadKey($true)
    }
    if($key.Key -eq "C" -and $key.Modifiers -contains "Control") {
        Write-Host ""
        throw "Presentation interrupted"
    }
    [Console]::TreatControlCAsInput = $false
    return $key
}

function Wait-ForKeyPress {

    if($global:AutoPlay) {
        Start-Sleep -Seconds $AutoPlayDelay
        return @{
            Key = "RightArrow"
        }
    }

    [Console]::TreatControlCAsInput = $true
    while([Console]::KeyAvailable) {
        $key = [Console]::ReadKey($true)
    }
    if($key.Key -eq "C" -and $key.Modifiers -contains "Control") {
        Write-Host ""
        throw "Presentation interrupted"
    }
    $key = [Console]::ReadKey($true)
    if($key.Key -eq "C" -and $key.Modifiers -contains "Control") {
        Write-Host ""
        throw "Presentation interrupted"
    }
    [Console]::TreatControlCAsInput = $false
    return $key
}

function Test-PresentationBuffer {
    param (
        [int] $MinimumWidth,
        [int] $MinimumHeight
    )

    [Console]::CursorVisible = $false

    $height = $Host.UI.RawUI.BufferSize.Height
    $width = $Host.UI.RawUI.BufferSize.Width
    $targetAspectRatio = [math]::Round($MinimumHeight / $MinimumWidth, 2)
    $aspectRatio = [math]::Round($height / $width, 2)

    # tests
    $acceptableWidth = $width -ge $MinimumWidth -and ($width - $MinimumWidth) -lt 10
    $acceptableHeight = $height -ge $MinimumHeight -and ($height - $MinimumHeight) -lt 10
    $acceptableRatio = [math]::Abs($aspectRatio - $targetAspectRatio) -lt 0.1

    # colors
    $barColor = "red"
    $barBackground = "black"
    $widthColor = "red"
    $heightColor = "red"
    $aspectRatioColor = "red"
    if($acceptableWidth) {
        $widthColor = "green"
    }
    if($acceptableHeight) {
        $heightColor = "green"
    }
    if($acceptableRatio) {
        $aspectRatioColor = "green"
    }
    if($acceptableWidth -and $acceptableHeight -and $acceptableRatio) {
        $barColor = "DarkGreen"
        $barBackground = "Green1"
    }

    Write-SpectreHost "[$barColor on $barBackground]$(([char]0x2580).ToString() * $width)[/]"
    0..5 | Foreach-Object {
        Write-Host (" " * $width)
    }
    Write-SpectreParagraph "Minimum height is '$MinimumHeight' actual is [$heightColor]'$height'[/]" -Alignment "center"
    Write-SpectreParagraph "Minimum width is '$MinimumWidth' actual is [$widthColor]'$width'[/]" -Alignment "center"
    Write-SpectreParagraph "Target aspect ratio is '$targetAspectRatio' actual is [$aspectRatioColor]'$aspectRatio'[/]" -Alignment "center"
    Write-Host (" " * $width)
    Write-SpectreParagraph ("The bar at the top and bottom should be solid and not have any gaps visible in it for images to render well") -Alignment "center"
    Write-Host (" " * $width)

    if($acceptableWidth -and $acceptableHeight -and $acceptableRatio) {
        Write-SpectreParagraph "Press [green rapidblink]ENTER[/] to start the presentation" $message -Alignment "center" -NoNewline
        $lastKey = Get-LastKeyPressed
        if($lastKey.Key -eq "Enter") {
            return $true
        }
    } else {
        Write-SpectreParagraph "Resize the window and adjust the zoom with [[Ctrl +]] or [[Ctrl -]]" $message -Alignment "center" -NoNewline
    }

    0..($height - $Host.UI.RawUI.CursorPosition.Y - 3) | Foreach-Object {
        Write-Host (" " * $width)
    }
    Write-SpectreHost "[$barColor on $barBackground]$(([char]0x2584).ToString() * $width)[/]" -NoNewline
}

function Write-PresentationCodeBlockTab {
    param (
        [string] $Title,
        [int] $Padding = 0,
        [hashtable] $BackgroundRgb = @{ R = 15; G = 33; B = 43 }
    )
    for($p = 0; $p -lt $Padding; $p++) {
        Write-Host -NoNewline " "
    }
    Write-Host ("$([Char]27)[3m$([Char]27)[38;2;130;130;130m$([Char]27)[48;2;$($BackgroundRgb.R);$($BackgroundRgb.G);$($BackgroundRgb.B)m " + $Title + " $([Char]27)[0m")
}

function Start-PresentationSleep {
    param (
        # 300 is about 10ms on my laptop
        [int] $Duration = 300
    )
    # Really bogus way of sleeping for durations shorter than "Start-Sleep -Milliseconds 1" will allow,
    # "Start-Sleep -Milliseconds 1" takes ~20ms because of some overhead. This func takes ~10ms on my laptop
    0..$Duration | Foreach-Object {
        $r = Get-Random -Minimum 0 -Maximum 1000
        $r | Out-Null
    }
}

function Write-PresentationTextStream {
    param (
        [string] $Text,
        [int] $Padding = 0,
        [int] $R = 231,
        [int] $G = 72,
        [int] $B = 86,
        [int] $Duration = 500,
        [switch] $Strikethrough,
        [switch] $NoNewline
    )
    $cursorVisibility = [Console]::CursorVisible
    [Console]::CursorVisible = $false
    for($p = 0; $p -lt $Padding; $p++) {
        Write-Host -NoNewline " "
    }

    $strikethroughChar = ""
    if($Strikethrough) {
        $strikethroughChar = "$([Char]27)[9m"
    }
    $foreground = "$([Char]27)[38;2;${R};${G};${B}m"
    $chars = @($strikethroughChar, $foreground)
    $chars += $Text.ToCharArray()
    $chars += "$([Char]27)[0m"
    if(-not $NoNewline) {
        $chars += "`n"
    }
    foreach($char in $chars) {
        [Console]::Write($char)
        Start-PresentationSleep -Duration $Duration
    }
    [Console]::CursorVisible = $cursorVisibility
}

function Read-PresentationControls {
    param (
        [int] $CurrentSlide,
        [int] $TotalSlides
    )

    $leftControl = " "
    if($CurrentSlide -gt 0) {
        $leftControl = "[$global:PresentationAccentColor]$([char]0x2190)[/]"
    }

    $rightControl = " "
    if($CurrentSlide -lt $TotalSlides) {
        $rightControl = "[$global:PresentationAccentColor]$([char]0x2192)[/]"
    }

    $remainingLinesInBuffer = $Host.UI.RawUI.BufferSize.Height - $Host.UI.RawUI.CursorPosition.Y - 1

    Write-Host ("`n" * $remainingLinesInBuffer) -NoNewline
    Write-SpectreParagraph "$leftControl $($CurrentSlide + 1)/$TotalSlides $rightControl" -Alignment "Center" -NoNewline
    
    $key = $null
    
    [console]::CursorVisible = $false
    
    do {
        $key = Wait-ForKeyPress
    } while (@("LeftArrow", "RightArrow") -notcontains $key.Key)

    [console]::CursorVisible = $true

    switch ($key.Key) {
        "LeftArrow" {
            return [math]::Max(0, $CurrentSlide - 1)
        }
        "RightArrow" {
            return [math]::Min($TotalSlides, $CurrentSlide + 1)
        }
    }
}

function Import-PresentationState {
    param (
        [string] $StatePath
    )
    try {
        return (Get-Content -Raw $StatePath -ErrorAction Stop | ConvertFrom-Json -AsHashtable)
    } catch {
        return @{
            StartDate = Get-Date
        }
    }
}

function Export-PresentationState {
    param (
        [string] $StatePath,
        [object] $State
    )
    [Console]::CursorVisible = $false
    Set-Content -Path $StatePath -Value ($State | ConvertTo-Json)
}