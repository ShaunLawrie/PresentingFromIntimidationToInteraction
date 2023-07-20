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

class AiFeedback : IFeedbackProvider {
    
    [Guid] $Id
    [FeedbackTrigger] $Trigger
    [int] $TimeoutMilliseconds
    [string] $Name
    [string] $Description

    AiFeedback() {
        $this.Id = [Guid]::new("230e5ee4-afa8-4319-9492-88239003f0e6");
        $this.Trigger = [FeedbackTrigger]::Error
        $this.TimeoutMilliseconds = 20000
        $this.Name = "powershellai"
        $this.Description = "A feedback source for errors that uses PowerShell AI to offer suggested fixes."
    }

    [FeedbackItem] GetFeedback([FeedbackContext] $context, [CancellationToken] $token) {
        if ($null -eq [runspace]::DefaultRunspace) {
            return $null
        }

        $question = ""
        $response = ""
        try {
            Stop-Chat
            New-ChatSystemMessage -Content `
	    	"You are a powershell expert and you provide concise options as a list to work around a problem when given an error description"
            
	    $question = @"
What can I do about the command: $($context.CommandLine)
Failing with: $($context.LastError.Exception.Message)
"@

            $response = Get-GPT4Completion -Content $question
        } catch {
            Write-Warning "Failed to get a response from PowerShellAI"
        }

        $suggestions = [System.Collections.Generic.List[string]]::new()

        $responsePoints = @()
        try {
            $responsePoints = ($response | Select-String "(?m)^[0-9]+\.(.+)" -AllMatches).Matches.Value
        } catch {
            Write-Warning "Couldn't get any suggestions out of the PowerShellAI response"
        }
        $currentPoints = 0
        $maxPoints = 5
        foreach($point in $responsePoints) {
            if($currentPoints -ge $maxPoints) {
                break
            }
            $sanitizedPoint = $point.Trim() -replace '\*', ''
            $suggestions.Add($sanitizedPoint)
            $currentPoints++
        }

        $global:LASTSUGGESTIONS_AIFEEDBACK = $suggestions

        return [FeedbackItem]::new(
                "Fresh from the AI...",
                $suggestions,
                [FeedbackDisplayLayout]::Portrait
        )
    }
}

# Check if the provider is already registered
$provider = [AiFeedback]::new()
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
