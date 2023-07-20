
function Get-OpenAIChatCompletionUri {
    <#
        .Synopsis
        Url for OpenAI Chat Completions API
    #>
    
    (Get-OpenAIBaseRestURI) + '/chat/completions'
}