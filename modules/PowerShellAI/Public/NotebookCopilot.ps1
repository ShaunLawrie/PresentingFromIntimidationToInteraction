function Test-InNotebook {
  <#
        .SYNOPSIS
          Returns true if the current session is in a Polyglot Interactive Notebook
        .DESCRIPTION
          Returns true if the current session is in a Polyglot Interactive Notebook
          This is a helper function for the other functions in this module
          It is not intended to be used directly
  
        .EXAMPLE
          if (Test-InNotebook) { 'in notebook' }
  #>
  [CmdletBinding()]
  param()
    
  $typename = 'Microsoft.DotNet.Interactive.Kernel'
  $null -ne ($typename -as [type])
}
  
function New-NBCell {
  <#
        .SYNOPSIS
          Creates a new cell in a Polyglot Interactive Notebook
        .DESCRIPTION
          Creates a new cell in a Polyglot Interactive Notebook
          This is a helper function for the other functions in this module
          It is not intended to be used directly
  
        .EXAMPLE
          New-NBCell -cellType 'pwsh' -code 'Get-Process'            
  #>
  [CmdletBinding()]
  param(
    [ValidateSet('pwsh', 'csharp', 'fsharp', 'html', 'markdown', 'javascript', 'sql', 'mermaid', 'kql')]
    $cellType = 'pwsh',
    [Parameter(ValueFromPipeline)]
    $code
  )
  
  Begin {
    if (-not (Test-InNotebook)) {
      throw 'This can only be used in a Polyglot Interactive Notebook'
    }
  }
  
  Process {
    $cellContent = New-Object Microsoft.DotNet.Interactive.Commands.SendEditableCode -ArgumentList $cellType, $code.Trim()
    $null = [Microsoft.DotNet.Interactive.Kernel]::Root.SendAsync($cellContent)
  }
}
  
function New-PwshCell {
  <#
        .SYNOPSIS
          Creates a new PowerShell cell in a Polyglot Interactive Notebook
        .DESCRIPTION
          Creates a new PowerShell cell in a Polyglot Interactive Notebook
          This is a helper function for the other functions in this module
  
        .EXAMPLE
          New-PwshCell -code 'Get-Process'
  #>
  [CmdletBinding()]
  param(
    [Parameter(ValueFromPipeline)]
    $code
  )
  
  Process {
    $code | New-NBCell
  }
}
  
function NBCopilot {
  <#
      .SYNOPSIS
      Interactes with GPT and sends the result to a Polyglot Interactive Notebook cell
  
      .EXAMPLE
      NBCopilot 'Write a PowerShell core function, just code, no explanation, do not show how to use it, that will: show a date and time in timestamp form'
  
      .EXAMPLE
      NBCopilot 'add comment based help to your code'
  
      .EXAMPLE
      $prompt = 'Write c#, just the function, no explanation, do not show how to use it, that will: show a date and time in a regular timestamp form'
      
      NBCopilot $prompt -cellType csharp
  #>
  [CmdletBinding()]
  param(
    $prompt,
    [ValidateSet('pwsh', 'csharp', 'fsharp', 'html', 'markdown', 'javascript', 'sql', 'mermaid', 'kql')]
    $cellType = 'pwsh'      
  )
  
  if (-not (Test-InNotebook)) {
    throw 'This can only be used in a Polyglot Interactive Notebook'
  }
  
  $result = chat $prompt
  
  $result = $result -replace '```powershell', '' -replace '```', ''
  $result | New-NBCell -cellType $cellType
}