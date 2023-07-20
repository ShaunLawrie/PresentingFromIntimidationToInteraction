# Not sure if there will be multiple ways functions will be rendered in responses from the LLM
$script:TestExtractionPatterns = @(
    @{
        Regex = '(?s)(Describe ["''][\w\s-]+?["''] \{.+})'
        FunctionBodyGroup = 1
    }
)

function ConvertTo-AifbTest {
    param (
        # Some text that contains a function name and body to extract
        [Parameter(ValueFromPipeline = $true)]
        [string] $Text
    )
    process {
        foreach($pattern in $script:TestExtractionPatterns) {
            if($Text -match $pattern.Regex) {
                return ($Matches[$pattern.FunctionBodyGroup] -replace '(?s)```.+', '')
            }
        }

        return $null
    }
}