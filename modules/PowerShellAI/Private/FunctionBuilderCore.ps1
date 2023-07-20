# Settings that may need tweaking for new models
$script:OpenAISettings = @{
    MaxTokens = 2048
    # The model is setup in Initialize-AifbFunction
    Model = $null
    # The codewriter is the system used to generate the first instance of the function
    CodeWriter = @{
        SystemPrompt = "You are a bot who is an expert in PowerShell and respond to all questions with PowerShell code contained in a ``````powershell code fence. You know that valid PowerShell functions always start with a verb prefix like Add, Clear, Close, Copy, Enter, Exit, Find, Format, Get, Hide, Join, Lock, Move, New, Open, Optimize, Push, Pop, Redo, Remove, Rename, Reset, Resize, Search, Select, Set, Show, Skip, Split,
        Step, Switch, Undo, Unlock or Watch. You do not use splatting for commandlet parameters."
        Temperature = 0.7
    }
    # The codeeditor alters the first instance of the code to meet new requirements
    CodeEditor = @{
        SystemPrompt = "You are a bot who is an expert in PowerShell and respond to all questions with the code fixed based on the requests made in the chat. You respond with the code in a ``````powershell code fence and if the code has no issues you return the original code. You do not use splatting for commandlet parameters."
        Temperature = 0.3
        Prompts = @{
            SyntaxCorrection = @'
Fix all of these PowerShell issues in the code below:
{0}

```powershell
{1}
```
'@
        }
    }
    # The semantic reinforcement system is used to check the code meets the requirements of the original prompt
    SemanticReinforcement = @{
        SystemPrompt = "You are a bot who is an expert in PowerShell and you respond to all questions with only the word YES if the PowerShell functions provided meet the requirements specified or you reply with a corrected version of the PowerShell functions rewritten in their entirety inside a ``````powershell code fence."
        Temperature = 0.0
        Prompts = @{
            Reinforcement = @'
Respond with YES if the PowerShell functions below meet the requirement: {0}.
If they don't meet ALL requirements then rewrite the function so that it does and explain what was missing.

```powershell
{1}
```
'@
            FollowUp = "What would the functions look like if they were fixed?"
        }
    }
}

# Not sure if there will be multiple ways functions will be rendered in responses from the LLM
$script:FunctionExtractionPatterns = @(
    @{
        Regex = '(?s)(function\s+([a-z0-9\-]+)\s*\{.+})'
        FunctionNameGroup = 2
        FunctionBodyGroup = 1
    }
)

function Get-AifbUserAction {
    <#
        .SYNOPSIS
            A prompt for AIFunctionBuilder to allow the user to choose what to do with the final function output
    #>

    $actions = @(
        New-Object System.Management.Automation.Host.ChoiceDescription '&Save', 'Save this function to your local filesystem'
        New-Object System.Management.Automation.Host.ChoiceDescription '&Run', 'Save this function to a temporary location on your local filesystem and load it into this PowerShell session to be run'
        New-Object System.Management.Automation.Host.ChoiceDescription '&Copy', 'Copy the function to your clipboard'
        New-Object System.Management.Automation.Host.ChoiceDescription '&Edit', 'Request changes to this function'
        New-Object System.Management.Automation.Host.ChoiceDescription 'E&xplain', 'Explain why this function works'
        New-Object System.Management.Automation.Host.ChoiceDescription '&Quit', 'Exit AIFunctionBuilder'
    )

    $response = $Host.UI.PromptForChoice($null, "What do you want to do?", $actions, 5)

    return $actions[$response].Label -replace '&', ''
}

function Save-AifbFunctionOutput {
    <#
        .SYNOPSIS
            Prompt the user for a destination to save their script output and save it to disk, this uses psm1 files because they're easier to load into the function builder.
    #>
    param (
        # The name of the function to be tested
        [string] $FunctionName,
        # A function in a text format to be formatted
        [string] $FunctionText,
        # The prompt used to create the function
        [string] $Prompt
    )

    $suggestedFilename = "$FunctionName.psm1"

    $powershellAiDirectory = Join-Path ([Environment]::GetFolderPath("MyDocuments")) "PowerShellAI"
    $defaultFile = Join-Path $powershellAiDirectory $SuggestedFilename
    $suffix = 1
    while((Test-Path -Path $defaultFile) -and $suffix -le 10) {
        $defaultFile = $defaultFile -replace '[0-9]+\.ps1$', "$suffix.ps1"
        $suffix++
    }

    while($true) {
        $finalDestination = Read-Host -Prompt "Enter a location to save or press enter for the default ($defaultFile)"
        if([string]::IsNullOrEmpty($finalDestination)) {
            $finalDestination = $defaultFile
            if(!(Test-Path $powershellAiDirectory)) {
                New-Item -Path $powershellAiDirectory -ItemType Directory -Force | Out-Null
            }
        }

        if(Test-Path $finalDestination) {
            Write-Error "There is already a file at '$finalDestination'"
        } else {
            Set-Content -Path $finalDestination -Value "<#`n$Prompt`n#>`n`n$FunctionText"
            Write-Output $finalDestination
            break
        }
    }
}

function Remove-AifbComments {
    <#
        .SYNOPSIS
            Removes comments from a string of PowerShell code.

        .EXAMPLE
            PS C:\> Remove-AifbComments "function foo { # comment 1 `n # comment 2 `n return 'bar' }"
            function foo {  `n  `n return 'bar' }
    #>
    param (
        # A function in a text format to have comments stripped
        [Parameter(ValueFromPipeline = $true)]
        [string] $FunctionText
    )

    process {
        $tokens = @()

        [System.Management.Automation.Language.Parser]::ParseInput($FunctionText, [ref]$tokens, [ref]$null) | Out-Null

        $comments = $tokens | Where-Object { $_.Kind -eq "Comment" }

        # Strip comments from bottom to top to preserve extent offsets
        $comments | Sort-Object { $_.Extent.StartOffset } -Descending | ForEach-Object {
            $preComment = $FunctionText.Substring(0, $_.Extent.StartOffset)
            $postComment = $FunctionText.Substring($_.Extent.EndOffset, $FunctionText.Length - $_.Extent.EndOffset)
            $FunctionText = $preComment + $postComment
        }

        return $FunctionText
    }
}

function ConvertTo-AifbFunction {
    <#
        .SYNOPSIS
            Converts a string containing a function into a hashtable with the function name and body
        .EXAMPLE
            ConvertTo-AifbFunction "This funtion writes 'bar' to the terminal function Get-Foo { Write-Host 'bar' }"
            Would return:
            @{
                Name = "Get-Foo"
                Body = "function Get-Foo { Write-Host 'bar' }"
            }
    #>
    [CmdletBinding()]
    param (
        # Some text that contains a function name and body to extract
        [Parameter(ValueFromPipeline = $true)]
        [string] $Text,
        [string] $FallbackText
    )
    process {
        foreach($pattern in $script:FunctionExtractionPatterns) {
            if($Text -match $pattern.Regex) {
                return @{
                    Name = $Matches[$pattern.FunctionNameGroup]
                    Body = ($Matches[$pattern.FunctionBodyGroup] -replace '(?s)```.+', '' | Format-AifbFunction)
                }
            }
        }
        
        if($FallbackText) {
            Add-AifbLogMessage -Level "WRN" -Message "There is no function in this PowerShell code block: $Text"
            foreach($pattern in $script:FunctionExtractionPatterns) {
                if($FallbackText -match $pattern.Regex) {
                    return @{
                        Name = $Matches[$pattern.FunctionNameGroup]
                        Body = ($Matches[$pattern.FunctionBodyGroup] -replace '(?s)```.+', '' | Format-AifbFunction)
                    }
                }
            }
        }

        #Write-Error "There is no function in the PowerShell code block returned by the LLM or in the fallback text provided as a backup. LLM: [$Text]`nFallback: [$FallbackText]" -ErrorAction "Stop"
    }
}

function Format-AifbFunction {
    <#
        .SYNOPSIS
            Strip all comments from a PowerShell code block and use PSScriptAnalyzer to format the script if it's available
    #>
    param (
        # A function in a text format to be formatted
        [Parameter(ValueFromPipeline = $true)]
        [string] $FunctionText
    )

    process {
        Write-Verbose "Input function input:`n$FunctionText"

        # Remove all comments because the comments can skew the LLMs interpretation of the code
        $FunctionText = $FunctionText | Remove-AifbComments
        
        # Remove empty lines to save space in the rendering window
        $FunctionText = ($FunctionText.Split("`n") | Where-Object { ![string]::IsNullOrWhiteSpace($_) }) -join "`n"
        
        if(Test-AifbScriptAnalyzerAvailable) {
            $FunctionText = Invoke-Formatter -ScriptDefinition $FunctionText -Verbose:$false
        }

        Write-Verbose "Output function:`n$FunctionText"

        return $FunctionText
    }
}

function Test-AifbFunctionSyntax {
    <#
        .SYNOPSIS
            This function tests a PowerShell script for quality and commandlet usage issues.

        .DESCRIPTION
            The Test-AifbFunctionSyntax function checks a PowerShell script for quality and commandlet usage issues by
            checking that the script:
             - Uses valid syntax
             - All commandlets are used and the correct parameters are used.
            For the first line with issues, the function returns a ChatGPT prompt that requests the LLM to perform corrections for the issues.
            Only the first line is returned because asking ChatGPT or other LLM models to do multiple things at once tends to result in pretty mangled code.

        .EXAMPLE
            $FunctionText = @"
            function Get-RunningServices { Get-Service | Where-Object {$_.Status -eq "Running"} | Sort-Object -Property Name }
            "@
            $originalPrompt = "Some Prompt"
            Test-AifbFunctionSyntax -FunctionText $FunctionText

            This example tests the specified PowerShell script for quality and commandlet usage issues. If any issues are found, the function returns a prompt for corrections.
    #>
    param (
        # A function in a text format to be formatted
        [string] $FunctionText
    )

    $issuesToCorrect = @()

    # Check syntax errors
    $issuesToCorrect += Test-AifbFunctionParsing -FunctionText $FunctionText

    # Only check commandlet usage if there are no syntax errors
    if($issuesToCorrect.Count -eq 0) {
        $issuesToCorrect += Test-AifbFunctionCommandletUsage -FunctionText $FunctionText
    }

    # Only check static function usage if there are no syntax errors
    if($issuesToCorrect.Count -eq 0) {
        $issuesToCorrect += Test-AifbFunctionStaticMethodUsage -FunctionText $FunctionText
    }

    # Extract extents to highlight
    $extents = $issuesToCorrect.Extent

    # Extract lines to highlight
    $lines = $issuesToCorrect.Line | Group-Object | Select-Object -ExpandProperty Name

    # Deduplicate issue messages
    $issuesToCorrect = $issuesToCorrect.Message | Group-Object | Select-Object -ExpandProperty Name

    if($issuesToCorrect.Count -gt 0) {
        return @{
            Lines = $lines
            Extents = $extents
            IssuesToCorrect = ($issuesToCorrect -join "`n")
        }
    } else {
        Write-Verbose "The script has no issues to correct"
        return @{
            Lines = @()
            Extents = @()
            IssuesToCorrect = $null
        }
    }
}

function Get-AifbSemanticFailureReason {
    <#
        .SYNOPSIS
            This function takes a chat GPT response that contains code and a reason for failing function semantic validation and returns just the reason.
    #>
    param (
        # The text response from ChatGPT format.
        [Parameter(ValueFromPipeline = $true)]
        [string] $Text
    )

    $result = $Text.Trim() -replace '(?i)NO(\.|,)?\s+', ''
    $result = $result -replace '(?s)\s+(Here is |Here''s |The function should be rewritten|The corrected).+', ''
    $result = $result -replace '(?s)```.+', ''

    if([string]::IsNullOrWhiteSpace($result)) {
        Write-Error "A reason for failure is required"
    }

    return $result
}

function Write-AifbChat {
    <#
        .SYNOPSIS
            Write the latest chat log for debugging
    #>
    param ()
    Get-ChatMessages | ForEach-Object {
        Write-Host -NoNewline "$($_.role): "
        Write-Host -ForegroundColor DarkGray $_.content
    }
}

function Get-GPT4CompletionWithRetries {
    <#
        .SYNOPSIS
            TODO This is a workaround for rate limiting until https://github.com/dfinke/PowerShellAI/issues/107 is fixed.
    #>
    param (
        [string] $Content
    )

    $attempts = 0
    $maxAttempts = 5

    while($attempts -lt $maxAttempts) {
        $attempts++
        Write-Verbose "Trying to get AI completion attempt number $attempts"
        $response = Get-GPT4Completion -Content $Content -ErrorAction "SilentlyContinue"
        if([string]::IsNullOrWhiteSpace($response)) {
            $delayInSeconds = 10 * [math]::Pow(2, $attempts)
            Add-AifbLogMessage -Level "WRN" -Message "Rate limited by the AI API, trying again in $delayInSeconds seconds."
            Start-Sleep -Seconds $delayInSeconds
            continue
        } else {
            return $response
        }
    }

    Write-Error "Ran out of retries after $maxRetries attempts trying to talk to the AI API."
}

function Test-AifbFunctionSemantics {
    <#
        .SYNOPSIS
            This function takes a the text of a function and the original prompt used to generate it and checks that the code will achieve the goals of the original prompt.
    #>
    param (
        # The original prompt used to generate the code provided as FunctionText
        [string] $Prompt,
        # The function as text generated by the prompt
        [string] $FunctionText
    )

    Set-ChatSessionOption `
        -model $script:OpenAISettings.Model `
        -max_tokens $script:OpenAISettings.MaxTokens `
        -temperature $script:OpenAISettings.SemanticReinforcement.Temperature | Out-Null
    New-Chat -Content $script:OpenAISettings.SemanticReinforcement.SystemPrompt | Out-Null
    
    $attempts = 0
    $maxAttempts = 4

    while($attempts -lt $maxAttempts) {
        $attempts++

        Add-AifbLogMessage "Waiting for AI to validate semantics for prompt '$Prompt'."
        $response = Get-GPT4CompletionWithRetries -Content ($script:OpenAISettings.SemanticReinforcement.Prompts.Reinforcement -f $Prompt, $FunctionText)
        $response = $response.Trim()

        if($response -match "(?i)\bYES\b") {
            Add-AifbLogMessage "The function meets the original intent of the prompt."
            return $FunctionText | ConvertTo-AifbFunction -FallbackText $FunctionText
        } else {
            try {
                Add-AifbLogMessage -Level "ERR" -Message ($response | Get-AifbSemanticFailureReason)
            } catch {
                Add-AifbLogMessage -Level "ERR" -Message "The function doesn't meet the original intent of the prompt."
            }
            try {
                return $response | ConvertTo-AifbFunction
            } catch {
                try {
                    Add-AifbLogMessage -Level "WRN" -Message "Following up with the AI because it didn't return any code."
                    $response = Get-GPT4CompletionWithRetries -Content $script:OpenAISettings.SemanticReinforcement.Prompts.FollowUp
                    return $response | ConvertTo-AifbFunction -FallbackText $FunctionText
                } catch {
                    Write-AifbChat
                    Write-Error "Failed to get something sensible out of ChatGPT, the chat log has been dumped above for debugging."
                }
            }
        }
    }
}

function Initialize-AifbFunction {
    <#
        .SYNOPSIS
            This function creates the first version of the code that will be used to start the function builder loop.
    #>
    param (
        # The prompt format is "Write a PowerShell function that will do something"
        [string] $Prompt,
        # The model to use for generating the function
        [string] $Model,
        # The initial function is usually what this would produce but you can provide your own starting point for the functionbuilder to iterate on
        [string] $InitialFunction
    )

    Write-Verbose "Getting initial powershell function with prompt '$Prompt'"
    Add-AifbLogMessage -NoRender "Built initial function version."

    $script:OpenAISettings.Model = $Model

    Set-ChatSessionOption `
        -model $script:OpenAISettings.Model `
        -max_tokens $script:OpenAISettings.MaxTokens `
        -temperature $script:OpenAISettings.CodeWriter.Temperature | Out-Null
    New-Chat -Content $script:OpenAISettings.CodeWriter.SystemPrompt -Verbose:$false | Out-Null

    if($InitialFunction) {
        return $InitialFunction | ConvertTo-AifbFunction
    } else {
        return Get-GPT4CompletionWithRetries -Content $Prompt | ConvertTo-AifbFunction
    }
}

function Optimize-AifbFunction {
    <#
        .SYNOPSIS
            This function takes a the text of a function and the original prompt used to generate it and iterates on it until it meets the intent
            of the original prompt and is also syntacticly correct.
    #>
    param (
        # The original prompt
        [string] $Prompt,
        # The initial state of the function
        [hashtable] $Function,
        # The maximum number of times to loop before giving up
        [int] $MaximumReinforcementIterations = 15,
        # A runtime error the function needs to fix
        [string] $RuntimeError,
        # Force semantic re-evaluation
        [switch] $Force,
        # Don't render partial functions
        [switch] $NonInteractive
    )

    $iteration = 1
    while ($true) {
        if($iteration -gt $MaximumReinforcementIterations) {
            Write-AifbChat
            Write-Error "A valid function was not able to generated in $MaximumReinforcementIterations iterations, try again with a higher -MaximumReinforcementIterations value or rethink the initial prompt to be more explicit" -ErrorAction "Stop"
        }
        
        Add-AifbLogMessage "Locally testing the syntax of the function."
        $corrections = Test-AifbFunctionSyntax -FunctionText $Function.Body

        if($RuntimeError -and $iteration -eq 1) {
            Add-AifbLogMessage -Level "ERR" -Message $RuntimeError
            $corrections.IssuesToCorrect = @($corrections.IssuesToCorrect, " - $RuntimeError") -join "`n"
        }
        
        if($corrections.IssuesToCorrect -or ($Force -and $iteration -eq 1)) {
            if($corrections.IssuesToCorrect) {
                Write-AifbFunctionOutput -FunctionText $Function.Body -Prompt $Prompt -HighlightExtents $corrections.Extents -HighlightLines $corrections.Lines
                Add-AifbLogMessage "Waiting for AI to correct any issues present in the script."
                Set-ChatSessionOption -model $script:OpenAISettings.Model `
                    -max_tokens $script:OpenAISettings.MaxTokens `
                    -temperature $script:OpenAISettings.CodeEditor.Temperature | Out-Null
                New-Chat -Content $script:OpenAISettings.CodeEditor.SystemPrompt -Verbose:$false | Out-Null
                $Function = Get-GPT4CompletionWithRetries -Content ($script:OpenAISettings.CodeEditor.Prompts.SyntaxCorrection -f $corrections.IssuesToCorrect, $Function.Body) | ConvertTo-AifbFunction -FallbackText $Function.Body
                Write-AifbFunctionOutput -FunctionText $Function.Body -Prompt $Prompt
            }

            $Function = Test-AifbFunctionSemantics -FunctionText $Function.Body -Prompt $Prompt
            Write-AifbFunctionOutput -FunctionText $Function.Body -Prompt $Prompt
        } else {
            Add-AifbLogMessage "Function building is complete!"
            Write-AifbFunctionOutput -FunctionText $Function.Body -Prompt $Prompt
            Start-Sleep -Seconds 3
            break
        }

        $iteration++
    }

    return $Function
}