# YOU'RE NOT SUPPOSED TO CREATE THESE IN POWERSHELL I JUST CAN'T BE BOTHERED REWRITING IT BEFORE THE PRESENTATION

using namespace System.Management.Automation.Subsystem.Feedback
using namespace System.Management.Automation.Subsystem
using namespace System.Threading

param (
    # Just unregister the implementation
    [switch] $Unregister
)

class CmdletParamsFeedback : IFeedbackProvider {
    
    [Guid] $Id
    [FeedbackTrigger] $Trigger
    [int] $TimeoutMilliseconds
    [string] $Name
    [string] $Description

    CmdletParamsFeedback() {
        $this.Id = [Guid]::new("9a600dc5-40a5-4d70-b882-a9200d846642");
        $this.Trigger = [FeedbackTrigger]::Error
        $this.TimeoutMilliseconds = 500
        $this.Name = "cmdletparams"
        $this.Description = "A feedback source for errors that finds parameters that you could be after when you use one that doesn't exist."
    }

    [FeedbackItem] GetFeedback([FeedbackContext] $context, [CancellationToken] $token) {
        if ($null -eq [runspace]::DefaultRunspace) {
            return $null
        }

        if($context.LastError.Exception.Message -notmatch "A parameter cannot be found that matches parameter name '(.+?)'") {
            return $null
        }

        $unknownParam = $Matches[1]
        $unknownParamChars = $unknownParam.ToCharArray()

        $commandAst = $context.CommandLineAst.FindAll({
            $args[0].GetType().Name -eq "CommandAst" `
            -and `
            ($args[0].CommandElements | Where-Object { $_.GetType().Name -eq "CommandParameterAst" -and $_.ParameterName -eq $unknownParam })
        }, $true)
        $commandName = $commandAst.CommandElements[0].Value
        $commandDef = Get-Command $commandName

        $paramKeys = $commandDef.Parameters.Keys
        $paramStats = @{}

        foreach($key in $paramKeys) {
            $matchingChars = 0
            foreach($char in $unknownParamChars) {
                if($key -like "*$char*") {
                    $matchingChars++
                }
            }
            $paramStats[$key] = $matchingChars
        }

        $suggestions = [System.Collections.Generic.List[string]]::new()

        $maxParams = 5
        $suggestedParams = $paramStats.GetEnumerator() `
            | Sort-Object -Property Value -Descending `
            | Where-Object { $_.Value -gt 2 } `
            | Select-Object -ExpandProperty Name -First $maxParams

        foreach($param in $suggestedParams) {
            $matching = $commandDef.Parameters.GetEnumerator() | Where-Object { $_.Key -eq $param }
            $suggestions.Add("-$param <$($matching.Value.ParameterType.Name)>")
        }

        $global:LASTSUGGESTIONS_CMDLETPARAMSFEEDBACK = $suggestions

        if($suggestions.Count -eq 0) {
            return $null
        }

        return [FeedbackItem]::new(
                "Similar parameters for '$commandName' are:",
                $suggestions,
                [FeedbackDisplayLayout]::Portrait
        )
    }
}

# Check if the provider is already registered
$provider = [CmdletParamsFeedback]::new()
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