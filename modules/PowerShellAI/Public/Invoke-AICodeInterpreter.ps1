#requires -Module PwshSpectreConsole

$script:WorkingStoragePath = $null
$script:PreviousRuns = $null
$global:WarningPreference = "SilentlyContinue"

function Initialize-AICodeInterpreter {
    param (
        [string] $Start
    )

    # Quick way of creating a directory to work in which will be reused if the exact same starting prompt is used a second time
    $sha256 = [System.Security.Cryptography.SHA256Managed]::new()
    $paramBytes = [System.Text.Encoding]::Default.GetBytes($Start)
    $hashBytes = $sha256.ComputeHash($paramBytes)
    $hashKey = [Convert]::ToBase64String($hashBytes)
    $pattern = '[' + ([System.IO.Path]::GetInvalidFileNameChars() -join '').Replace('\','\\') + ']+'
    $workingDir = [regex]::Replace($hashKey, $pattern, "-")

    if ($PSVersionTable.Platform -eq 'Unix') {
        $Script:WorkingStoragePath = Join-Path $env:HOME '~/PowerShellAI/ChatGPT/CodeInterpreter'
    }
    else {
        $Script:WorkingStoragePath = Join-Path $env:APPDATA 'PowerShellAI/ChatGPT/CodeInterpreter'
    }

    $path = "$script:WorkingStoragePath\$workingDir"
    New-Item -Path "$path" -ItemType "Directory" -Force | Out-Null

    Write-Host "Working in directory: $path`n"

    return $path
}

function Export-AITestDefinition {
    param (
        [string] $Path,
        [string] $TestDefinition
    )

    $pathName = "$Path\function.Tests.ps1"
    Set-Content -Path $pathName -Value $TestDefinition

    return $pathName
}

function Export-AIFunctionDefinition {
    param (
        [string] $Path,
        [string] $FunctionDefinition
    )

    $pathName = "$Path\function.psm1"
    Set-Content -Path $pathName -Value $FunctionDefinition

    return $pathName
}

function Convert-XmlToPrettyString {
    param (
        [xml]$Xml
    )
    $stringwriter = New-Object System.IO.StringWriter
    $writer = New-Object System.Xml.XmlTextwriter($stringwriter)
    $writer.Formatting = [System.XML.Formatting]::Indented
    $Xml.WriteContentTo($writer)
    return $stringwriter.ToString()
}

function Convert-XmlToSortedXml {
    param (
        [object] $Xml
    )

    if($Xml.HasChildNodes) {
        $sortedChildNodes = $Xml.ChildNodes | Where-Object { $_.NodeType -ne "XmlDeclaration" } | Sort-Object { $_.LocalName, $_.name }
        foreach($child in $sortedChildNodes) {
            $sortedChild = Convert-XmlToSortedXml $child
            $Xml.AppendChild($Xml.RemoveChild($sortedChild)) | Out-Null
        }
    }

    return $Xml
}

function Invoke-AICodeInterpreterHelp {
    $help = Read-Host "`nProvide some help"
    $help = $help + ". Try to rewrite the function with this new information."
    Write-Host ""
    $response = (Get-GPT4Completion $help).Trim()
    $function = $response | ConvertTo-AifbFunction -ErrorAction "SilentlyContinue"
    $text = $response -replace '(?s)```.+?```', '' -replace ':', '.' -replace '[\n]{2}', "`n"

    $text = [Spectre.Console.Markup]::Escape($text)
    $text = $text -replace '`(.+?)`', '[IndianRed1_1]$1[/]'

    Write-SpectrePanel -Title "[IndianRed1_1]:robot: PowerShellAI Code Interpreter [/]" -Color "IndianRed1_1" -Data $text.Trim() -Expand

    if($function) {
        Write-Host ""
        Write-Codeblock $function.Body.Trim() -SyntaxHighlight -ShowLineNumbers
        return Export-AIFunctionDefinition -Path $path -FunctionDefinition $function.Body
    } else {
        $global:LASTAIRESPONSE = $response
        throw "Shit"
    }
}

function ConvertTo-SanitizedResult {
    param (
        [object] $Results
    )
    
    # Force the order of elements so cached responses are consistent
    $resultsReport = $results | ConvertTo-NUnitReport
    $resultsReport = Convert-XmlToSortedXml $resultsReport
    $envNode = $resultsReport.'test-results'.environment
    $resultsReport.'test-results'.RemoveChild($envNode) | Out-Null
    $resultsXmlString = Convert-XmlToPrettyString $resultsReport

    # get rid of values that change each run or caching won't work
    $resultsXmlString = $resultsXmlString -replace '\s+time=".+?"', '' -replace 'date=".+?"', 'date="2023-01-01"'

    return $resultsXmlString
}

function Invoke-AICodeInterpreter {
    [CmdletBinding()]
    param (
        [string] $Start = @"
 - Takes an integer as input and returns another integer
 - Given a number parameter of 3 the function returns 382
 - Given a number parameter of 17 the function returns 2174
"@,
        [string] $Build = "Work out a mathematical solution to the requirements.",
        [string] $Build2 = "Write powershell function code that will pass the tests using logic to deduce what the best quality code to solve the problem will be. Verify all mathematic assumptions using only the functions you have been provided with.",
        [bool] $Cached = $true,
        [int] $CacheResponseDelayMilliseconds = 5000,
        [switch] ${🔥},
        [switch] $ClearCache
    )

    if(${🔥}) {
        $global:YoloMode = $true
    } else {
        $global:YoloMode = $false
    }

    if($Cached) {
        Set-OpenAIAPIOptions -CacheResponses $true -CacheResponseDelayMilliseconds $CacheResponseDelayMilliseconds -PersistCachedResponses $true
    } else {
        Set-OpenAIAPIOptions -CacheResponses $false -CacheResponseDelayMilliseconds 0 -PersistCachedResponses $false
    }

    if($ClearCache) {
        Clear-OpenAIAPICache
    }

    Set-ChatSessionOption -model "gpt-4" -max_tokens 1024
    Stop-Chat
    New-ChatSystemMessage -Content @"
You are an expert powershell with the following skills:
 - You develop and you test code.
 - You are capable of evaluating math when it's required to meet function requirements.
 - When given a list of requirements for a function you will write pester tests without mocks.
 - You always write tests before attempting to solve the requirements.
 - You don't test for missing parameters.
 - You always use available functions to test mathematical assumptions before writing code.
 - The function you build is always called Invoke-DemoFunction.
 - You never suggest the tests are wrong and work out why the function doesn't meet the requirements of the test.
 - You work out mathematic solutions without first running the calculations through functions.
 - Only use the functions you have been provided with.
 - You never use fully qualified function names in Pester tests.
 - If you're given a math problem you don't just use if-else or case statements to solve the specific examples.
 - You are capable of thinking about linear algebra and how to solve problems using it.
 - If you are stuck you can ask for help by saying HELP in capital letters in your response.
"@

    $path = Initialize-AICodeInterpreter -Start $Start

    Push-Location "."
    try {
        Set-Location $path

        $functionFile = $null

        $response = (Get-GPT4Completion $Start).Trim()
        $test = $response | ConvertTo-AifbTest
        $text = $response -replace '(?s)```.+?```', '' -replace ':', '.' -replace '[\n]{2}', "`n"
        $text = [Spectre.Console.Markup]::Escape($text)
        $text = $text -replace '`(.+?)`', '[IndianRed1_1]$1[/]'

        Write-SpectrePanel -Title "[IndianRed1_1]:robot: PowerShellAI Code Interpreter [/]" -Color "IndianRed1_1" -Data $text.Trim() -Expand
        
        if($test) {
            Write-Host ""
            Write-Codeblock $test -SyntaxHighlight -ShowLineNumbers
            $null = Export-AITestDefinition -Path $path -TestDefinition $test
            Write-Host ""
        } else {
            $global:LASTAIRESPONSE = $response
            throw "Damn"
        }

        Add-ChatFunction -Name "Get-MathCalculation" `
            -Description @"
Get the results of a math equation that has been provided as powershell code e.g.
 - [math]::PI * 13
 - [math]::Sqrt(4)
 - 14 * 23
 - [math]::Pow(10, 2)
"@ `
            -Parameters ([ordered]@{
                equation = [ordered]@{
                    type = "string"
                    description = "The equation as powershell code"
                }
            }) `
            -RequiredParameters @("equation")

        $response = Get-GPT4Completion $Build

        $function = $response.Trim() | ConvertTo-AifbFunction
        $text = $response -replace '(?s)```.+?```', '' -replace ':', '.' -replace '[\n]{2}', "`n"
        $text = [Spectre.Console.Markup]::Escape($text)
        $text = $text -replace '`(.+?)`', '[IndianRed1_1]$1[/]'
        
        Write-SpectrePanel -Title "[IndianRed1_1]:robot: PowerShellAI Code Interpreter [/]" -Color "IndianRed1_1" -Data $text.Trim() -Expand

        if($function) {
            Write-Host ""
            Write-Codeblock $function.Body.Trim() -SyntaxHighlight -ShowLineNumbers
            $functionFile = Export-AIFunctionDefinition -Path $path -FunctionDefinition $function.Body
        } else {
            $response = Get-GPT4Completion $Build2
            $function = $response.Trim() | ConvertTo-AifbFunction
            $text = $response -replace '(?s)```.+?```', '' -replace ':', '.' -replace '[\n]{2}', "`n"
            $text = [Spectre.Console.Markup]::Escape($text)
            $text = $text -replace '`(.+?)`', '[IndianRed1_1]$1[/]'
            Write-SpectrePanel -Title "[IndianRed1_1]:robot: PowerShellAI Code Interpreter [/]" -Color "IndianRed1_1" -Data $text.Trim() -Expand
            if($function) {
                Write-Host ""
                Write-Codeblock $function.Body.Trim() -SyntaxHighlight -ShowLineNumbers
                $functionFile = Export-AIFunctionDefinition -Path $path -FunctionDefinition $function.Body
            } else {
                throw "Doh"
            }
        }

        Import-Module $functionFile -Force
        $results = Invoke-Pester -Passthru
        $testResult = $LASTEXITCODE
        $sanitizedResults = ConvertTo-SanitizedResult $results
        Write-Host ""

        $attempts = 0
        $maxAttempts = 4
        $semanticallyCorrect = $false
        while($semanticallyCorrect -ne $true) {
            $attempts++
            if($attempts -gt $maxAttempts) {
                Write-Error "Reached maximum attempts $attempts"
                exit
            }
            while ($testResult -ne 0) {
                $function = $null
                $text = "Not set"
                if($testResult -eq 9001) {
                    $question = "The code doesn't meet all requirements, the code needs fixing:"
                    Write-Verbose "Failing on semantics"
                    Write-Verbose $question
                    Write-Warning "Cache bypassed"
                    $response = (Get-GPT4Completion $question -NoCache).Trim()
                    $function = $response | ConvertTo-AifbFunction -ErrorAction "SilentlyContinue"
                    $text = $response -replace '(?s)```.+?```', '' -replace ':', '.' -replace '[\n]{2}', "`n"
                } else {
                    Write-Verbose "Failing on testing"
                    $question = "Some tests failed, the code needs fixing, remember to use available functions for any mathematic equations and show your working:`n$sanitizedResults"
                    Write-Verbose $question
                    $response = (Get-GPT4Completion $question).Trim()
                    $function = $response | ConvertTo-AifbFunction -ErrorAction "SilentlyContinue"
                    $text = $response -replace '(?s)```.+?```', '' -replace ':', '.' -replace '[\n]{2}', "`n"
                }
                $text = [Spectre.Console.Markup]::Escape($text)
                $text = $text -replace '`(.+?)`', '[IndianRed1_1]$1[/]'

                Write-SpectrePanel -Title "[IndianRed1_1]:robot: PowerShellAI Code Interpreter [/]" -Color "IndianRed1_1" -Data $text.Trim() -Expand

                if($text -clike "*HELP*") {
                    $functionFile = Invoke-AICodeInterpreterHelp
                }

                if($function) {
                    Write-Host ""
                    Write-Codeblock $function.Body.Trim() -SyntaxHighlight -ShowLineNumbers
                    $functionFile = Export-AIFunctionDefinition -Path $path -FunctionDefinition $function.Body
                } else {
                    $functionFile = Invoke-AICodeInterpreterHelp
                }

                Import-Module $functionFile -Force
                $results = Invoke-Pester -Passthru
                $testResult = $LASTEXITCODE
                $sanitizedResults = ConvertTo-SanitizedResult $results
                Write-Host ""
            }

            # check semantics work
            $question = 'All tests are now passing. Does the code meet all requirements? Respond with "Yes" or "No" followed by an explanation.'
            Write-Verbose $question
            $response = (Get-GPT4Completion $question).Trim()
            $text = $response -replace '(?s)```.+?```', '' -replace ':', '.' -replace '[\n]{2}', "`n"
            $text = [Spectre.Console.Markup]::Escape($text)
            $text = $text -replace '`(.+?)`', '[IndianRed1_1]$1[/]'
            Write-SpectrePanel -Title "[IndianRed1_1]:robot: PowerShellAI Code Interpreter [/]" -Color "IndianRed1_1" -Data $text.Trim() -Expand
            if($response -like "*yes*") {
                $semanticallyCorrect = $true
                $testResult = 0
            } else {
                $semanticallyCorrect = $false
                $testResult = 9001
            }
        }

    } finally {
        Pop-Location
    }
}