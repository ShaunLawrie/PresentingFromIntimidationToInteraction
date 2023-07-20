function Write-Tweet {
    param (
        [string] $AuthorName,
        [string] $AuthorHandle,
        [string] $ImagePath,
        [string] $Content
    )

    $lines = $Content.Split("`n")
    $width = $Host.UI.RawUI.BufferSize.Width
    $longestLine = $lines | Measure-Object -Property Length -Maximum | Select-Object -ExpandProperty Maximum
    $imageSpace = 14
    $fullWidth = $longestLine + $imageSpace
    $leftPadding = [int](($width - $fullWidth) / 2)

    $twitter = "$([char]0xeb72)"

    Write-SpectreParagraph -Alignment "center" -ForegroundColor Blue "[DeepSkyBlue1]$twitter Twitter[/] - Home"

    #Write-Host ""
    #Write-Host -ForegroundColor DarkGray ((" " * ($leftPadding - 1)) + ("-" * ($fullWidth + 4)))

    Write-Host ""
    $yPosition = $Host.UI.RawUI.CursorPosition.Y
    Get-SpectreImageExperimental -ImagePath $ImagePath -MaxWidth 10 -Alignment "left" -XOffset $leftPadding
    
    [Console]::SetCursorPosition($leftPadding + $imageSpace, $yPosition)
    Write-Host "$AuthorName " -NoNewline
    Write-Host -ForegroundColor DarkGray "$AuthorHandle "

    for($i = 0; $i -lt $lines.Count; $i++) {
        [Console]::SetCursorPosition($leftPadding + $imageSpace, $yPosition + $i + 2)
        Write-SpectreHost $lines[$i] -NoNewline
    }

    [Console]::SetCursorPosition(0, $yPosition + $i + 3)
}