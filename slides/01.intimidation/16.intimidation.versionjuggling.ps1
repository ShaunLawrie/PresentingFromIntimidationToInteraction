[Console]::CursorVisible = $false

$isPresentation = $PSVersionTable.PSVersion.Major -gt 5

function Enter-WindowsPowerShell {
    if($PSVersionTable.PSVersion.Major -gt 5) {
        $script = "-File $($PSCommandPath -replace "^/mnt/([a-z])/", "`$1:/")"
        $argstring = ""
        $PsBoundParameters.GetEnumerator() | Foreach-Object {
            if($_.Value.GetType().Name -eq "SwitchParameter") {
                $argstring += " -$($_.Key)"
            } else {
                $argstring += " -$($_.Key):`"$($_.Value)`""
            }
        }
        Write-Verbose "Relaunching in PowerShell for Windows"
        Start-Process -FilePath "powershell.exe" `
                      -ArgumentList ($script + $argstring) `
                      -LoadUserProfile -UseNewEnvironment -NoNewWindow -Wait
        exit 0
    }
}

$codeblock = @'

  param (
    [string] $AppPoolName = "DemoAppPool"
  )

  # Make sure this runs in powershell.exe
  Enter-WindowsPowerShell

  # Disable idle timeout on an app pool
  Import-Module WebAdministration
  $appPool = Get-ChildItem IIS:\AppPools | Where-Object { $_.Name -eq $AppPoolName }
  $appPool.processModel.idleTimeout = [TimeSpan]::FromMinutes(0)
  $appPool | Set-Item
  Write-Host "Disabled idle timeout on '$($appPool.Name)' from PSv$($PSVersionTable.PSVersion.Major)"

'@

if($isPresentation) {
    [Console]::CursorVisible = $false

    Write-Host ""

    Write-PokemonSpeechBubble -CharacterName "10x Engineer" -CharacterImage $global:CharacterImage10x -Text @"
[White]I'm off to lunch now.
I need you to update the app pool configs on the dev server, the default site keeps going to sleep and people are complaining it's slow.
Use DisableIdleTimeout.ps1, It's in the shared docs on my PC.[/]
"@

    Write-PokemonSpeechBubble -CharacterName "Shaun" -CharacterImage $global:CharacterImageShaun -Color $global:PresentationAccentColor -Text @"
[White]Hey,
Is that it?
Oh they're gone. I guess I'll figure it out myself.[/]
"@

    Write-PresentationCodeBlockTabs @("DisableIdleTimeout.ps1", "DisableIdleTimeout2.ps1", "Enter-WindowsPowerShell.ps1") -ActiveTab 1 -Padding 3
    Write-CodeBlock -Text $codeblock -SyntaxHighlight -ShowLineNumbers -Theme "Presentation"
    $endOfCodeBlock = $Host.UI.RawUI.CursorPosition.Y

    Write-Host ""
    Write-SpectreHost "  PS> [yellow]./DisableIdleTimeout2.ps1[/]" -NoNewline
    Read-PresentationPause -Terminal
    Write-Host "`n"
}

Invoke-Expression $codeblock

$global:SlideSettings = @{
    ClearBelowLine = $endOfCodeBlock
    Overwrite = $true
}