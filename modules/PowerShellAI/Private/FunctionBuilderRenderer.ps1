$script:LogMessages = [System.Collections.Queue]::new()
$script:LogMessageColors = @{
    "INF" = "White"
    "WRN" = "Yellow"
    "ERR" = "Red"
}
$script:LogMessagesMaxCount = 8
$script:FunctionTopLeft = @{X = 0; Y = 0}
$script:RendererBackground = @{ R = 35; G = 35; B = 35 }
$script:FunctionVersion = 1
$script:InitialPrePrompt = $null
$script:InitialPrompt = $null
$script:NonInteractive = $false

function Initialize-AifbRenderer {
    <#
        .SYNOPSIS
            Setup the function renderer at the current cursor position, this will be considered the top left of the function for each draw
    #>
    param (
        [string] $InitialPrePrompt,
        [string] $InitialPrompt,
        [bool] $NonInteractive
    )
    $script:FunctionTopLeft.X = $Host.UI.RawUI.CursorPosition.X
    $script:FunctionTopLeft.Y = $Host.UI.RawUI.CursorPosition.Y + 1
    $script:LogMessages = [System.Collections.Queue]::new()
    $script:FunctionVersion = 0
    $script:InitialPrePrompt = $InitialPrePrompt
    $script:InitialPrompt = $InitialPrompt
    $script:NonInteractive = $NonInteractive
}

function Write-AifbFunctionOutput {
    <#
        .SYNOPSIS
            This function writes a function to the terminal with optional syntax highlighting

        .DESCRIPTION
            Using some cursor manipulation and Write-Host this re-renders overtop of itself and clears the rest of the text on the terminal.
            Then the function text is drawn and the log data is written underneath it.
    #>
    param (
        # The text of the function to render
        [string] $FunctionText,
        # Prompt info
        [string] $Prompt,
        # Extents to highlight as issues
        [array] $HighlightExtents,
        # Lines to highlight as issues
        [array] $HighlightLines,
        # Whether to syntax highlight the function
        [switch] $SyntaxHighlight,
        # The background color for the code block
        [hashtable] $BackgroundRgb = $script:RendererBackground,
        # Don't output the log viewer
        [switch] $NoLogMessages
    )

    if($script:NonInteractive) {
        return
    }

    $FunctionText = $FunctionText.Trim() + "`n`n<#`nAIFunctionBuilder Iteration $([int]$script:FunctionVersion++)`n$Prompt`n#>"
    $script:FunctionLines = @()

    # Write it all to the terminal and don't overwrite on every render in verbose mode, this makes debugging easier
    if($VerbosePreference -ne "SilentlyContinue") {
        Write-Verbose "Function text:`n$FunctionText"
        return
    }

    # Draw from the top left of the terminal window
    [Console]::CursorVisible = $false
    [Console]::SetCursorPosition(0, 0)
    if($script:InitialPrePrompt) {
        Write-Host -ForegroundColor Cyan -NoNewline "$($script:InitialPrePrompt): "
        Write-Host -NoNewline $script:InitialPrompt
    } else {
        Write-Host -NoNewline $script:InitialPrompt
    }
    [Console]::WriteLine(" " * ($Host.UI.RawUI.WindowSize.Width - $Host.UI.RawUI.CursorPosition.X))
    [Console]::WriteLine(" " * ($Host.UI.RawUI.WindowSize.Width))
    
    Write-Codeblock -Text $FunctionText -ShowLineNumbers -HighlightExtents $HighlightExtents -HighlightLines $HighlightLines -SyntaxHighlight:$SyntaxHighlight

    # Blank out the rest of the terminal
    $endOfFunctionPosition = $Host.UI.RawUI.CursorPosition
    $clearingBuffer = ""
    1..($Host.UI.RawUI.WindowSize.Height - $Host.UI.RawUI.CursorPosition.Y) | Foreach-Object {
        $clearingBuffer += (" " * $Host.UI.RawUI.WindowSize.Width)
    }
    [Console]::Write($clearingBuffer)
    [Console]::SetCursorPosition($endOfFunctionPosition.X, $endOfFunctionPosition.Y)
    Write-Host ""

    # Write the log messages under the function
    if(!$NoLogMessages) {
        Write-AifbLogMessages
    }
    [Console]::CursorVisible = $true
}

function Add-AifbLogMessage {
    <#
        .SYNOPSIS
            Add a log message to the function builder log.
    #>
    param (
        # The message to add
        [string] $Message,
        # The level to log it at
        [ValidateSet("INF", "WRN", "ERR")]
        [string] $Level = "INF",
        # Whether to skip rendering the latest log to the terminal
        [switch] $NoRender
    )

    Write-Verbose "$Level $Message"

    $logItem = @{
        Date = (Get-Date).ToString("HH:mm:ss")
        Message = $Message
        Level = $Level
    }
    $script:LogMessages.Enqueue($logItem)

    if($script:LogMessages.Count -gt $script:LogMessagesMaxCount) {
        $script:LogMessages.Dequeue() | Out-Null
    }
}

function Write-AifbLogMessages {
    <#
        .SYNOPSIS
            Write out the current list of log messages to the terminal.
    #>
    if($VerbosePreference) {
        return
    }

    $consoleWidth = $Host.UI.RawUI.WindowSize.Width
    $script:LogMessages | Foreach-Object {
        $logPrefix = "$($_.Date) $($_.Level.PadRight(4))"
        $line = $_.Message -replace "`n", ". " -replace "`r", ""
        $messageWidth = $consoleWidth - $logPrefix.Length - 1
        if($line.Length -gt $messageWidth) {
            $lines = ($line | Select-String "(.{1,$messageWidth})+").Matches.Groups[1].Captures.Value
        } else {
            $lines = @($line)
        }
        $lineNumber = 0
        foreach($line in $lines) {
            if($lineNumber -eq 0) {
                $message = $logPrefix + $line
                Write-Host -NoNewline -ForegroundColor $script:LogMessageColors[$_.Level] ($message + (" " * ($consoleWidth - $message.Length)))
            } else {
                $message = (" " * $logPrefix.Length) + $line
                Write-Host -NoNewline -ForegroundColor $script:LogMessageColors[$_.Level] ($message + (" " * ($consoleWidth - $message.Length)))
            }
            $lineNumber++
        }   
    }
    Write-Host "`n"
}