function Get-OpenAIEmbeddings {
    <#
        .SYNOPSIS
        Get OpenAI Embeddings

        .DESCRIPTION
        Get OpenAI Embeddings

        .PARAMETER Content
        The text to embed

        .PARAMETER Raw
        Return the raw response

        .EXAMPLE
        Get-OpenAIEmbeddings -Content "Hello world"
        
        .LINK 
        https://platform.openai.com/docs/api-reference/embeddings
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$Content,
        [Switch]$Raw
    )

    $body = @{
        "input" = $Content
        "model" = "text-embedding-ada-002"
    } | ConvertTo-Json

    $response = Invoke-OpenAIAPI -Uri (Get-OpenAIEmbeddingsUri) -Method Post -Body $body

    if ($Raw) {
        $response
    }
    else {
        # $response.choices | Select-Object text
        # return everything till we figure out what info is needed
        $response.data
    }
}