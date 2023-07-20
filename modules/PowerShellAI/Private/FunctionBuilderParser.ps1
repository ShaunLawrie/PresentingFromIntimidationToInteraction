# Cached result of checking if PSScriptAnalyzer is installed
$script:ScriptAnalyzerAvailable = $null
# List of PSScriptAnalyzer rules to ignore when validating functions
$script:ScriptAnalyserIgnoredRules = @(
    "PSReviewUnusedParameter",
    "PSAvoidUsingWriteHost",
    "PSUseSingularNouns",
    "PSUseShouldProcessForStateChangingFunctions"
)
# ScriptAnalyzer rules to return custom error messages for rule names that match the keys of the hashtable because the default errors trip up LLM models
$script:ScriptAnalyserCustomRuleResponses = @{
    "PSAvoidOverwritingBuiltInCmdlets" = { "The name of the function is reserved, rename the function to not collide with internal PowerShell commandlets." }
    "PSUseApprovedVerbs" = { "The function name has to start with a valid PowerShell verb like $((Get-Verb | Where-Object { $_.Group -eq 'Common' } | Select-Object -ExpandProperty Verb) -join ', ')." }
    "*ShouldProcess*" = { "The function has to have the CmdletBinding SupportsShouldProcess and use a process block." }
}
# ScriptAnalyzer custom error messages for messages matching keys in the hashtable because the default errors trip up LLM models
$script:ScriptAnalyserCustomMessageResponses = @{
    "Script definition uses Write-Host*" = { "Avoid using Write-Host because it might not work in all hosts." }
    "*Unexpected attribute 'CmdletBinding'*" = { "CmdletBinding must be followed by a param block." }
    "*uses a plural noun*" = { "Function name can't be a plural$(Get-AifbUnavailableFunctionNames)" }
    "*':' was not followed by a valid variable name character*" = { 'A variable inside a PowerShell string cannot be followed by a colon, rewrite $foo: needs to be ${foo}: to delimit the variable.' }
}
# Simple functions that don't need named parameters to work out if they're being used correctly
$script:CommandletsExemptFromNamedParameters = @(
    "Write-Host",
    "Write-Output",
    "Write-Error",
    "Write-Warning",
    "Write-Verbose",
    "Where-Object",
    "ForEach-Object",
    "Write-Information",
    "Write-Verbose",
    "Select-Object",
    "Import-Module"
)
$script:UnavailableCommandletNames = @()

function Get-AifbUnavailableFunctionNames {
    <#
        .SYNOPSIS
            Gets a list of function names that have already been attempted that do not work.
    #>
    if($script:UnavailableCommandletNames.Count -gt 0) {
        return " (other unavailable names are $(($script:UnavailableCommandletNames | Group-Object | Select-Object -ExpandProperty "Name") -join ', '))"
    } else {
        return ""
    }
}

function Test-AifbScriptAnalyzerAvailable {
    <#
        .SYNOPSIS
            Checks if PSScriptAnalyzer is available on this system and uses a cached response to avoid using get-module all the time.
    #>
    if($null -eq $script:ScriptAnalyzerAvailable) {
        if(Get-Module "PSScriptAnalyzer" -ListAvailable -Verbose:$false) {
            $script:ScriptAnalyzerAvailable = $true
        } else {
            Add-AifbLogMessage -Level "WRN" -Message "This module performs better if you have PSScriptAnalyzer installed" -NoRender
            $script:ScriptAnalyzerAvailable = $false
        }
    }

    return $script:ScriptAnalyzerAvailable
}

function Write-AifbFunctionParsingOutput {
    <#
        .SYNOPSIS
            Writes parsing output to the output stream and also to the renderer log output as errors.
    #>
    param (
        # The message to log and format
        [string] $Message,
        [object] $Extent,
        [int] $Line
    )
    Add-AifbLogMessage -Level "ERR" -Message $Message
    return @{
        Line = $Line
        Extent = $Extent
        Message = " - $Message"
    }
}

function Write-AifbScriptAnalyzerOutput {
    <#
        .SYNOPSIS
            This function will analyze the function text and return the error details for the first line with errors.
    #>
    param (
        # A function in a text format to be formatted
        [string] $FunctionText
    )
    $scriptAnalyzerOutput = Invoke-ScriptAnalyzer -ScriptDefinition $FunctionText `
        -Severity @("Warning", "Error", "ParseError") `
        -ExcludeRule $script:ScriptAnalyserIgnoredRules `
        -Verbose:$false

    if($null -ne $scriptAnalyzerOutput) {
        $brokenLines = $scriptAnalyzerOutput | Group-Object Line

        # This originally returned the whole list of errors but it was too much for the LLM to understand, just return the errors for the first line with issues and then fix other errors on future iterations
        $firstBrokenLine = $brokenLines[0]
        $brokenLineErrors = $firstBrokenLine.Group.Message
        $ruleNames = $firstBrokenLine.Group.RuleName

        # Write the first custom error message that matches and violated PSScriptAnalyzer rules
        foreach($ruleResponse in $script:ScriptAnalyserCustomRuleResponses.GetEnumerator()) {
            if($ruleNames | Where-Object { $_ -like $ruleResponse.Key }) {
                Write-AifbFunctionParsingOutput -Message (Invoke-Command $ruleResponse.Value) -Line $firstBrokenLine.Name
                return
            }
        }

        # Write the first custom error message that matches and violated PSScriptAnalyzer message
        foreach($messageResponse in $script:ScriptAnalyserCustomMessageResponses.GetEnumerator()) {
            if($brokenLineErrors | Where-Object { $_ -like $messageResponse.Key }) {
                Write-AifbFunctionParsingOutput -Message (Invoke-Command $messageResponse.Value) -Line $firstBrokenLine.Name
                return
            }
        }

        # Otherwise dump the raw error messages
        $brokenLineErrors | ForEach-Object {
            Write-AifbFunctionParsingOutput -Message $_ -Line $firstBrokenLine.Name
        }
    }
}

function Find-AifbCommandletOnline {
    <#
        .SYNOPSIS
            Finds a commandlet online and installs he module it belongs to if the user wants to.

        .EXAMPLE
            Find-AifbCommandletOnline -CommandletName "Get-AzActivityLog"
    #>
    param (
        # The name of the commandlet to find online
        [string] $CommandletName
    )
    $command = $null
    $onlineModules = Find-Module -Command $CommandletName -Verbose:$false
    $localModules = Get-Module -ListAvailable -Verbose:$false
    if($onlineModules) {
        $matchingLocalModules = (Compare-Object -ReferenceObject $onlineModules.Name -DifferenceObject $localModules.Name -ExcludeDifferent).InputObject
        if($matchingLocalModules) {
            try {
                Import-Module $matchingLocalModules -Global -ErrorAction "Stop"
                $command = Get-Command $CommandletName -ErrorAction "Stop"
                return $command
            } catch {
                Write-Warning "Couldn't import command from local module '$($matchingLocalModules)'"
            }
        }

        Write-Host "There are modules online that include the function '$CommandletName' used by ChatGPT. To validate the usage of commandlets in the function the module needs to be installed locally.`n"
        Write-Host ($onlineModules | Select-Object Name, ProjectUri | Out-String).Trim()
        while($null -eq $command) {
            $onlineModuleToInstall = Read-Host "`nEnter the name of one of the modules to install or press enter to get ChatGPT to try use a different command"
            if(![string]::IsNullOrEmpty($onlineModuleToInstall)) {
                Install-Module -Name $onlineModuleToInstall.Trim() -Scope CurrentUser -Verbose:$false
                Import-Module -Name $onlineModuleToInstall.Trim() -Global -Verbose:$false
                $command = Get-Command $CommandletName
                Write-Host ""
            } else {
                Write-Host "Asking ChatGPT to use another command instead of installing the module for '$CommandletName'."
                break
            }
        }
    } else {
        Write-Verbose "No commands matching the name '$CommandletName' were available online."
    }
    return $command
}

function Test-AifbFunctionParsing {
    <#
        .SYNOPSIS
            This function tests the quality of a PowerShell function using PSScriptAnalyzer module.

        .DESCRIPTION
            The Test-AifbFunctionParsing function checks the quality of a PowerShell script by using the PSScriptAnalyzer module.
            If any errors or warnings are detected, the function outputs a list of lines containing errors and their corresponding error messages.
            If the module is not installed, the function silently bypasses script quality validation because it's not critical to the operation of the AI Script Builder.
    #>
    param (
        # A function in a text format to be tested
        [string] $FunctionText
    )

    $scriptAst = [System.Management.Automation.Language.Parser]::ParseInput($FunctionText, [ref]$null, [ref]$null)
    $functions = $scriptAst.FindAll({$args[0].GetType().Name -eq "FunctionDefinitionAst"}, $true)

    foreach($function in $functions) {
        if(Get-Command $function.Name -ErrorAction "SilentlyContinue") {
            Write-AifbFunctionParsingOutput -Message "The name of the function is reserved, rename the function to not collide with common function names$(Get-AifbUnavailableFunctionNames)." -Line $function.Extent.StartLineNumber
            $script:UnavailableCommandletNames += $FunctionName.Text
        }
    }

    foreach($function in $functions) {
        if($function.Name -notlike "*-*") {
            Write-AifbFunctionParsingOutput -Message "The name of the function should follow the PowerShell format of Verb-Noun$(Get-AifbUnavailableFunctionNames)." -Line $function.Extent.StartLineNumber
            $script:UnavailableCommandletNames += $FunctionName.Text
        }
    }

    if(Test-AifbScriptAnalyzerAvailable) {
        Write-Verbose "Using PSScriptAnalyzer to validate script quality"
        Write-AifbScriptAnalyzerOutput -FunctionText $FunctionText
    } else {
        Add-AifbLogMessage -Level "WRN" -Message "PSScriptAnalyzer is not installed so falling back on parsing directly with PS internals."
        try {
            [scriptblock]::Create($FunctionText) | Out-Null
        } catch {
            $innerExceptionErrors = $_.Exception.InnerException.Errors
            if($innerExceptionErrors) {
                Write-AifbFunctionParsingOutput -Message $innerExceptionErrors[0].Message -Line 1
            } else {
                Write-AifbFunctionParsingOutput -Message "The script is invalid because of a $($_.FullyQualifiedErrorId)." -Line 1
            }
        }
    }
}

function Test-AifbFunctionCommandletUsage {
    <#
        .SYNOPSIS
            This function tests the usage of commandlets in a PowerShell script.

        .DESCRIPTION
            The Test-AifbFunctionCommandletUsage function checks the usage of commandlets in a PowerShell script by analyzing the Abstract Syntax Tree (AST) of the script.
            For each commandlet found in the script, the function checks whether the commandlet is valid and whether any of the commandlet parameters are invalid.

        .EXAMPLE
            $FunctionText = Get-Content -Path "C:\Scripts\MyScript.ps1" -Raw
            Test-AifbFunctionCommandletUsage -ScriptAst $scriptAst

            This example tests the usage of commandlets in a PowerShell script.
        .NOTES
            This could likely be converted to a set of PSScriptAnalyzer custom rules https://learn.microsoft.com/en-us/powershell/utility-modules/psscriptanalyzer/create-custom-rule?view=ps-modules
    #>
    param (
        # A function in a text format to be tested
        [string] $FunctionText
    )

    $scriptAst = [System.Management.Automation.Language.Parser]::ParseInput($FunctionText, [ref]$null, [ref]$null)

    $commandlets = $scriptAst.FindAll({$args[0].GetType().Name -eq "CommandAst"}, $true)
    $functions = $scriptAst.FindAll({$args[0].GetType().Name -eq "FunctionDefinitionAst"}, $true)

    # Validate each commandlet and return on the first error found because telling the LLM about too many errors at once results in unpredictable fixes
    foreach($commandlet in $commandlets) {
        $commandletName = $commandlet.CommandElements[0].Value
        $commandletParameterNames = $commandlet.CommandElements.ParameterName
        $commandletParameterElements = @()
        $hasPipelineInput = $null -ne $commandlet.Parent -and $commandlet.Parent.GetType().Name -eq "PipelineAst" -and $commandlet.Parent.PipelineElements.Count -gt 1
        $extent = $commandlet.Extent
        if($commandlet.CommandElements.Count -gt 1) {
            $commandletParameterElements = $commandlet.CommandElements[1..($commandlet.CommandElements.Count - 1)]
        }

        if($functions.Name -contains $commandletName) {
            Add-AifbLogMessage -Message "This function calls one of its own functions."
            continue
        }

        $command = Get-Command $commandletName -ErrorAction "SilentlyContinue"
        
        # Check online if no local command is found
        if($null -eq $command) {
            $command = Find-AifbCommandletOnline -CommandletName $commandletName
        }

        if($null -eq $command) {
            Write-AifbFunctionParsingOutput -Message "The commandlet $commandletName cannot be found, use a different command or add another function to implement the logic$(Get-AifbUnavailableFunctionNames)." -Extent $extent
            $script:UnavailableCommandletNames += $commandletName
            return
        }
        
        # Check for missing parameters
        foreach($param in $commandletParameterNames) {
            if(![string]::IsNullOrEmpty($param)) {
                if(!$command.Parameters.ContainsKey($param)) {
                    Write-AifbFunctionParsingOutput -Message "The commandlet $commandletName does not take a parameter named $param, available parameters are $($command.Parameters.Keys -join ', ')." -Extent $extent
                    return
                }
            }
        }

        # Check for unnamed parameters, these are harder to validate and makes a generated script less obvious as to what it does
        if($commandletParameterElements.Count -gt 0 -and $script:CommandletsExemptFromNamedParameters -notcontains $commandletName -and $commandletName -like "*-*") {
            # Ignoring splatting
            if($commandletParameterElements[0] -like "@*") {
                continue
            }

            $previousElementWasParameterName = $false
            foreach($element in $commandletParameterElements) {
                if($element.GetType().Name -eq "CommandParameterAst") {
                    $previousElementWasParameterName = $true
                } else {
                    if(!$previousElementWasParameterName) {
                        Write-AifbFunctionParsingOutput -Message "Use a named parameter when passing $element to $commandletName." -Extent $extent
                        return
                    }
                    $previousElementWasParameterName = $false
                }
            }
        }

        # Check named parameters haven't been specified more than once
        $duplicateParameters = $commandletParameterNames | Group-Object | Where-Object { $_.Count -gt 1 } 
        foreach($duplicateParameter in $duplicateParameters) {
            Write-AifbFunctionParsingOutput -Message "The parameter $($duplicateParameter.Name) cannot be provided more than once to $commandletName." -Extent $extent
            return
        }
        
        # Check at least one parameter set is satisfied if all parameters to this commandlet have been specified by name
        $availableParameterSets = @()
        if($script:CommandletsExemptFromNamedParameters -notcontains $commandletName -and $commandletName -like "*-*") {
            $parameterSetSatisfied = $false
            if($command.ParameterSets.Count -eq 0) {
                $parameterSetSatisfied = $true
            } else {
                foreach($parameterSet in $command.ParameterSets) {
                    $mandatoryParameters = $parameterSet.Parameters | Where-Object { $_.IsMandatory }
                    $availableParameterSets += "$($parameterSet.Name) ($($mandatoryParameters.Name -join ', '))"
                    $mandatoryParametersUsed = [array]($mandatoryParameters | Where-Object { $commandletParameterNames -contains $_.Name }).Name
                    if($hasPipelineInput -and ($mandatoryParameters | Where-Object { $_.ValueFromPipeline })) {
                        $mandatoryParametersUsed += "Pipeline Input"
                    }
                    if($mandatoryParametersUsed.Count -ge $mandatoryParameters.Count) {
                        Write-Verbose "Parameter set $($parameterSet.Name) was satisfied"
                        $parameterSetSatisfied = $true
                        break
                    } else {
                        Write-Verbose "Parameter set $($parameterSet.Name) wasn't satisfied, expected $($mandatoryParameters.Count) but found $($mandatoryParametersUsed.Count)"
                    }
                }
            }
            if(!$parameterSetSatisfied) {
                Write-AifbFunctionParsingOutput -Message "Parameter set cannot be resolved using the specified named parameters for $commandletName, available parameter sets are $($availableParameterSets -join ', ')." -Extent $extent
                return
            }
        }

        # Check if types are real
        if("Add-Type" -eq $commandletName) {
            $commandletParameterElementsText = $commandletParameterElements.Extent.Text
            $typeNameIndex = $commandletParameterElementsText.IndexOf('-AssemblyName') + 1
            if($typeNameIndex -gt 0 -and $commandletParameterElementsText.Count -gt $typeNameIndex) {
                $typeName = $commandletParameterElements.Extent.Text[$typeNameIndex] -replace "(^['`"]|['`"]`$)", ""
                Write-Verbose "Checking type '$typeName' exists for Add-Type"
                $typeSections = $typeName -split "\."
                for($i = ($typeSections.Length - 1); $i -ge 0; $i--) {
                    $assembly = $typeSections[0..$i] -join "."
                    try {
                        Add-Type -AssemblyName $assembly -ErrorAction Stop
                        return
                    } catch {
                        Add-AifbLogMessage -Level "WRN" -Message "Failed to Add-Type '$assembly'."
                    }
                }
                Write-AifbFunctionParsingOutput "Failed to Add-Type '$typeName', the type doesn't exist." -Extent $extent
                return
            }
        }
        if("New-Object" -eq $commandletName) {
            $commandletParameterElementsText = $commandletParameterElements.Extent.Text
            $typeNameIndex = $commandletParameterElementsText.IndexOf('-TypeName') + 1
            if($typeNameIndex -gt 0 -and $commandletParameterElementsText.Count -gt $typeNameIndex) {
                $typeName = $commandletParameterElements.Extent.Text[$typeNameIndex] -replace "(^['`"]|['`"]`$)", ""
                Write-Verbose "Checking type '$typeName' exists for New-Object"

                $builtinType = [System.Management.Automation.PSTypeName]"$typeName"
                if($null -ne $builtinType.Type) {
                    Write-Verbose "Built-in type found"
                    return
                }

                $typeSections = $typeName -split "\."
                for($i = ($typeSections.Length - 1); $i -ge 0; $i--) {
                    $assembly = $typeSections[0..$i] -join "."
                    try {
                        Add-Type -AssemblyName $assembly -ErrorAction Stop
                        return
                    } catch {
                        Add-AifbLogMessage -Level "WRN" -Message "Failed to Add-Type '$assembly'."
                    }
                }
                Write-AifbFunctionParsingOutput "Failed to find type for New-Object -TypeName '$typeName', the type doesn't exist." -Extent $extent
                return
            }
        }
    }
}

function Test-AifbFunctionStaticMethodUsage {
    <#
        .SYNOPSIS
            This function tests the usage .net class static methods.

        .PARAMETER FunctionText
            Specifies the text content of the PowerShell script to be tested.

        .NOTES
            This could likely be converted to a set of PSScriptAnalyzer custom rules https://learn.microsoft.com/en-us/powershell/utility-modules/psscriptanalyzer/create-custom-rule?view=ps-modules
    #>
    param (
        # A function in a text format to be tested
        [string] $FunctionText
    )

    $scriptAst = [System.Management.Automation.Language.Parser]::ParseInput($FunctionText, [ref]$null, [ref]$null)

    $staticMemberCalls = $scriptAst.FindAll({$args[0].Static -eq $true}, $true)

    # Validate each commandlet and return on the first error found because telling the LLM about too many errors at once results in unpredictable fixes
    foreach($memberCall in $staticMemberCalls) {
        $className = $memberCall.Expression.TypeName.FullName
        $memberName = $memberCall.Member.Value
        $arguments = $memberCall.Arguments
        $extent = $memberCall.Extent
        
        $instance = Invoke-Expression "[$className]" -ErrorAction "SilentlyContinue"
        $instanceMembers = $instance | Get-Member -Static -ErrorAction "SilentlyContinue" | Where-Object { $_.Name -eq $memberName }

        if(!$instance) {
            Write-AifbFunctionParsingOutput "The class $className doesn't exist." -Extent $extent
            return
        }
        
        if(!$instanceMembers) {
            Write-AifbFunctionParsingOutput "The member $memberName doesn't exist on $className." -Extent $extent
            return
        }

        if($instanceMembers[0].MemberType -eq "Property") {
            Write-Verbose "Member is a property"
            return
        }

        if($memberName -eq "new") {
            $constructorArgCounts = ($instance.GetConstructors() | Foreach-Object { $_.GetParameters().Count } | Group-Object).Name
            if($constructorArgCounts -notcontains $arguments.Count) {
                Write-AifbFunctionParsingOutput "There is no constructor for $className that takes $($arguments.Count) parameters." -Extent $extent
                return
            } else {
                Write-Verbose "Constructor is correct"
                return
            }
        }

        $methods = $instanceMembers | Where-Object { $_.MemberType -eq "Method" }
        $methodDefinitions = $methods.Definition -split "static [a-z\.]+ " | Where-Object { ![string]::IsNullOrWhiteSpace($_) }
        $foundMethodDefinitionThatHasCorrectArgNumber = $false
        foreach($methodDefinition in $methodDefinitions) {
            $possibleMethodArgs = @()
            if($methodDefinition -notlike "*()*") {
                $possibleMethodArgs = ($methodDefinition | Select-String "\((.+)\)").Matches.Groups[1].Value
                $possibleMethodArgs = $possibleMethodArgs -split "," | ForEach-Object { $_.Trim() }
            }
            if($arguments.Count -eq $possibleMethodArgs.Count) {
                Write-Verbose "Found a static method that takes the correct number of arguments"
                $foundMethodDefinitionThatHasCorrectArgNumber = $true
                break
            }
        }
        if(!$foundMethodDefinitionThatHasCorrectArgNumber) {
            Write-AifbFunctionParsingOutput "The method $memberName doesn't take $($arguments.Count) arguments." -Extent $extent
            return
        }
    }
}