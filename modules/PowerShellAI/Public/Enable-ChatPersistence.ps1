function Enable-ChatPersistence {
    <#
        .SYNOPSIS
        Enables chat persistence.

        .DESCRIPTION
        The Enable-ChatPersistence function sets the $Script:ChatPersistence variable to $true, which enables chat persistence.

        .EXAMPLE
        Enable-ChatPersistence
    #>

    $Script:ChatPersistence = $true
}