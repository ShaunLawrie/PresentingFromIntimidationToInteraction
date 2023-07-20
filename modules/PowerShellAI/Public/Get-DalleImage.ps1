function Get-DalleImage { 
    <#
        .SYNOPSIS
        Get a DALL-E image from the OpenAI API
        
        .DESCRIPTION
        Given a description, the model will return an image

        .PARAMETER Description
        The description to generate an image for

        .PARAMETER Size
        The size of the image to generate. Defaults to 256

        .PARAMETER Raw
        If set, the raw response will be returned. Otherwise, the image will be saved to a temporary file and the path to that file will be returned

        .PARAMETER NoProgress
        The option to hide write-progress if you want, you could also set $ProgressPreference to SilentlyContinue

        .EXAMPLE
        Get-DalleImage -Description "A cat sitting on a table"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        $Description,
        [ValidateSet('256', '512', '1024')]
        $Size = 256,
        [Switch]$Raw,
        [Switch]$NoProgress
    )

    $targetSize = switch ($Size) {
        256 { '256x256' }
        512 { '512x512' }
        1024 { '1024x1024' }     
    }
  
    $body = [ordered]@{
        prompt = $Description
        size   = $targetSize
    } | ConvertTo-Json

    $result = Invoke-OpenAIAPI -Uri (Get-OpenAIImagesGenerationsURI) -Body $body -Method Post
  
    if ($Raw) {
        return $result
    }
    else {
        $DestinationPath = [IO.Path]::GetTempFileName() -replace ".tmp", ".png"
        $params = @{
            Uri = $result.data.url
            OutFile = $DestinationPath
        }
        Invoke-RestMethodWithProgress -Params $params -NoProgress:$NoProgress
        $DestinationPath
    }
}