
Write-Host ""
$selection = Invoke-PokemonSelection -Choices @(
    "CONTINUE            ",
    "NEW CAREER          ",
    "OPTION              "
)

if($selection -notlike "NEW CAREER*") {
    Write-SpectreParagraph "[yellow]Sorry this menu is just for presentation purposes, you have to start a new career...[/]" -Alignment "center" -Transparent
    Read-PresentationPause
}

$global:SlideSettings = @{
    SkipPresentationControls = $true
}