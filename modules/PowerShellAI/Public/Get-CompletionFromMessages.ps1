function Get-CompletionFromMessages {
    <#
        .SYNOPSIS
        Gets completion suggestions based on the array of messages.

        .DESCRIPTION
        The Get-CompletionFromMessages function returns completion suggestion based on the messages.

        .PARAMETER Messages
        Specifies the chat messages to use for generating completion suggestions.

        .EXAMPLE
        Get-CompletionFromMessages $(
            New-ChatMessageTemplate -Role system 'You are a PowerShell expert'
            New-ChatMessageTemplate -Role user 'List even numbers between 1 and 10'
        )
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        $Messages
    )

    $payload = (Get-ChatSessionOptions).Clone()

    $payload.messages = $messages
    $payload = $payload | ConvertTo-Json -Depth 10
    
    $body = [System.Text.Encoding]::UTF8.GetBytes($payload)

    if ((Get-ChatAPIProvider) -eq 'OpenAI') {
        $uri = Get-OpenAIChatCompletionUri
    }
    elseif ((Get-ChatAPIProvider) -eq 'AzureOpenAI') {
        $uri = Get-ChatAzureOpenAIURI
    }

    $result = Invoke-OpenAIAPI -Uri $uri -Method 'Post' -Body $body 
    $result.choices.message
}