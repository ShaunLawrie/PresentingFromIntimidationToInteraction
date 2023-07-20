function Get-OpenAIEmbeddingsUri {
    [CmdletBinding()]
    param ()

    (Get-OpenAIBaseRestURI) + '/embeddings'
}