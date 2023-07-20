class ValidateSpectreColor : System.Management.Automation.ValidateArgumentsAttribute 
{
    ValidateSpectreColor() : base() { }
    [void]Validate([object] $Color, [System.Management.Automation.EngineIntrinsics]$EngineIntrinsics) {
        $spectreColors = [Spectre.Console.Color] | Get-Member -Static -Type Properties | Select-Object -ExpandProperty Name
        $result = $spectreColors -contains $Color
        if($result -eq $false) {
            throw "'$Color' is not in the list of valid Spectre colors ['$($spectreColors -join ''', ''')']" 
        }
    }
}

class ArgumentCompletionsSpectreColors : System.Management.Automation.ArgumentCompleterAttribute 
{
    ArgumentCompletionsSpectreColors() : base({
        [Spectre.Console.Color] | Get-Member -Static -Type Properties | Select-Object -ExpandProperty Name
    }) { }
}

class ValidateSpectreBoxBorder : System.Management.Automation.ValidateArgumentsAttribute 
{
    ValidateSpectreBoxBorder() : base() { }
    [void]Validate([object] $BoxBorder, [System.Management.Automation.EngineIntrinsics]$EngineIntrinsics) {
        $spectreBoxBorders = [Spectre.Console.BoxBorder] | Get-Member -Static -Type Properties | Select-Object -ExpandProperty Name
        $result = $spectreBoxBorders -contains $BoxBorder
        if($result -eq $false) {
            throw "'$BoxBorder' is not in the list of valid Spectre box borders ['$($spectreBoxBorders -join ''', ''')']" 
        }
    }
}

class ArgumentCompletionsSpectreBoxBorders : System.Management.Automation.ArgumentCompleterAttribute 
{
    ArgumentCompletionsSpectreBoxBorders() : base({
        [Spectre.Console.BoxBorder] | Get-Member -Static -Type Properties | Select-Object -ExpandProperty Name
    }) { }
}