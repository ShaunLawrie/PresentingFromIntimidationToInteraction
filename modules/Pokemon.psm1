function Invoke-PokemonSelection {
    # This is a fake menu, it will toggle up and down but enter always just progresses
    param (
        [array] $Choices = @("NEW CAREER", "OPTION")
    )

    function Write-SelectionPointer {
        param (
            [int] $SelectionIndex,
            [object] $CursorPosition
        )
        [Console]::SetCursorPosition($CursorPosition.X + 2, $CursorPosition.Y + $SelectionIndex + 1)
        Write-SpectreHost "[rapidblink]$([char]0x25B8)[/]"
    }

    $choiceText = ($Choices | Foreach-Object { "  $_" }) -join "`n"
    $cursorPosition = $Host.UI.RawUI.CursorPosition
    [Console]::CursorVisible = $false

    Write-SpectrePanel -Color Grey89 -Data $choiceText
    $key = $null
    $selectionIndex = 0
    while($key.Key -ne "Enter") {
        1..($Choices.Count) | Foreach-Object {
            [Console]::SetCursorPosition($cursorPosition.X + 2, $cursorPosition.Y + $_)
            Write-Host " "
        }
        if($key.Key -eq "DownArrow") {
            $selectionIndex = ($selectionIndex + 1) % $Choices.Count
        } elseif($key.Key -eq "UpArrow") {
            $selectionIndex = ($selectionIndex - 1) -lt 0 ? $Choices.Count - 1 : $selectionIndex - 1
        }
        Write-SelectionPointer -SelectionIndex $selectionIndex -CursorPosition $cursorPosition
        $key = Wait-ForKeyPress
    }
    return $Choices[$selectionIndex]
}

function Write-PokemonSpeechBubble {
    param (
        [string] $Text,
        [string] $CharacterName,
        [string] $Color = "Grey89",
        [string] $CharacterImage
    )

    [Console]::CursorVisible = $false
    $cursorPosition = $Host.UI.RawUI.CursorPosition
    Write-SpectrePanel -Color $Color -Data $Text -Title "[white] $CharacterName [/]" -Expand

    [Console]::SetCursorPosition($cursorPosition.X, $cursorPosition.Y)
    Get-SpectreImageExperimental -ImagePath $CharacterImage -MaxWidth 10 -Alignment "right"

    # redraw edge of panel as speech bubble
    $col = $Host.UI.RawUI.BufferSize.Width - 12
    $topRight = [char]0x0256E
    $bottomRight = "$([char]0x2534)$([char]0x2500)"
    $side = [char]0x2502
    $height = $Text.Split("`n").Count

    [Console]::SetCursorPosition($col, $cursorPosition.Y)
    Write-SpectreHost "[$Color]$topRight [/]"
    $i = 0
    for($i = 1; $i -le $height; $i++) {
        [Console]::SetCursorPosition($col, $cursorPosition.Y + $i)
        Write-SpectreHost "[$Color]$side [/]"
    }
    [Console]::SetCursorPosition($col, $cursorPosition.Y + $i)
    Write-SpectreHost "[$Color]$bottomRight[/]"
    Write-Host "  "
}

function Invoke-Evolution {
    param (
        [int] $FrameLimit = 50,
        [int] $BrightnessIncrement = 1,
        [int] $FrameRate = 20
    )

    $topPosition = $Host.UI.RawUI.CursorPosition.Y
    $width = $Host.UI.RawUI.BufferSize.Width
    $height = $Host.UI.RawUI.BufferSize.Height - $Host.UI.RawUI.CursorPosition.Y
    $bottomPanelHeight = 4
    $topPanelHeight = $height - $bottomPanelHeight - 1
    
    [Console]::CursorVisible = $false
    [Console]::SetCursorPosition(0, $topPosition + $topPanelHeight)
    Write-SpectrePanel -Color "Magenta2_1" -Data @'
What?
Shaun is evolving!
'@ -Expand
    
    $frames = @()
    $brightness = 10
    for($f = 0; $f -lt $frameLimit; $f++) {
        $char = [char]' '
        $buffer = [System.Text.StringBuilder]::new($Width * $Height)
        $buffer.Append("$([Char]27)[48;2;${brightness};${brightness};${brightness}m") | Out-Null
        for($r = 0; $r -lt $topPanelHeight; $r++) {
            for($c = 0; $c -lt $width; $c++) {
                $buffer.Append($char) | Out-Null
            }
        }
        $buffer.Append("$([Char]27)[0m") | Out-Null
        $frames += $buffer
        $brightness += $BrightnessIncrement
    }
    $targetDuration = 1000 / $FrameRate

    foreach($frame in $frames) {
        $date = Get-Date
        [Console]::SetCursorPosition(0, $topPosition)
        [Console]::Write($frame.ToString())
        $duration = (Get-Date) - $date
        $sleepTime = $targetDuration - $duration.TotalMilliseconds
        if($sleepTime -gt 20) {
            Start-Sleep -Milliseconds $sleepTime
        }
    }

    [Console]::SetCursorPosition(0, $topPosition + 2)
    $brightness -= $BrightnessIncrement
    Get-SpectreImageExperimental -ImagePath "$global:MediaRoot\evolution.gif" -MaxWidth 40 -Alignment "center" -BackgroundRgb @{ R = $brightness; G = $brightness; B = $brightness }
}
