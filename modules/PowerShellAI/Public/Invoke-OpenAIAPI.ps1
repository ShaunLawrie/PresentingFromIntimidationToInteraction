$script:CacheResponses = $false
$script:CachedResponses = @{}
$script:CacheResponseDelayMilliseconds = 0
$script:CacheStoragePath = $null
$script:RequestCountKey = $null
$script:RequestCount = 0

function Export-CacheStorage {
    [CmdletBinding()]
    param ()

    if($null -ne $script:CacheStoragePath) {
        $script:CachedResponses | ConvertTo-Json -Depth 10 | Set-Content $script:CacheStoragePath
    }
}

function Set-OpenAIAPIOptions {
    param (
        [bool] $CacheResponses,
        [int] $CacheResponseDelayMilliseconds
    )

    if ($PSVersionTable.Platform -eq 'Unix') {
        $Script:CacheStoragePath = Join-Path $env:HOME '~/PowerShellAI/ChatGPT/cache.json'
    }
    elseif ($env:APPDATA) {
        $Script:CacheStoragePath = Join-Path $env:APPDATA 'PowerShellAI/ChatGPT/cache.json'
    }

    $script:CacheResponses = $CacheResponses
    $script:CacheResponseDelayMilliseconds = $CacheResponseDelayMilliseconds
    
    if($CacheResponses) {
        if(Test-Path $script:CacheStoragePath) {
            $cacheContent = Get-Content -Raw -Path $script:CacheStoragePath
            if([string]::IsNullOrWhiteSpace($cacheContent)) {
                $script:CachedResponses = @{}
            } else {
                Write-Warning "Loaded OpenAI Cache from $script:CacheStoragePath"
                $script:CachedResponses = $cacheContent | ConvertFrom-Json -Depth 10 -AsHashtable
            }
        } else {
            $script:CachedResponses = @{}
        }
    }
    $n = [Guid]::NewGuid()
    Write-Host "Cache logging is under '$n'"
    $script:RequestCountKey = $n
    $script:RequestCount = 0
}

function Get-OpenAICachedResponse {
    param (
        [hashtable] $Params,
        [switch] $NoCache,
        [string] $CacheKey
    )
    # Should probably use sha256 because the params contain the api key
    $sha256 = [System.Security.Cryptography.SHA256Managed]::new()
    $paramString = $Params | ConvertTo-Json -Depth 10 -Compress
    $paramBytes = [System.Text.Encoding]::Default.GetBytes($paramString)
    $hashBytes = $sha256.ComputeHash($paramBytes)
    $hashKey = [Convert]::ToBase64String($hashBytes)

    $parent = Split-Path $script:CacheStoragePath
    $logPath = "$parent\$script:RequestCountKey.$script:RequestCount.attempt.json"
    Set-Content -Path $logPath -Value $CacheKey
    $script:RequestCount++
    
    # Quick in-memory cache
    if($script:CachedResponses.ContainsKey($CacheKey) -and $NoCache -ne $true) {
        $response = $script:CachedResponses[$CacheKey]
        if($script:CacheResponseDelayMilliseconds -gt 0) {
            $progressActivity = "Thinking (cached)..."
            $start = Get-Date
            $timeout = (Get-Date).AddMilliseconds($script:CacheResponseDelayMilliseconds)
            while((Get-Date) -lt $timeout) {
                $percent = ((Get-Date) - $start).TotalMilliseconds / $script:CacheResponseDelayMilliseconds * 100
                
                # Slow the progress towards the end of the progress bar because the api is a bit all over the show for response times, this makes sure the bar doesn't fill up linearly
                $logPercent = [int][math]::Min([math]::Max(1, $percent * [math]::Log(1.5)), 100)
                $status = "$logPercent% Completed"
                if($logPercent -eq 100) {
                    $status = "API is taking longer than expected"
                }
                Write-Progress -Id 1 -Activity $progressActivity -Status $status -PercentComplete $logPercent
                Start-Sleep -Milliseconds 10
            }
            Write-Progress -Id 1 -Activity $progressActivity -Completed
        }
    } else {
        $response = Invoke-RestMethodWithProgress -Params $params -NoProgress:$NoProgress
        $script:CachedResponses[$CacheKey] = $response
        Export-CacheStorage
    }

    return $response
}

function Clear-OpenAIAPICache {
    $script:CachedResponses = @{}
    Export-CacheStorage
}

function Invoke-OpenAIAPI {
    <#
    .SYNOPSIS
    Invoke the OpenAI API

    .DESCRIPTION
    Invoke the OpenAI API

    .PARAMETER Uri
    The URI to invoke

    .PARAMETER Method
    The HTTP method to use. Defaults to 'Get'

    .PARAMETER Body
    The body to send with the request

    .PARAMETER NoProgress
    The option to hide write-progress if you want, you could also set $ProgressPreference to SilentlyContinue

    .EXAMPLE
    Invoke-OpenAIAPI -Uri "https://api.openai.com/v1/images/generations" -Method Post -Body $body
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        $Uri,
        [ValidateSet('Default', 'Delete', 'Get', 'Head', 'Merge', 'Options', 'Patch', 'Post', 'Put', 'Trace')]
        $Method = 'Get',
        $Body,
        [switch] $NoProgress,
        [switch] $NoCache,
        [string] $CacheKey
    )

    $params = @{
        Uri         = $Uri
        Method      = $Method
        ContentType = 'application/json'
        body        = $Body
    }

    if ((Get-ChatAPIProvider) -eq 'OpenAI') {
        if (!(Test-OpenAIKey)) {
            throw 'Please set your OpenAI API key using Set-OpenAIKey or by configuring the $env:OpenAIKey environment variable (https://platform.openai.com/account/api-keys)'
        }

        if (($apiKey = Get-LocalOpenAIKey) -is [SecureString]) {
            #On PowerShell 6 and higher use Invoke-RestMethod with Authentication parameter and secure Token
            $params['Authentication'] = 'Bearer'
            $params['Token'] = $apiKey
        }
        else {
            #On PowerShell 5 and lower, or when using the $env:OpenAIKey environment variable, use Invoke-RestMethod with plain text header
            $params['Headers'] = @{Authorization = "Bearer $apiKey" }
        }
    } 
    elseif ((Get-ChatAPIProvider) -eq 'AzureOpenAI') {
        $callingFunction = (Get-PSCallStack)[1].FunctionName
        # if($callingFunction -ne 'Get-GPT4Completion'){
        if ($callingFunction -ne 'Get-GPT4Response') {
            $msg = "$callingFunction is not supported by Azure OpenAI. Use 'Set-ChatAPIProvider OpenAI' and then try again."
            #Write-Warning $msg
            throw $msg
        }`

        if (!(Test-AzureOpenAIKey)) {
            throw 'Please set your Azure OpenAI API key by configuring the $env:AzureOpenAIKey environment variable'
        }
        else {
            $params['Headers'] = @{'api-key' = $env:AzureOpenAIKey }
        }
    }
    
    Write-Verbose ($params | ConvertTo-Json)
    
    Write-Information "Thinking ..."
    
    if($script:CacheResponses) {
        Get-OpenAICachedResponse -Params $params -NoProgress:$NoProgress -NoCache:$NoCache -CacheKey $CacheKey
    } else {
        Invoke-RestMethodWithProgress -Params $params -NoProgress:$NoProgress
    }
}
