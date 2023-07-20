$script:OutputBuffer = $null
$script:Random = [System.Random]::new()
$script:Letters = "PowerShell-is-Awesome!%$([char]0x2665)"

function Read-SpectreImageIntoBuffer {
    param (
        [string] $ImagePath,
        [int] $MaxWidth,
        [ValidateSet("Bicubic", "NearestNeighbor")]
        [string] $Resampler = "Bicubic",
        [array] $Buffer
    )

    $backgroundColor = [System.Drawing.Color]::FromName([Console]::BackgroundColor)
    
    $image = [SixLabors.ImageSharp.Image]::Load($ImagePath)
    
    if($image.Width -gt $MaxWidth) {
        $scaledHeight = [int]($image.Height * ($MaxWidth / $image.Width))
        [SixLabors.ImageSharp.Processing.ProcessingExtensions]::Mutate($image, {
            param($context)
            [SixLabors.ImageSharp.Processing.ResizeExtensions]::Resize(
                $context,
                $MaxWidth,
                $scaledHeight,
                [SixLabors.ImageSharp.Processing.KnownResamplers]::$Resampler
            )
        })
    } else {
        $scaledHeight = $image.Height
        $MaxWidth = $image.Width
    }

    $frame = $image.Frames[0]
    $bufferY = $Buffer.Count - 5
    $leftPadding = $buffer[0].Count - $MaxWidth - 10
    for($y = $scaledHeight - 1; $y -gt 0; $y -= 2) {
        for($x = 0; $x -lt $MaxWidth; $x++) {
            $currentPixel = $frame[$x,$y]
            if($null -ne $currentPixel.A) {
                # Skip pixels that are mostly transparent
                if($currentPixel.A -lt 50) {
                    continue
                }

                # Quick-hack blending the foreground with the terminal background color. This could be done in imagesharp
                $foregroundMultiplier = $currentPixel.A / 255
                $backgroundMultiplier = 100 - $foregroundMultiplier
                $currentPixelRgb = @{
                    R = [math]::Min(255, ($currentPixel.R * $foregroundMultiplier + $backgroundColor.R * $backgroundMultiplier))
                    G = [math]::Min(255, ($currentPixel.G * $foregroundMultiplier + $backgroundColor.G * $backgroundMultiplier))
                    B = [math]::Min(255, ($currentPixel.B * $foregroundMultiplier + $backgroundColor.B * $backgroundMultiplier))
                }
            } else {
                $currentPixelRgb = @{
                    R = $currentPixel.R
                    G = $currentPixel.G
                    B = $currentPixel.B
                }
            }

            # Parse the image 2 vertical pixels at a time and use the lower half block character with varying foreground and background colors to
            # make it appear as two pixels within one character space
            $currentPixelString = ""
            if($image.Height -ge ($y + 1)) {
                $pixelBelow = $frame[$x,($y + 1)]
                # Skip pixels that are mostly transparent
                if($null -eq $pixelBelow) {
                    continue
                }

                if($null -ne $pixelBelow.A) {
                    # Skip pixels that are mostly transparent
                    if($pixelBelow.A -lt 50) {
                        continue
                    }
                    # Quick-hack blending the foreground with the terminal background color. This could be done in imagesharp
                    $foregroundMultiplier = $pixelBelow.A / 255
                    $backgroundMultiplier = 100 - $foregroundMultiplier
                    $pixelBelowRgb = @{
                        R = [math]::Min(255, ($pixelBelow.R * $foregroundMultiplier + $backgroundColor.R * $backgroundMultiplier))
                        G = [math]::Min(255, ($pixelBelow.G * $foregroundMultiplier + $backgroundColor.G * $backgroundMultiplier))
                        B = [math]::Min(255, ($pixelBelow.B * $foregroundMultiplier + $backgroundColor.B * $backgroundMultiplier))
                    }
                } else {
                    $pixelBelowRgb = @{
                        R = $pixelBelow.R
                        G = $pixelBelow.G - 120
                        B = $pixelBelow.B
                    }
                }

                $currentPixelString += "$([Char]27)[38;2;{0};{1};{2}m" -f $pixelBelowRgb.R, $pixelBelowRgb.G, $pixelBelowRgb.B
            }

            $currentPixelString += "$([Char]27)[48;2;{0};{1};{2}m$([Char]0x2584)$([Char]27)[0m" -f $currentPixelRgb.R, $currentPixelRgb.G, $currentPixelRgb.B

            $Buffer[$bufferY][($x + $leftPadding)].ImagePixel = $currentPixelString
        }
        $bufferY--
    }

    return $Buffer
}

function Initialize-MatrixBuffer {
    param (
        [int] $Width,
        [int] $height,
        [string] $ImagePath
    )

    $script:OutputBuffer = [System.Text.StringBuilder]::new(($width * $height))

    $buffer = @()
    for($r = 0; $r -lt $height; $r++) {
        $row = @()
        for($c = 0; $c -lt $width; $c++) {
            
            $row += @{
                Letter = [char]' '
                ImagePixel = $null
                Absorb = $false
                LetterIndex = $null
                Color = @{
                    R = 0
                    G = 0
                    B = 0
                }
            }
        }
        $buffer += ,$row
    }

    $buffer = Read-SpectreImageIntoBuffer -ImagePath $ImagePath -MaxWidth $Width -Buffer $buffer

    return $buffer
}

function Add-MatrixTextToBuffer {
    param (
        [float] $X,
        [float] $Y,
        [array] $Text,
        [object] $Buffer
    )

    $height = $Buffer.Count
    $width = $Buffer[0].Count

    $xPosition = [int]($width * $X)
    $yPosition = [int]($height * $Y)

    $line = $buffer[$yPosition]

    foreach($String in $Text) {
        for($c = 0; $c -lt $String.Length; $c++) {
            $char = $String[$c]
            $line[$xPosition + $c].ImagePixel = $char
            $line[$xPosition + $c].Absorb = $false
        }
        $line = $buffer[$yPosition + [int]++$lines]
    }

    return $Buffer
}

function Update-MatrixBuffer {
    param (
        [object] $Buffer
    )
    $lastRow = $Buffer.Count - 1
    for($r = $lastRow; $r -ge 0; $r--) {
        $row = $Buffer[$r]
        $width = $row.Count
        for($c = 0; $c -lt $width; $c++) {
            $currentCell = $row[$c]
            # Skip cells containing part of the image
            if($null -ne $currentCell.ImagePixel) {
                continue
            }
            # Create a char
            if($r -eq 0 -and $currentCell.Letter -eq ' ' -and $script:Random.Next(50) -eq 0) {
                $brightness = $script:Random.Next(120)
                $blueness = 25 + $script:Random.Next(110)
                $nextLetter = $script:Random.Next($script:Letters.Length)
                $currentCell.Letter = $script:Letters[$nextLetter]
                $currentCell.LetterIndex = $nextLetter
                $currentCell.Color = @{
                    R = $brightness
                    G = [int]($brightness + ($blueness / 2))
                    B = $brightness + $blueness
                }
            } else {
                # Shift an existing char down and leave a shadow
                if($r -lt $lastRow -and $null -ne $currentCell.Letter -and $currentCell.Letter -ne [char]' ') {
                    $nextLetter = ($currentCell.LetterIndex + 1) % $script:Letters.Length
                    # if there are image pixels below, flow the characters in a direction that makes sense
                    $nextRow = $r + 1
                    $nextCol = $c
                    $nextDirection = "down"
                    $skip = $false
                    if($Buffer[$nextRow][$nextCol].Absorb) {
                        $skip = $true
                    }
                    if($null -ne $Buffer[$nextRow][$nextCol].ImagePixel) {
                        $leftAvailable = $false
                        $rightAvailable = $false
                        if($null -eq $Buffer[$r][$nextCol-1].ImagePixel -and $Buffer[$r][$nextCol-1].Letter -eq [char]' ') {
                            $leftAvailable = $true
                        }
                        if($null -eq $Buffer[$r][$nextCol+1].ImagePixel -and $Buffer[$r][$nextCol+1].Letter -eq [char]' ') {
                            $rightAvailable = $true
                        }

                        if($leftAvailable -or $rightAvailable) {
                            if($script:Random.Next(2) -gt 0 -and $currentCell.Direction -eq "down") {
                                $skip = $true
                            } else {
                                if($leftAvailable -and $rightAvailable -and $currentCell.Direction -eq "down") {
                                    if($script:Random.Next(2) -gt 0) {
                                        $nextDirection = "left"
                                    } else {
                                        $nextDirection = "right"
                                    }
                                } elseif($leftAvailable -and $rightAvailable -and $currentCell.Direction -eq "left") {
                                    $nextDirection = "left"
                                } elseif($leftAvailable -and $rightAvailable -and $currentCell.Direction -eq "right") {
                                    $nextDirection = "right"
                                } elseif($leftAvailable) {
                                    $nextDirection = "left"
                                } elseif($rightAvailable) {
                                    $nextDirection = "right"
                                }

                                if($nextDirection -eq "left") {
                                    $nextRow = $r
                                    $nextCol = $nextCol - 1
                                    $nextDirection = "left"
                                } else {
                                    $nextRow = $r
                                    $nextCol = $nextCol + 1
                                    $nextDirection = "right"
                                }
                            }
                        } else {
                            $skip = $true
                        }
                    }
                    if(-not $skip) {
                        $Buffer[$nextRow][$nextCol] = @{
                            Letter = $script:Letters[$nextLetter]
                            LetterIndex = $nextLetter
                            Direction = $nextDirection
                            Color = @{
                                R = $currentCell.Color.R
                                G = $currentCell.Color.G
                                B = $currentCell.Color.B
                            }
                        }
                    }
                    $nextLetter = ($nextLetter - 1 -lt 0) ? $script:Letters.Length - 1 : $nextLetter - 1
                    $currentCell.Letter = $script:Letters[$nextLetter]
                    $currentCell.LetterIndex = $nextLetter
                    $currentCell.Color.R = [math]::Max($currentCell.Color.R - 10, 0)
                    $currentCell.Color.G = [math]::Max($currentCell.Color.G - 10, 0)
                    $currentCell.Color.B = [math]::Max($currentCell.Color.B - 10, 0)
                }
                # Remove invisible chars or flip letter
                if(($currentCell.Color.R + $currentCell.Color.G + $currentCell.Color.B) -lt 20) {
                    $currentCell.Letter = ' '
                }
            }
        }
    }
    return $Buffer
}

function Write-MatrixBuffer {
    param (
        [object] $Buffer
    )
    [Console]::CursorVisible = $false
    $height = $Buffer.Count
    $null = $outputBuffer.Clear()
    for($r = 0; $r -lt $height; $r++) {
        $row = $Buffer[$r]
        $width = $row.Count
        for($c = 0; $c -lt $width; $c++) {
            $currentCell = $row[$c]
            if($null -ne $currentCell.ImagePixel) {
                $null = $outputBuffer.Append($currentCell.ImagePixel)
            } else {
                $rgb = "$($currentCell.Color.R);$($currentCell.Color.G);$($currentCell.Color.B)"
                if($null -ne $Buffer[$r + 1] -and $Buffer[$r + 1][$c].Letter -eq [char]' ') {
                    $rgb = "$([math]::Min(255, $currentCell.Color.R + 60));$([math]::Min(255, $currentCell.Color.G + 60));$([math]::Min(255, $currentCell.Color.B + 90))"
                }
                $null = $outputBuffer.Append("$([char]27)[38;2;${rgb}m$($currentCell.Letter)$([char]27)[0m")
            }
        }
    }
    [Console]::SetCursorPosition(0, 0)
    [Console]::Write($outputBuffer.ToString())
}