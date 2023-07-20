param (
    [int] $TargetFps = 30
)

function Get-LastKeyPressed {
    if([Console]::KeyAvailable) {
        $key = $null
        while([Console]::KeyAvailable) {
            $key = [Console]::ReadKey($true)
        }
        return $key
    } else {
        return $null
    }
}

function Test-Collision {
    param (
        [string] $Direction,
        [int] $StepSize
    )
    switch($Direction) {
        "LeftArrow" {
            # collide with grass on left because I cbf re-rendering when the character steps on it
            $grassWidth = 24
            if(($script:CharacterPosition.NextX - $script:XStepSize) -lt $grassWidth) {
                return $true
            } else {
                return $false
            }
        }
        "RightArrow" {
            # collide with right hand side of the screen
            if(($script:CharacterPosition.NextX + $script:XStepSize) -gt ($script:Width - ($script:XStepSize))) {
                return $true
            } else {
                return $false
            }
        }
        "UpArrow" {
            # collide with buildings at the top of the screen but allow to pass through the door to the gym
            $buildingHeight = 24
            if(($script:CharacterPosition.NextY - $script:YStepSize) -lt $buildingHeight) {
                if($script:CharacterPosition.NextX -eq 88 -and !$script:CharacterPosition.Hidden) {
                    if($script:CharacterPosition.NextY -lt 16) {
                        $script:CharacterPosition.Hidden = $true
                    }
                    return $false
                }
                return $true
            } else {
                return $false
            }
        }
        "DownArrow" {
            # collide with buildings at the top of the screen
            if((($script:CharacterPosition.NextY + $script:YStepSize) / 2) -ge $script:Height - 1) {
                return $true
            } else {
                return $false
            }
        }
    }
    return $false
}

function Write-BackgroundColor {
    param (
        [int] $X,
        [int] $Y,
        [int] $Width = 16,
        [int] $Height = 16
    )
    $terminalY = $Y / 2
    if($X -lt 0 -or $Y -lt 0 -or $terminalY -ge $script:Height) {
        return
    }
    $terminalHeight = $Height / 2
    $blockMaxHeight = $script:Height - $terminalY
    $blockHeight = [math]::Min($terminalHeight, $blockMaxHeight)
    $backgroundBuffer = "`e[38;2;$($script:BackgroundColor.R);$($script:BackgroundColor.G);$($script:BackgroundColor.B)m"
    $backgroundBuffer += "`e[48;2;$($script:BackgroundColor.R);$($script:BackgroundColor.G);$($script:BackgroundColor.B)m"
    for($i = 0; $i -lt $blockHeight; $i++) {
        if($X -gt 0) {
            $backgroundBuffer += "$([char]27)[${X}C"
        }
        $backgroundBuffer += $("x" * $Width) + "`n"
    }
    $backgroundBuffer = $backgroundBuffer.Trim()
    $backgroundBuffer += "$([char]27)[0m"

    [Console]::SetCursorPosition(0, $terminalY)
    [Console]::Write($backgroundBuffer)
}

function Test-CharacterMoved {
    return $script:CharacterPosition.PreviousX -ne $script:CharacterPosition.NextX -or $script:CharacterPosition.PreviousY -ne $script:CharacterPosition.NextY
}

function Write-Character {
    Write-Gym

    if($script:CharacterPosition.Hidden){
        return
    }
    
    [Console]::SetCursorPosition(0, [int]($script:CharacterPosition.PreviousY / 2))
    Get-SpectreImageExperimental -ImagePath "$global:MediaRoot\walking-character\$($script:CharacterPosition.Orientation)$($script:CharacterPosition.Frame).png" -XOffset $script:CharacterPosition.PreviousX -Resampler NearestNeighbor -BackgroundRgb $script:BackgroundColor -NoNewline

    $script:CharacterPosition.Frame = ($script:CharacterPosition.Frame + 1) % 2
    $blockX = -1
    $blockY = -1
    $blockWidth = 0
    $blockHeight = 0
    if($script:CharacterPosition.MovingDirection -eq "left") {
        $blockWidth = $script:XAnimationStepSize
        $blockHeight = $script:YStepSize
        $blockX = $script:CharacterPosition.PreviousX + $script:XStepSize
        $blockY = $script:CharacterPosition.PreviousY
    }
    if($script:CharacterPosition.MovingDirection -eq "right") {
        $blockWidth = $script:XAnimationStepSize
        $blockHeight = $script:YStepSize
        $blockX = $script:CharacterPosition.PreviousX - $script:XAnimationStepSize
        $blockY = $script:CharacterPosition.PreviousY
    }
    if($script:CharacterPosition.MovingDirection -eq "up") {
        $blockWidth = $script:XStepSize
        $blockHeight = $script:YAnimationStepSize
        $blockX = $script:CharacterPosition.PreviousX
        $blockY = $script:CharacterPosition.PreviousY + $script:XStepSize
    }
    if($script:CharacterPosition.MovingDirection -eq "down") {
        $blockWidth = $script:XStepSize
        $blockHeight = $script:YAnimationStepSize
        $blockX = $script:CharacterPosition.PreviousX
        $blockY = $script:CharacterPosition.PreviousY - $script:XAnimationStepSize
    }
    Write-BackgroundColor -X $blockX -Y $blockY -Width $blockWidth -Height $blockHeight
}

function Write-Gym {
    [Console]::SetCursorPosition(0, 0)
    Get-SpectreImageExperimental -ImagePath "$global:MediaRoot\gym.png" -Alignment "left" -Crop -Resampler NearestNeighbor -BackgroundRgb $script:BackgroundColor
}

function Write-Background {
    # Dump a background color to the terminal
    [Console]::SetCursorPosition(0, 0)
    $backgroundBuffer = [System.Text.StringBuilder]::new(($script:Width * $script:Height))
    $null = $backgroundBuffer.Append("`e[48;2;$($script:BackgroundColor.R);$($script:BackgroundColor.G);$($script:BackgroundColor.B)m$(" " * ($script:Width * $height))$([char]27)[0m")
    [Console]::Write($backgroundBuffer.ToString())

    # Dump the gym and grass
    Write-Gym
    Get-SpectreImageExperimental -ImagePath "$global:MediaRoot\gym-grass.png" -Alignment "left" -Crop -Resampler NearestNeighbor -BackgroundRgb $script:BackgroundColor -NoNewline
}

function Write-FadeOut {
    $top = 0
    $bottom = $Host.UI.RawUI.BufferSize.Height - 1
    $width = $Host.UI.RawUI.BufferSize.Width
    
    [Console]::CursorVisible = $false

    while($top -le $bottom) {
        [Console]::SetCursorPosition(0, $top)
        Write-Host -ForegroundColor Black -BackgroundColor Black ("X" * $width) -NoNewline
        [Console]::SetCursorPosition(0, $bottom)
        Write-Host -ForegroundColor Black -BackgroundColor Black ("X" * $width) -NoNewline
        $top++
        $bottom--
        Start-Sleep -Milliseconds 50
    }
    Clear-Host
}

[Console]::CursorVisible = $false
Clear-Host

# Script global parameters to avoid too much parameter passing overhead
$script:BackgroundColor = @{
    R = 222
    G = 255
    B = 222
}
$script:Width = $Host.UI.RawUI.BufferSize.Width
$script:Height = $Host.UI.RawUI.BufferSize.Height
# one step is half a sprite width, sprites are 16 pixels because it makes division easy without floats
# each pixel is rendered in one tall vertical character so we need to divide by 2 for height translations
$script:XStepSize = 16
$script:YStepSize = 16
$script:XAnimationStepSize = 4
$script:YAnimationStepSize = 4
# Initialise the character position to the middle bottom of the screen
$script:CharacterPosition = @{
    Orientation = "up"
    MovingDirection = "none"
    Frame = 0
    PreviousX = 24 # [int]($script:XStepSize * 2)
    PreviousY = [int](($script:Height * 2) - $script:YStepSize - 1)
    NextX = 24 #[int]($script:XStepSize * 2)
    NextY = [int](($script:Height * 2) - $script:YStepSize - 1)
    Hidden = $false
}

$targetLoopDurationMilliseconds = 1000 / $TargetFps
$startTime = Get-Date
$lastRender = (Get-Date).AddSeconds(-10)
$script:backgroundRefresh = $true
$firstFrame = $true
while (!$script:CharacterPosition.Hidden) {
    [Console]::CursorVisible = $false
    if($script:backgroundRefresh) {
        Write-Background
        $script:backgroundRefresh = $false
    }
    $key = Get-LastKeyPressed
    if($key.Key -eq "Q") {
        $script:CharacterPosition.Hidden = $true
    }

    if($global:AutoPlay) {
        $duration = (Get-Date) - $startTime
        if($duration.TotalSeconds -gt 30) {
            $script:CharacterPosition.Hidden = $true
        }
    }

    if($script:CharacterPosition.MovingDirection -eq "none") {
        if(-not (Test-Collision -Direction $key.Key)) {
            $targetDirection = $key.Key
            switch($targetDirection) {
                "LeftArrow" {
                    $script:CharacterPosition.Orientation = "left"
                    $script:CharacterPosition.MovingDirection = "left"
                    $script:CharacterPosition.NextX -= $script:XStepSize
                }
                "RightArrow" {
                    $script:CharacterPosition.Orientation = "right"
                    $script:CharacterPosition.MovingDirection = "right"
                    $script:CharacterPosition.NextX += $script:XStepSize
                }
                "UpArrow" {
                    $script:CharacterPosition.Orientation = "up"
                    $script:CharacterPosition.MovingDirection = "up"
                    $script:CharacterPosition.NextY -= $script:YStepSize
                }
                "DownArrow" {
                    $script:CharacterPosition.Orientation = "down"
                    $script:CharacterPosition.MovingDirection = "down"
                    $script:CharacterPosition.NextY += $script:YStepSize
                }
            }
        }
    }

    $sinceLastRender = New-TimeSpan -Start $lastRender -End (Get-Date)
    if($sinceLastRender.TotalMilliseconds -ge $targetLoopDurationMilliseconds) {
        $lastRender = Get-Date

        switch($script:CharacterPosition.MovingDirection) {
            "left" {
                if($script:CharacterPosition.PreviousX -gt $script:CharacterPosition.NextX) {
                    $script:CharacterPosition.PreviousX -= $script:XAnimationStepSize
                    $characterRefresh = $true
                } else {
                    $script:CharacterPosition.MovingDirection = "none"
                    $characterRefresh = $false
                }
            }
            "right" {
                if($script:CharacterPosition.PreviousX -lt $script:CharacterPosition.NextX) {
                    $script:CharacterPosition.PreviousX += $script:XAnimationStepSize
                    $characterRefresh = $true
                } else {
                    $script:CharacterPosition.MovingDirection = "none"
                    $characterRefresh = $false
                }
            }
            "up" {
                if($script:CharacterPosition.PreviousY -gt $script:CharacterPosition.NextY) {
                    $script:CharacterPosition.PreviousY -= $script:YAnimationStepSize
                    $characterRefresh = $true
                } else {
                    $script:CharacterPosition.MovingDirection = "none"
                    $characterRefresh = $false
                }
            }
            "down" {
                if($script:CharacterPosition.PreviousY -lt $script:CharacterPosition.NextY) {
                    $script:CharacterPosition.PreviousY += $script:YAnimationStepSize
                    $characterRefresh = $true
                } else {
                    $script:CharacterPosition.MovingDirection = "none"
                    $characterRefresh = $false
                }
            }
            default {
                if($firstFrame) {
                    $characterRefresh = $true
                    $firstFrame = $false
                } else {
                    $characterRefresh = $false
                }
            }
        }

        if($characterRefresh) {
            Write-Character
        }
    }
}
Write-Character
Write-FadeOut

$global:SlideSettings = @{
    SkipPresentationControls = $true
}