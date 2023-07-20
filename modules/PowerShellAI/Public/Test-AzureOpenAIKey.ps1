function Test-AzureOpenAIKey {
    <#
        .SYNOPSIS
        Tests if the AzureOpenAIKey module scope variable or environment variable is set.

        .EXAMPLE
        Test-AzureOpenAIKey
    #>
    -not [string]::IsNullOrEmpty($env:AzureOpenAIKey)
}
