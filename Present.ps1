[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '', Justification='PSNativeCommandUseErrorActionPreference is used internally')]
param (
    [int] $StartNumber = 0,
    [switch] $Resume,
    [switch] $SkipCalibration,
    [switch] $DisablePrompt,
    [bool] $AutoPlay = $false,
    [string] $StatePath = "$PSScriptRoot\state.json"
)

$ErrorActionPreference = "Stop"
if($env:USERNAME -like "*shaun*") {
    $global:PSNativeCommandUseErrorActionPreference = $false
    $env:WSL_UTF8=0
}

$global:ModulesRoot = "$PSScriptRoot\modules"

Import-Module "$global:ModulesRoot\PwshSpectreConsole\PwshSpectreConsole\PwshSpectreConsole.psm1" -Force
Import-Module "$global:ModulesRoot\PowerShellAI\PowerShellAI.psm1" -Force
Import-Module "$global:ModulesRoot\Matrix.psm1" -Force
Import-Module "$global:ModulesRoot\Pokemon.psm1" -Force
Import-Module "$global:ModulesRoot\Presentation.psm1" -Force
Import-Module "$global:ModulesRoot\PresentationWebServer.psm1" -Force
Import-Module "$global:ModulesRoot\Browser.psm1" -Force
Import-Module "$global:ModulesRoot\Twitter.psm1" -Force

$global:MediaRoot = "$PSScriptRoot\slides\media"
$global:CharacterImageOak = "$global:MediaRoot\character-oak.png"
$global:CharacterImage10x = "$global:MediaRoot\character-10x.png"
$global:CharacterImageShaun = "$global:MediaRoot\character-shaun.png"
$global:CharacterImageShaunOlder = "$global:MediaRoot\character-shaun-older.png"
$global:CharacterImageDev = "$global:MediaRoot\character-nurse.png"
$global:CharacterImageAi = "$global:MediaRoot\character-ai.png"
$global:CharacterImageFeedback = "$global:MediaRoot\character-feedback.png"
$global:PresentationAccentColor = "steelblue1"
$global:DisablePrompt = $DisablePrompt
$global:PresentationState = Import-PresentationState -StatePath $StatePath

Set-SpectreColors -AccentColor $global:PresentationAccentColor -DefaultValueColor "Grey"

$slides = Get-ChildItem -Path "$PSScriptRoot/slides" -Recurse -Filter "*.ps1" | Sort-Object Name

# Calibrate the terminal to fit the presentation correctly
Clear-Host
$calibrated = $SkipCalibration
while(!$calibrated) {
    [Console]::SetCursorPosition(0, 0)
    $calibrated = Test-PresentationBuffer -MinimumWidth 145 -MinimumHeight 40
    Start-Sleep -Milliseconds 150
}

Set-PresentationConfig -AutoPlay $AutoPlay

$slideNumber = $StartNumber
if($Resume) {
    if($global:PresentationState["LatestSlide"]) {
        $slideNumber = $global:PresentationState["LatestSlide"]
    }
}
while($slideNumber -lt $slides.Count) {
    [Console]::CursorVisible = $false
    $currentSlide = $slides[$slideNumber]
    if($previousSlideSettings.ClearBelowLine) {
        [Console]::SetCursorPosition(0, $previousSlideSettings.ClearBelowLine)
        $linesToClear = $Host.UI.RawUI.BufferSize.Height - $previousSlideSettings.ClearBelowLine
        1..$linesToClear | ForEach-Object {
            Write-Host -NoNewline (" " * $Host.UI.RawUI.BufferSize.Width)
        }
    }
    if($previousSlideSettings.Overwrite) {
        [Console]::SetCursorPosition(0, 0)
    } else {
        Clear-Host
    }

    $title = $null
    $activeSection = ($currentSlide.Name | Select-String "[0-9\.]+([a-z]+)").Matches.Groups[1].Value
    switch ($activeSection) {
        "intimidation" {
            $title = "Intimidation"
        }
        "interaction" {
            $global:PresentationAccentColor = "Magenta2_1"
            Set-SpectreColors -AccentColor $global:PresentationAccentColor -DefaultValueColor "Grey"
            $title = "Interaction"
        }
        "challenges" {
            $global:PresentationAccentColor = "Gold1"
            Set-SpectreColors -AccentColor $global:PresentationAccentColor -DefaultValueColor "Grey"
            $title = "Challenges"
        }
        default {
            # no section to write out
        }
    }

    if($null -ne $title) {
        Write-SpectreRule $title
    }

    $global:SlideSettings = @{}
    $ErrorActionPreference = "Continue"
    . $currentSlide.FullName
    $previousSlideSettings = $global:SlideSettings

    if($previousSlideSettings.SkipPresentationControls) {
        $slideNumber++
    } else {
        $slideNumber = Read-PresentationControls -CurrentSlide $slideNumber -TotalSlides $slides.Count
    }

    $global:PresentationState["LatestSlide"] = $slideNumber

    Export-PresentationState -StatePath $StatePath -State $global:PresentationState
}