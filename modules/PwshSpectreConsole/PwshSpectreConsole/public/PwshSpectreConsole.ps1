using module "..\private\Attributes.psm1"

$script:AccentColor = [Spectre.Console.Color]::Blue
$script:DefaultValueColor = [Spectre.Console.Color]::Grey

function Invoke-SpectrePromptAsync {
    param (
        $Prompt
    )
    $cts = [System.Threading.CancellationTokenSource]::new()
    try {
        $task = $Prompt.ShowAsync([Spectre.Console.AnsiConsole]::Console, $cts.Token)
        while (-not $task.AsyncWaitHandle.WaitOne(200)) {
            # Waiting for the async task this way allows ctrl-c interrupts to continue to work within the single-threaded PowerShell world
        }
        return $task.GetAwaiter().GetResult()
    } finally {
        $cts.Cancel()
        $task.Dispose()
    }
}

function Set-SpectreColors {
    param (
        [ValidateSpectreColor()]
        [ArgumentCompletionsSpectreColors()]
        [string] $AccentColor = "Blue",
        [ValidateSpectreColor()]
        [ArgumentCompletionsSpectreColors()]
        [string] $DefaultValueColor = "Grey"
    )
    $script:AccentColor = [Spectre.Console.Color]::$AccentColor
    $script:DefaultValueColor = [Spectre.Console.Color]::$DefaultValueColor
}

function Get-SpectreColorExamples {
    [Spectre.Console.Color] | Get-Member -Static -Type Properties | Select-Object -ExpandProperty Name | Foreach-Object {
        [Spectre.Console.AnsiConsole]::MarkupLine("[$_ on $_]  [/] [$_]$_[/]")
    }
}

function Write-SpectreParagraph {
    param (
        [string] $Text = "This is a sample paragraph! Provide some text to the command to write your own. This function writes a body of text without splitting a word across multiple lines.",
        [ValidateSet("Left", "Right", "Center")]
        [string] $Alignment = "Left",
        [int] $Padding = 0,
        [ValidateSpectreColor()]
        [ArgumentCompletionsSpectreColors()]
        [string] $Color,
        [ValidateSpectreColor()]
        [ArgumentCompletionsSpectreColors()]
        [string] $BackgroundColor,
        [switch] $Transparent,
        [switch] $NoNewline,
        [switch] $NoTrim
    )
    $bufferWidth = $Host.UI.RawUI.BufferSize.Width - 1 - ($Padding * 2)
    
    # omg this is hard when you have to factor in the spectre markup
    $textWithoutMarkup = $Text -replace ":[a-z0-9_]+:", [char]0x2714 -replace "\[[^\[\]]+?\]", [char]0x2715
    $textToReplace = (Select-String -Input $textWithoutMarkup -Pattern ".{1,$bufferWidth}(\s|$)" -AllMatches).Matches.Value
    $textToReplace | Foreach-Object {
        $capture = [regex]::Escape($_) -replace [char]0x2714, ':[a-z0-9_]+:' -replace [char]0x2715, '\[[^\[\]]+?\]'
        $Text = $Text -replace "($capture)(?!\[)(\b|$)", "`$1`n"
    }
    $lines = $Text.Split("`n")

    $lines | Foreach-Object {

        $paragraphColor = ""
        $paragraphColorClosing = ""
        if(-not [string]::IsNullOrWhiteSpace($BackgroundColor) -or -not [string]::IsNullOrWhiteSpace($Color)) {
            $paragraphBackgroundColor = ""
            if(-not [string]::IsNullOrWhiteSpace($BackgroundColor)) {
                $paragraphBackgroundColor = " on $BackgroundColor"
            }

            if(-not [string]::IsNullOrWhiteSpace($Color)) {
                $paragraphColor = "[$Color$paragraphBackgroundColor]"
            } else {
                $paragraphColor = "[default$paragraphBackgroundColor]"
            }
            
            $paragraphColorClosing = "[/]"
        }

        if(-not [string]::IsNullOrWhiteSpace($_) -or $NoTrim) {
            $inputText = $_ -replace "[\r\n]", ""
            if(-not $NoTrim) {
                $inputText = $inputText.Trim()
            }
            $paddedInputLine = (" " * $Padding) + $inputText + (" " * $Padding)
            $paddedInputLineWithoutMarkup = [Spectre.Console.Markup]::Remove($paddedInputLine) -replace ":[a-z0-9_]+:", "e"
            if($Alignment -eq "Left") {
                if($Transparent) {
                    $paddingLeftSpaces = "$([char]27)[[${PaddingLeft}C"
                } else {
                    $paddingLeftSpaces = " " * $PaddingLeft
                }
            }
            if($Alignment -eq "Center") {
                if($Transparent) {
                    $paddingLeftSpaces = "$([char]27)[[$([int](($Host.UI.RawUI.BufferSize.Width - $paddedInputLineWithoutMarkup.Length) / 2))C"
                } else {
                    $paddingLeftSpaces = " " * (($Host.UI.RawUI.BufferSize.Width - $paddedInputLineWithoutMarkup.Length) / 2)
                }
            }
            if($Alignment -eq "Right") {
                if($Transparent) {
                    $paddingLeftSpaces = "$([char]27)[[$($Host.UI.RawUI.BufferSize.Width - $paddedInputLineWithoutMarkup.Length)C"
                } else {
                    $paddingLeftSpaces = " " * ($Host.UI.RawUI.BufferSize.Width - $paddedInputLineWithoutMarkup.Length)
                }
            }
            $markupLine = "$paragraphColor$paddingLeftSpaces$paddedInputLine$paragraphColorClosing"
            try {
                [Spectre.Console.AnsiConsole]::Markup($markupLine)
            } catch {
                Write-Warning "Failed to render '$markupLine'"
                throw
            }
            $rightBuffer = "$paragraphColor"
            $positionX = $Host.UI.RawUI.CursorPosition.X
            $rightBuffer += (" " * ($Host.UI.RawUI.BufferSize.Width - $positionX))
            $rightBuffer += "$paragraphColorClosing"
            [Spectre.Console.AnsiConsole]::Markup($rightBuffer)
        }
    }

    if(-not $NoNewline) {
        Write-Host ""
    }
}

function Write-SpectreRule {
    param (
        [string] $Title,
        [ValidateSet("Left", "Right", "Center")]
        [string] $Alignment = "Left",
        [ValidateSpectreColor()]
        [ArgumentCompletionsSpectreColors()]
        [string] $Color = $script:AccentColor.ToString()
    )
    $rule = [Spectre.Console.Rule]::new("[$($Color)]$Title[/]")
    $rule.Justification = [Spectre.Console.Justify]::$Alignment
    [Spectre.Console.AnsiConsole]::Write($rule)
}

function Write-SpectreFigletText {
    param (
        [string] $Text = "Hello Spectre!",
        [ValidateSet("Left", "Right", "Center")]
        [string] $Alignment = "Left",
        [ValidateSpectreColor()]
        [ArgumentCompletionsSpectreColors()]
        [string] $Color = $script:AccentColor.ToString()
    )
    $figletText = [Spectre.Console.FigletText]::new($Text)
    $figletText.Justification = [Spectre.Console.Justify]::$Alignment
    $figletText.Color = [Spectre.Console.Color]::$Color
    [Spectre.Console.AnsiConsole]::Write($figletText)
}

function Get-SpectreSelection {
    param (
        [string] $Title = "What's your favourite colour [$($script:AccentColor.ToString())]option[/]?",
        [array] $Choices = @("red", "green", "blue"),
        [string] $ChoiceLabelProperty,
        [ValidateSpectreColor()]
        [ArgumentCompletionsSpectreColors()]
        [string] $Color = $script:AccentColor.ToString(),
        [int] $PageSize = 5
    )
    $prompt = [Spectre.Console.SelectionPrompt[string]]::new()

    $choiceLabels = $Choices
    if($ChoiceLabelProperty) {
        $choiceLabels = $Choices | Select-Object -ExpandProperty $ChoiceLabelProperty
    }

    $duplicateLabels = $choiceLabels | Group-Object | Where-Object { $_.Count -gt 1 }
    if($duplicateLabels) {
        Write-Error "You have duplicate labels in your select list, this is ambiguous so a selection cannot be made"
        exit 2
    }

    $prompt = [Spectre.Console.SelectionPromptExtensions]::AddChoices($prompt, [string[]]$choiceLabels)
    $prompt.Title = $Title
    $prompt.PageSize = $PageSize
    $prompt.WrapAround = $true
    $prompt.HighlightStyle = [Spectre.Console.Style]::new([Spectre.Console.Color]::$Color)
    $prompt.MoreChoicesText = "[$($script:DefaultValueColor)](Move up and down to reveal more choices)[/]"

    return $prompt
}

function Read-SpectreSelection {
    param (
        [string] $Title = "What's your favourite colour [$($script:AccentColor.ToString())]option[/]?",
        [array] $Choices = @("red", "green", "blue"),
        [string] $ChoiceLabelProperty,
        [ValidateSpectreColor()]
        [ArgumentCompletionsSpectreColors()]
        [string] $Color = $script:AccentColor.ToString(),
        [int] $PageSize = 5
    )
    $prompt = Get-SpectreSelection @PSBoundParameters
    $selected = Invoke-SpectrePromptAsync -Prompt $prompt

    if($ChoiceLabelProperty) {
        $selected = $Choices | Where-Object -Property $ChoiceLabelProperty -Eq $selected
    }

    return $selected
}

function Read-SpectreMultiSelection {
    param (
        [string] $Title = "What are your favourite [$($script:AccentColor.ToString())]colors[/]?",
        [array] $Choices = @("red", "orange", "yellow", "green", "blue", "indigo", "violet"),
        [string] $ChoiceLabelProperty,
        [ValidateSpectreColor()]
        [ArgumentCompletionsSpectreColors()]
        [string] $Color = $script:AccentColor.ToString(),
        [int] $PageSize = 5
    )
    $prompt = [Spectre.Console.MultiSelectionPrompt[string]]::new()

    $choiceLabels = $Choices
    if($ChoiceLabelProperty) {
        $choiceLabels = $Choices | Select-Object -ExpandProperty $ChoiceLabelProperty
    }

    $duplicateLabels = $choiceLabels | Group-Object | Where-Object { $_.Count -gt 1 }
    if($duplicateLabels) {
        Write-Error "You have duplicate labels in your select list, this is ambiguous so a selection cannot be made"
        exit 2
    }

    $prompt = [Spectre.Console.MultiSelectionPromptExtensions]::AddChoices($prompt, [string[]]$choiceLabels)
    $prompt.Title = $Title
    $prompt.PageSize = $PageSize
    $prompt.WrapAround = $true
    $prompt.HighlightStyle = [Spectre.Console.Style]::new([Spectre.Console.Color]::$Color)
    $prompt.InstructionsText = "[$($script:DefaultValueColor)](Press [$($script:AccentColor.ToString())]space[/] to toggle a choice and press [$($script:AccentColor.ToString())]<enter>[/] to submit your answer)[/]"
    $prompt.MoreChoicesText = "[$($script:DefaultValueColor)](Move up and down to reveal more choices)[/]"
    $selected = Invoke-SpectrePromptAsync -Prompt $prompt

    if($ChoiceLabelProperty) {
        $selected = $Choices | Where-Object -Property $ChoiceLabelProperty -Eq $selected
    }

    return $selected
}

function Read-SpectreMultiSelectionGrouped {
    param (
        [string] $Title = "What are your favourite [$($script:AccentColor.ToString())]colors[/]?",
        [array] $Choices = @(
            @{
                Name = "The rainbow"
                Choices = @("red", "orange", "yellow", "green", "blue", "indigo", "violet")
            },
            @{
                Name = "The other colors"
                Choices = @("black", "grey", "white")
            }
        ),
        [string] $ChoiceLabelProperty,
        [ValidateSpectreColor()]
        [ArgumentCompletionsSpectreColors()]
        [string] $Color = $script:AccentColor.ToString(),
        [int] $PageSize = 10
    )
    $prompt = [Spectre.Console.MultiSelectionPrompt[string]]::new()

    $choiceLabels = $Choices.Choices
    if($ChoiceLabelProperty) {
        $choiceLabels = $Choices | Select-Object -ExpandProperty $ChoiceLabelProperty
    }
    $duplicateLabels = $choiceLabels | Group-Object | Where-Object { $_.Count -gt 1 }
    if($duplicateLabels) {
        Write-Error "You have duplicate labels in your select list, this is ambiguous so a selection cannot be made (even when using choice groups)"
        exit 2
    }

    foreach($group in $Choices) {
        $choiceLabels = $group.Choices
        if($ChoiceLabelProperty) {
            $choiceLabels = $Choices | Select-Object -ExpandProperty $ChoiceLabelProperty
        }
        $prompt = [Spectre.Console.MultiSelectionPromptExtensions]::AddChoiceGroup($prompt, $group.Name, [string[]]$choiceLabels)
    }

    $prompt.Title = $Title
    $prompt.PageSize = $PageSize
    $prompt.WrapAround = $true
    $prompt.HighlightStyle = [Spectre.Console.Style]::new([Spectre.Console.Color]::$Color)
    $prompt.InstructionsText = "[$($script:DefaultValueColor)](Press [$($script:AccentColor.ToString())]space[/] to toggle a choice and press [$($script:AccentColor.ToString())]<enter>[/] to submit your answer)[/]"
    $prompt.MoreChoicesText = "[$($script:DefaultValueColor)](Move up and down to reveal more choices)[/]"
    $selected = Invoke-SpectrePromptAsync -Prompt $prompt

    if($ChoiceLabelProperty) {
        $selected = $Choices | Where-Object -Property $ChoiceLabelProperty -Eq $selected
    }

    return $selected
}

function Read-SpectreText {
    param (
        [string] $Question = "What's your name?",
        [string] $DefaultAnswer = "Prefer not to say"
    )
    $prompt = [Spectre.Console.TextPrompt[string]]::new($Question)
    $prompt.DefaultValueStyle = [Spectre.Console.Style]::new($script:DefaultValueColor)
    $prompt = [Spectre.Console.TextPromptExtensions]::DefaultValue($prompt, $DefaultAnswer)
    return Invoke-SpectrePromptAsync -Prompt $prompt
}

function Invoke-SpectreCommandWithStatus {
    param (
        [scriptblock] $ScriptBlock,
        [string] $Spinner,
        [string] $Title,
        [ValidateSpectreColor()]
        [ArgumentCompletionsSpectreColors()]
        [string] $Color = $script:AccentColor.ToString()
    )
    [Spectre.Console.AnsiConsole]::Status().Start($Title, {
        param (
            $ctx
        )
        $ctx.Spinner = [Spectre.Console.Spinner+Known]::$Spinner
        $ctx.SpinnerStyle = [Spectre.Console.Style]::new([Spectre.Console.Color]::$Color)
        & $ScriptBlock
    })
}

function Format-SpectreColumns {
    param (
        [array] $Columns
    )
    Write-SpectreConsole ([Spectre.Console.Columns]::new($Columns))
}

function Write-SpectreConsole {
    param (
        [object] $Renderable
    )
    [Spectre.Console.AnsiConsole]::Write($Renderable)
}

function Write-SpectreHost {
    param (
        [string] $Message,
        [switch] $NoNewline
    )
    if($NoNewline) {
        [Spectre.Console.AnsiConsole]::Markup($Message)
    } else {
        [Spectre.Console.AnsiConsole]::MarkupLine($Message)
    }
}

function Invoke-SpectreCommandWithProgress {
    param (
        [scriptblock] $ScriptBlock
    )
    [Spectre.Console.AnsiConsole]::Progress().Start({
        param (
            $ctx
        )
        & $ScriptBlock $ctx
    })
}

function Add-SpectreJob {
    param (
        [object] $Context,
        [string] $JobName,
        [System.Management.Automation.Job] $Job
    )

    return @{
        Job = $Job
        Task = $Context.AddTask($JobName)
    }
}

# Adapted from https://key2consulting.com/powershell-how-to-display-job-progress/
function Wait-SpectreJobs {
    param (
        [object] $Context,
        [array] $Jobs,
        [int] $TimeoutSeconds = 60
    )

    $timeout = (Get-Date).AddSeconds($TimeoutSeconds)

    while(!$Context.IsFinished) {
        if((Get-Date) -gt $timeout) {
            throw "Timed out waiting for jobs after $TimeoutSeconds seconds"
        }
        foreach($job in $Jobs) {
            $progress = 0.0
            if($null -ne $job.Job.ChildJobs[0].Progress) {
                $progress = $job.Job.ChildJobs[0].Progress | Select-Object -Last 1 -ExpandProperty "PercentComplete"
            }
            $job.Task.Value = $progress
        }
        Start-Sleep -Milliseconds 100
    }
}

function Format-SpectreBarChart {
    param (
        [Parameter(ValueFromPipeline)]
        [array] $Data,
        $Title,
        $Width = $Host.UI.RawUI.Width
    )
    begin {
        $barChart = [Spectre.Console.BarChart]::new()
        if($Title) {
            $barChart.Label = $Title
        }
        $barChart.Width = $Width
    }
    process {
        $barChart = [Spectre.Console.BarChartExtensions]::AddItem($barChart, $Data.Label, $Data.Value, $Data.Color)
    }
    end {
        [Spectre.Console.AnsiConsole]::Write($barChart)
    }
}

function Format-SpectreBreakdownChart {
    param (
        [Parameter(ValueFromPipeline)]
        [array] $Data,
        $Width = $Host.UI.RawUI.Width
    )
    begin {
        $chart = [Spectre.Console.BreakdownChart]::new()
        $chart.Width = $Width
    }
    process {
        $chart = [Spectre.Console.BreakdownChartExtensions]::AddItem($chart, $Data.Label, $Data.Value, $Data.Color)
    }
    end {
        [Spectre.Console.AnsiConsole]::Write($chart)
    }
}

function Get-SpectrePanel {
    param (
        [Parameter(ValueFromPipeline)]
        [string] $Data,
        [string] $Title,
        [ValidateSpectreBoxBorder()]
        [ArgumentCompletionsSpectreBoxBorders()]
        [string] $Border = "Rounded",
        [switch] $Expand, 
        [ValidateSpectreColor()]
        [ArgumentCompletionsSpectreColors()]
        [string] $Color = $script:AccentColor.ToString()
    )
    $panel = [Spectre.Console.Panel]::new($Data)
    if($Title) {
        $panel.Header = [Spectre.Console.PanelHeader]::new($Title)
    }
    $panel.Expand = $Expand
    $panel.Border = [Spectre.Console.BoxBorder]::$Border
    $panel.BorderStyle = [Spectre.Console.Style]::new([Spectre.Console.Color]::$Color)
    return $panel
}

function Write-SpectrePanel {
    param (
        [Parameter(ValueFromPipeline)]
        [string] $Data,
        [string] $Title,
        [ValidateSpectreBoxBorder()]
        [ArgumentCompletionsSpectreBoxBorders()]
        [string] $Border = "Rounded",
        [switch] $Expand, 
        [ValidateSpectreColor()]
        [ArgumentCompletionsSpectreColors()]
        [string] $Color = $script:AccentColor.ToString()
    )
    $panel = Get-SpectrePanel @PSBoundParameters
    [Spectre.Console.AnsiConsole]::Write($panel)
}

function Format-SpectreTable {
    # TODO fix this to be not crap and use a formatter or something
    param (
        [Parameter(ValueFromPipeline)]
        [array] $Data,
        [string] $Border = "Double",
        [ValidateSpectreColor()]
        [ArgumentCompletionsSpectreColors()]
        [string] $Color = $script:AccentColor.ToString()
    )
    begin {
        $table = [Spectre.Console.Table]::new()
        $table.Border = [Spectre.Console.TableBorder]::$Border
        $table.BorderStyle = [Spectre.Console.Style]::new([Spectre.Console.Color]::$Color)
        $headerProcessed = $false
    }
    process {
        if(!$headerProcessed) {
            $data[0].psobject.Properties.Name | Foreach-Object {
                $table.AddColumn($_) | Out-Null
            }
            
            $headerProcessed = $true
        }
        $row = @()
        $Data | Get-Member -MemberType Properties | Foreach-Object {
            if($null -eq $Data."$($_.Name)") {
                $row += [Spectre.Console.Text]::new("")
            } else {
                $row += [Spectre.Console.Text]::new($Data."$($_.Name)".ToString())
            }
        }
        $table = [Spectre.Console.TableExtensions]::AddRow($table, [Spectre.Console.Text[]]$row)
    }
    end {
        [Spectre.Console.AnsiConsole]::Write($table)
    }
}

function Format-SpectreTree {
    param (
        [Parameter(ValueFromPipeline)]
        [hashtable] $Data,
        [string] $Border = "Rounded",
        [ValidateSpectreColor()]
        [ArgumentCompletionsSpectreColors()]
        [string] $Color = $script:AccentColor.ToString()
    )

    function Add-SpectreTreeNode {
        param (
            $Node,
            $Children
        )
    
        foreach($child in $Children) {
            $newNode = [Spectre.Console.HasTreeNodeExtensions]::AddNode($Node, $child.Label)
            if($child.Children.Count -gt 0) {
                Add-SpectreTreeNode -Node $newNode -Children $child.Children
            }
        }
    }

    $tree = [Spectre.Console.Tree]::new($Data.Label)

    Add-SpectreTreeNode -Node $tree -Children $Data.Children

    $tree.Style = [Spectre.Console.Style]::new([Spectre.Console.Color]::$Color)
    [Spectre.Console.AnsiConsole]::Write($tree)
}

function Read-SpectrePause {
    param (
        [string] $Message = "[$script:DefaultValueColor]Press [$script:AccentColor]<enter>[/] to continue[/]",
        [switch] $NoNewline
    )

    $position = $Host.UI.RawUI.CursorPosition
    if(!$NoNewline) {
        Write-Host ""
    }
    Write-SpectreHost $Message -NoNewline
    Read-Host
    $endPosition = $Host.UI.RawUI.CursorPosition
    if($endPosition -eq $position) {
        # Reached the end of the window
        [Console]::SetCursorPosition($position.X, $position.Y - 2)
        Write-Host (" " * $Message.Length)
        [Console]::SetCursorPosition($position.X, $position.Y - 2)
    } else {
        [Console]::SetCursorPosition($position.X, $position.Y)
        Write-Host (" " * $Message.Length)
        [Console]::SetCursorPosition($position.X, $position.Y)
    }
}