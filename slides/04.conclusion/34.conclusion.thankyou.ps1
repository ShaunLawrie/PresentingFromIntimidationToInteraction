$width = $Host.UI.RawUI.BufferSize.Width
$height = $Host.UI.RawUI.BufferSize.Height
$frames = 0

$script:OutputBuffer = $null
$script:Random = [System.Random]::new()

$buffer = Initialize-MatrixBuffer -Width $width -Height $height -ImagePath "$global:MediaRoot\red8.png"
$buffer = Add-MatrixTextToBuffer -X 0.37 -Y 0.5 -Text @("Thank you for listening! $([char]0x2665)") -Buffer $buffer
$buffer = Add-MatrixTextToBuffer -X 0.71 -Y 0.91 -Text @(" github.com/shaunlawrie", "twitter.com/shaun_lawrie", "  linked.in/shaunlawrie") -Buffer $buffer
Write-MatrixBuffer $buffer

Start-Sleep -Seconds 2
$targetTimeMs = 50
[Console]::CursorVisible = $false
[Console]::TreatControlCAsInput = $false
while($frames -le 420) {
    $start = Get-Date
    $buffer = Update-MatrixBuffer $buffer
    Write-MatrixBuffer $buffer
    $frames++
    $sleepDuration = [int]($targetTimeMs - ((Get-Date) - $start).TotalMilliseconds)
    if($sleepDuration -gt 20) {
        Start-Sleep -Milliseconds $sleepDuration
    }
}

[Console]::CursorVisible = $true