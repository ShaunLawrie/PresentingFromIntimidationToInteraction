# YOU'RE NOT SUPPOSED TO CREATE THESE IN POWERSHELL I JUST CAN'T BE BOTHERED REWRITING IT BEFORE THE PRESENTATION

using namespace System.Management.Automation.Subsystem.Feedback
using namespace System.Management.Automation.Subsystem
using namespace System.Threading

param (
    # Just unregister the implementation
    [switch] $Unregister
)

if($PSVersionTable.GitCommitId -notlike "7.4.0-preview.4-*") {
    throw "This module is only supported on PowerShell built from the branch https://github.com/ShaunLawrie/PowerShell/tree/configurable-feedbackprovider-timeouts"
}

class ModuleFeedback : IFeedbackProvider {
    
    [Guid] $Id
    [FeedbackTrigger] $Trigger
    [int] $TimeoutMilliseconds
    [string] $Name
    [string] $Description

    ModuleFeedback() {
        $this.Id = [Guid]::new("230e5ee4-afa8-4319-9492-88239003f0e5");
        $this.Trigger = [FeedbackTrigger]::CommandNotFound
        $this.TimeoutMilliseconds = 20000
        $this.Name = "modulefinder"
        $this.Description = "A feedback source for errors that uses PSGallery to offer modules for missing commands."
    }

    [FeedbackItem] GetFeedback([FeedbackContext] $context, [CancellationToken] $token) {
        if ($null -eq [runspace]::DefaultRunspace) {
            return $null
        }

        $commandName = $Error[0].Exception.CommandName
        $modules = Find-Module -Command $commandName

        $suggestions = [System.Collections.Generic.List[string]]::new()

        $currentModules = 0
        $maxModules = 5
        foreach($module in $modules) {
            if($currentModules -ge $maxModules) {
                break
            }
            $suggestions.Add("https://www.powershellgallery.com/packages/$($module.Name)")
            $currentModules++
        }

        $global:LASTSUGGESTIONS_MODULEFEEDBACK = $suggestions

        return [FeedbackItem]::new(
                "Available modules that contain the command '$commandName'",
                $suggestions,
                [FeedbackDisplayLayout]::Portrait
        )
    }
}

# Check if the provider is already registered
$provider = [ModuleFeedback]::new()
$existingRegistration = (Get-PSSubsystem -Kind "FeedbackProvider").Implementations | Where-Object {
    $_.Id -eq $provider.Id
}

# Re-add the provider to reflect code changes
if($null -ne $existingRegistration) {
    [SubsystemManager]::UnregisterSubsystem(
        [SubsystemKind]::FeedbackProvider,
        $provider.Id
    )
}
if(-not $Unregister) {
    [SubsystemManager]::RegisterSubsystem(
        [SubsystemKind]::FeedbackProvider,
        $provider
    )
    Write-Host -ForegroundColor Green "      Registered '$($provider.Name)' as a FeedbackProvider`n"
}

# Unregister builtin providers to avoid the race conditions
$defaultRegistration = [Guid]::new("a3c6b07e-4a89-40c9-8be6-2a9aad2786a4") 
$existingDefaultRegistration = (Get-PSSubsystem -Kind "FeedbackProvider").Implementations | Where-Object {
    $_.Id -eq $defaultRegistration
}
if($existingDefaultRegistration) {
    [SubsystemManager]::UnregisterSubsystem(
        [SubsystemKind]::FeedbackProvider,
        $defaultRegistration
    )
}