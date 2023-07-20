function Invoke-AIFunctionBuilder {
    <#
        .SYNOPSIS
            Create a PowerShell function with the help of ChatGPT
        .DESCRIPTION
            Invoke-AIFunctionBuilder is a function that uses ChatGPT to generate an initial PowerShell function to achieve the goal defined
            in the prompt by the user but goes a few steps beyond the typical interaction with an LLM by auto-validating the result
            of the AI generated script using parsing techniques that feed common issues back to the model until it resolves them.
        .EXAMPLE
            PS>Invoke-AIFunctionBuilder
            # The function builder renders the UI and asks the user to enter a prompt to generate a function
        .EXAMPLE
            PS>Invoke-AIFunctionBuilder -Prompt "Write a powershell function that will show a date and time in timestamp form" -NonInteractive
            function Get-Timestamp {
                return (Get-Date).ToString("yyyy-MM-ddTHH:mm:ss.fffffZ")
            }
        .EXAMPLE
            PS>$function = 'function Write-Hello { Write-Output "hello world" }'
            PS>Invoke-AIFunctionBuilder -InitialFunction $function -Prompt "write a powershell function that says hello"
            # The function builder renders the UI and validates the function provided meets the goal of the prompt
        .NOTES
            Author: Shaun Lawrie / @shaun_lawrie
    #>
    [CmdletBinding(DefaultParameterSetName = 'Interactive')]
    [alias("ifb")]
    param(
        # A prompt in the format "Write a powershell function that will sing me happy birthday"
        [Parameter(ParameterSetName="Interactive", ValueFromPipeline = $true)]
        [Parameter(ParameterSetName="NonInteractive", ValueFromPipeline = $true, Mandatory=$true)]
        [string] $Prompt,
        # The maximum loop iterations to attempt to generate the function within
        [Parameter(ParameterSetName="Interactive")]
        [Parameter(ParameterSetName="NonInteractive")]
        [int] $MaximumReinforcementIterations = 15,
        # Return the code result without showing any interactions
        [Parameter(ParameterSetName="NonInteractive")]
        [switch] $NonInteractive,
        # The model to use
        [Parameter(ParameterSetName="Interactive")]
        [Parameter(ParameterSetName="NonInteractive")]
        [ValidateSet("gpt-3.5-turbo", "gpt-4")]
        [string] $Model = "gpt-3.5-turbo",
        # A seed function to use as the function builder starting point, this can allow you to iterate on an existing idea
        [Parameter(ParameterSetName="Interactive")]
        [Parameter(ParameterSetName="NonInteractive")]
        [string] $InitialFunction
    )

    $fullPrompt = $Prompt

    if(-not $NonInteractive) {
        Clear-Host
        $prePrompt = $null
        if([string]::IsNullOrEmpty($Prompt)) {
            $version = if($PSVersionTable.PSVersion.Major -gt 5) { "core" } else { $PSVersionTable.PSVersion.Major }
            $prePrompt = "Write a PowerShell $version function that will"
            Write-Host -ForegroundColor Cyan -NoNewline "${prePrompt}: "
            $Prompt = Read-Host
            if([string]::IsNullOrWhiteSpace($Prompt)) {
                Write-Host "No prompt was provided, I guess you're feeling lucky..."
                $Prompt = "do something"
            }
        }
        $fullPrompt = (@($prePrompt, $Prompt) | Where-Object { $null -ne $_ }) -join ' '
    }

    try {
        $function = Initialize-AifbFunction -Prompt $fullPrompt -Model $Model -InitialFunction $InitialFunction

        Initialize-AifbRenderer -InitialPrePrompt $prePrompt -InitialPrompt $Prompt -NonInteractive $NonInteractive
        Write-AifbFunctionOutput -FunctionText $function.Body -Prompt $fullPrompt

        $function = Optimize-AifbFunction -Function $function -Prompt $fullPrompt -Force:(![string]::IsNullOrWhiteSpace($InitialFunction))

        if($NonInteractive) {
            return $function.Body
        }

        Write-AifbFunctionOutput -FunctionText $function.Body -SyntaxHighlight -NoLogMessages -Prompt $fullPrompt

        $finished = $false
        while(-not $finished) {
            $action = Get-AifbUserAction -Function $function

            switch($action) {
                "Edit" {
                    $editPrePrompt = "`nI also want the function to"
                    Write-Host -ForegroundColor Cyan -NoNewline "${editPrePrompt}: "
                    $editPrompt = Read-Host
                    Write-Verbose "Re-running function optimizer with a request to edit functionality: '$editPrompt'"
                    $fullPrompt = (@($fullPrompt, $editPrompt) | Where-Object { ![string]::IsNullOrWhiteSpace($_) }) -join ' and the function must '
                    Write-AifbFunctionOutput -FunctionText $function.Body -Prompt $fullPrompt
                    $function = Optimize-AifbFunction -Function $function -Prompt $fullPrompt -RuntimeError "The function does not meet all conditions in the prompt ($fullPrompt)."
                    Write-AifbFunctionOutput -FunctionText $function.Body -SyntaxHighlight -NoLogMessages -Prompt $fullPrompt
                }
                "Copy" {
                    Set-Clipboard -Value $function.Body
                    Write-Host "The function code has been copied to your clipboard!"
                    if($IsLinux) {
                        Write-Warning "This might not work under WSL, you can try the 'Save' option to save the function to your local filesystem instead."
                    }
                    Write-Host ""
                }
                "Explain" {
                    $explanation = (Get-GPT3Completion -prompt "Explain how the function below meets all of the requirements the following requirements, list the requirements and how each is met in a numbered list. Also provide a summary of what the function can do.`nRequirements: $fullPrompt`n`n``````powershell`n$($function.Body)``````" -max_tokens 2000).Trim()
                    Write-AifbFunctionOutput -FunctionText $function.Body -SyntaxHighlight -NoLogMessages -Prompt $fullPrompt
                    Write-Host $explanation
                    Write-Host ""
                }
                "Run" {
                    $tempFile = New-TemporaryFile
                    $tempFilePsm1 = "$($tempFile.FullName).psm1"
                    Set-Content -Path $tempFile -Value $function.Body
                    Move-Item -Path $tempFile.FullName -Destination $tempFilePsm1
                    Write-Host ""
                    Import-Module $tempFilePsm1 -Global
                    $commands = (Get-Module | Where-Object { $_.Path -eq $tempFilePsm1 }).ExportedCommands.Keys
                    $command = Get-Command $commands[0]
                    if($commands.Count -gt 1) {
                        while($null -eq $command) {
                            $commandName = (Read-Host "There are multiple functions in this module ($($commands -join ', ')), enter the name of the one you want to use as the entry point").Trim()
                            $command = Get-Command $commandName -ErrorAction "SilentlyContinue"
                            if(!$command) {
                                Write-Warning "Command name '$commandName' failed to import a command."
                            }
                        }
                    }
                    $params = @{}
                    if($command.ParameterSets) {
                        $command.ParameterSets.GetEnumerator()[0].Parameters | Where-Object { $_.Position -ge 0 } | Foreach-Object {
                            $params[$_.Name] = Read-Host "$($_.Name) ($($_.ParameterType))"
                        }
                    }
                    $previousErrorActionPreference = $ErrorActionPreference
                    try {
                        & $function.Name @params -ErrorAction "Stop" | Out-Host
                        Get-Module | Where-Object { $_.Path -eq $tempFilePsm1 } | Remove-Module -Force
                        $answer = Read-Host -Prompt "Are there any issues that need correcting? (y/n)"
                        if($answer -eq "y") {
                            $issueDescription = Read-Host -Prompt "Describe the issues"
                            Write-AifbFunctionOutput -FunctionText $function.Body -Prompt $fullPrompt
                            $function = Optimize-AifbFunction -Function $function -Prompt $fullPrompt -RuntimeError $issueDescription
                            Write-AifbFunctionOutput -FunctionText $function.Body -SyntaxHighlight -NoLogMessages -Prompt $fullPrompt
                        }
                    } catch {
                        Get-Module | Where-Object { $_.Path -eq $tempFilePsm1 } | Remove-Module -Force
                        Write-Error $_
                        $answer = Read-Host -Prompt "An error occurred, do you want to try auto-fix the function? (y/n)"
                        if($answer -eq "y") {
                            Write-AifbFunctionOutput -FunctionText $function.Body -Prompt $fullPrompt
                            $function = Optimize-AifbFunction -Function $function -Prompt $fullPrompt -RuntimeError $_.Exception.Message
                            Write-AifbFunctionOutput -FunctionText $function.Body -SyntaxHighlight -NoLogMessages -Prompt $fullPrompt
                        }
                    }
                    Write-Host ""
                    $ErrorActionPreference = $previousErrorActionPreference
                }
                "Save" {
                    $moduleLocation = Save-AifbFunctionOutput -FunctionText $function.Body -FunctionName $function.Name -Prompt $fullPrompt
                    Import-Module $moduleLocation -Global
                    Write-Host "The function is available as '$($function.Name)' in your current terminal session. To import this function in the future use 'Import-Module $moduleLocation' or add the directory with all your PowerShellAI modules to your `$env:PSModulePath to have them auto import for every session."
                    $finished = $true
                }
                "Quit" {
                    $finished = $true
                }
            }
        }
    } finally {
        Stop-Chat
    }
}