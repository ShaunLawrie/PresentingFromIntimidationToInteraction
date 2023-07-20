function Get-SpectreImageExperimental {
    param (
        [string] $ImagePath,
        [string] $Alignment = "left",
        [int] $XOffset = 0,
        [int] $MaxWidth,
        [switch] $Repeat,
        [ValidateSet("Bicubic", "NearestNeighbor")]
        [string] $Resampler = "Bicubic",
        [switch] $Crop,
        [switch] $NoNewline,
        [hashtable] $BackgroundRgb
    )

    $backgroundColor = [System.Drawing.Color]::FromName([Console]::BackgroundColor)
    if($BackgroundRgb) {
        $backgroundColor = [System.Drawing.Color]::FromArgb(255, $BackgroundRgb.R, $BackgroundRgb.G, $BackgroundRgb.B)
    }

    $hostWidth = $Host.UI.RawUI.BufferSize.Width
    $hostHeight = $Host.UI.RawUI.BufferSize.Height
    $startY = $Host.UI.RawUI.CursorPosition.Y
    
    $image = [SixLabors.ImageSharp.Image]::Load($ImagePath)
    if(-not $MaxWidth) {
        if(-not $Crop) {
            $MaxWidth = [math]::Min(($hostWidth - 1), $image.Width)
        } else {
            $MaxWidth = $image.Width
        }
    }
    $scaledHeight = [int]($image.Height * ($MaxWidth / $image.Width))
    if($image.Width -gt $MaxWidth) {
        [SixLabors.ImageSharp.Processing.ProcessingExtensions]::Mutate($image, {
            param($context)
            [SixLabors.ImageSharp.Processing.ResizeExtensions]::Resize(
                $context,
                $MaxWidth,
                $scaledHeight,
                [SixLabors.ImageSharp.Processing.KnownResamplers]::$Resampler
            )
        })
    }

    $frames = @()
    $buffer = [System.Text.StringBuilder]::new($MaxWidth * $scaledHeight * 2)

    foreach($frame in $image.Frames) {
        $frameDelayMilliseconds = 0
        try {
            $frameMetadata = [SixLabors.ImageSharp.MetadataExtensions]::GetGifMetadata($frame.Metadata)
            if($frameMetadata.FrameDelay) {
                # The delay is supposed to be in milliseconds and imagesharp seems to be a bit out when it decodes it
                $frameDelayMilliseconds = $frameMetadata.FrameDelay * 10
            }
        } catch {
            # Don't care
        }
        $buffer.Clear() | Out-Null
        # offset for alignment
        if($Alignment -eq "center") {
            $leftPadding = [int](($Host.UI.RawUI.BufferSize.Width - $MaxWidth) / 2)
        } elseif($Alignment -eq "right") {
            $leftPadding = [int]($Host.UI.RawUI.BufferSize.Width - $MaxWidth)
        } else {
            $leftPadding = $XOffset
        }
        for($y = 0; $y -lt $scaledHeight; $y += 2) {
            if($Crop -and $y -ge (($hostHeight - $startY) * 2)) {
                continue
            }
            if($leftPadding -gt 0) {
                $buffer.Append("$([char]27)[${leftPadding}C") | Out-Null
            }
            for($x = 0; $x -lt $MaxWidth; $x++) {
                if($Crop -and $x -ge $hostWidth) {
                    continue
                }
                $currentPixel = $frame[$x,$y]
                if($null -ne $currentPixel.A) {
                    # Quick-hack blending the foreground with the terminal background color. This could be done in imagesharp
                    $foregroundMultiplier = $currentPixel.A / 255
                    $backgroundMultiplier = 1 - $foregroundMultiplier
                    $currentPixelRgb = @{
                        R = [math]::Min(255, (($currentPixel.R * $foregroundMultiplier) + ($backgroundColor.R * $backgroundMultiplier)))
                        G = [math]::Min(255, (($currentPixel.G * $foregroundMultiplier) + ($backgroundColor.G * $backgroundMultiplier)))
                        B = [math]::Min(255, (($currentPixel.B * $foregroundMultiplier) + ($backgroundColor.B * $backgroundMultiplier)))
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
                if($image.Height -gt ($y + 1)) {
                    $pixelBelow = $frame[$x,($y + 1)]

                    if($null -ne $pixelBelow.A) {
                        # Quick-hack blending the foreground with the terminal background color. This could be done in imagesharp
                        $foregroundMultiplier = $pixelBelow.A / 255
                        $backgroundMultiplier = 1 - $foregroundMultiplier
                        $pixelBelowRgb = @{
                            R = [math]::Min(255, (($pixelBelow.R * $foregroundMultiplier) + ($backgroundColor.R * $backgroundMultiplier)))
                            G = [math]::Min(255, (($pixelBelow.G * $foregroundMultiplier) + ($backgroundColor.G * $backgroundMultiplier)))
                            B = [math]::Min(255, (($pixelBelow.B * $foregroundMultiplier) + ($backgroundColor.B * $backgroundMultiplier)))
                        }
                    } else {
                        $pixelBelowRgb = @{
                            R = $pixelBelow.R
                            G = $pixelBelow.G
                            B = $pixelBelow.B
                        }
                    }

                    $buffer.Append(("$([Char]27)[38;2;{0};{1};{2}m" -f
                        $pixelBelowRgb.R,
                        $pixelBelowRgb.G,
                        $pixelBelowRgb.B
                    )) | Out-Null
                } else {
                    $buffer.Append(("$([Char]27)[38;2;{0};{1};{2}m" -f
                        $backgroundColor.R,
                        $backgroundColor.G,
                        $backgroundColor.B
                    )) | Out-Null
                }

                $buffer.Append(("$([Char]27)[48;2;{0};{1};{2}m$([Char]0x2584)$([Char]27)[0m" -f
                    $currentPixelRgb.R,
                    $currentPixelRgb.G,
                    $currentPixelRgb.B
                )) | Out-Null
            }
            $buffer.AppendLine() | Out-Null
        }

        $bufferFrame = $buffer.ToString()
        if($NoNewline) {
            $bufferFrame = $buffer.ToString() -replace '\n$', ''
        }

        $frames += @{
            FrameDelayMilliseconds = $frameDelayMilliseconds
            Frame = $bufferFrame
        }
    }

    $topLeft = $Host.UI.RawUI.CursorPosition
    [Console]::CursorVisible = $false
    do {
        foreach($frame in $frames) {
            [Console]::SetCursorPosition($topLeft.X, $topLeft.Y)
            Write-Host $frame.Frame -NoNewline
            Start-Sleep -Milliseconds $frame.FrameDelayMilliseconds
        }
    } while ($Repeat)
    [Console]::CursorVisible = $true
}

function Get-SpectreImage {
    param (
        [string] $ImagePath,
        [int] $MaxWidth
    )
    $image = [Spectre.Console.CanvasImage]::new($ImagePath)
    if($MaxWidth) {
        $image.MaxWidth = $MaxWidth
    }
    [Spectre.Console.AnsiConsole]::Write($image)
}