function Disable-ChatPersistence {
    <#
        .SYNOPSIS
        Disables chat persistence.

        .DESCRIPTION
        This function disables chat persistence by setting the $ChatPersistence variable to $false.

        .EXAMPLE
        Disable-ChatPersistence
    #>
    $Script:ChatPersistence = $false
}