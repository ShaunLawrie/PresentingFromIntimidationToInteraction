function Test-VSCodeInstalled {
    <#
        .SYNOPSIS
        Test if VSCode is installed.

        .EXAMPLE
        Test-VSCodeInstalled
    #>

    $null -ne (Get-Command code -ErrorAction SilentlyContinue)
}

function CustomReadHost {
    <#
        .SYNOPSIS
        Custom Read-Host function that allows for a default value and a prompt message.

        .EXAMPLE
        CustomReadHost 
    #>

    $Run = New-Object System.Management.Automation.Host.ChoiceDescription '&Yes', 'Yes, run the code'
    $Explain = New-Object System.Management.Automation.Host.ChoiceDescription '&Explain', 'Explain the code'
    $Copy = New-Object System.Management.Automation.Host.ChoiceDescription '&Copy', 'Copy to clipboard'
    $VSCode = New-Object System.Management.Automation.Host.ChoiceDescription '&VSCode', 'Open in VSCode'
    $Quit = New-Object System.Management.Automation.Host.ChoiceDescription '&Quit', 'Do not run the code'

    $options = [System.Management.Automation.Host.ChoiceDescription[]]($Run, $Explain, $Copy, $VSCode, $Quit)
    
    if (Test-VSCodeInstalled) {
        $defaultChoice = 4
        $options = [System.Management.Automation.Host.ChoiceDescription[]]($Run, $Explain, $Copy, $VSCode, $Quit)
    }
    else {
        $defaultChoice = 3
        $options = [System.Management.Automation.Host.ChoiceDescription[]]($Run, $Explain, $Copy, $Quit)
    }

    $message = 'Run the code? You can also choose additional actions'
    $host.ui.PromptForChoice($null, $message, $options, $defaultChoice)
}