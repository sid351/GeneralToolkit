<#

    General Toolkit

#>

Function Confirm-ModuleAvailable
{
[cmdletbinding()]
Param( [string][alias("ModuleName")]$name )

    If((Get-Module -Name $name) -eq $null)
    {
        Write-Verbose -Message "$name is not already loaded"

        If((Get-Module -ListAvailable | Where-Object -FilterScript {$_.Name -eq $name}) -ne $null)
        {
            Import-Module -Name $name -Global
            Write-Output "Module $Name has been loaded."
        }
        else
        {
            Write-Error -Message "ERROR: PowerShell Module '$name' cannot be found on this system. $([environment]::NewLine)Check the module exists under one of the following locations and the user account ($($env:USERDOMAIN)\$($env:USERNAME)) has sufficient permissions to access it: $([Environment]::NewLine)$($env:PSModulePath.Split(";") -join [Environment]::NewLine)"
        }
    }
    else
    {
        Write-Output "$name is already loaded"
    }
}

function Confirm-PathExists
{
[cmdletbinding()]
Param(
    $path, 
    $itemType = "Directory"
    )

    If(-not (Test-Path -Path $path))
    {
        New-Item -Path $path -ItemType $itemType
    }    
}


function Add-LogEntry
{
param(
[Parameter(Position=0, ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true)]$message,
[Parameter(Position=1)]$path)
    $logDate = (get-date -format "yyyy-MM-dd HH:mm:ss")
    $logEntry = $logDate+"`t"+$message
    $logFile = $path
    add-content $logFile $logEntry

<#
.SYNOPSIS
    Adds an entry with the date in ISO format prefixed to the input message

.DESCRIPTION
    Essentially this just wraps Add-Content with the addition of prefixing the date.

    Use splatting to define the Path at the begining of any scripts to simplify calling this; see the examples
    
.PARAMETER  Message
    The is the log message that will be pre-fixed with the system time in ISO format (yyyy-MM-dd HH:mm:ss)

    This is accepted from the pipeline and is also positional (position 0 - the first item)

.PARAMETER  Path
    The full file path of the log file output, including file extension.

    This is also positional (position 1 - the second item)

.EXAMPLE
    Add-LogEntry -message "Hello World" -path "C:\Testing\Test.log"

    When run at 11:23 on the 2nd of October 2013 this will add the following to the Log File:

    2013-10-02 11:23:36 Hello World
        
    NOTE: the gap between the time and the message is really a TAB character (`t)

.EXAMPLE
    $addLogParam = @{path="$($env:SystemDrive)\Testing\Test.log"

    Add-LogEntry "Hello World" @addLogParam

.EXAMPLE
    $addLogParam = @{path="$($env:SystemDrive)\Testing\Test.log"

    Get-ChildItem $env:SystemDrive | Sort-Object -Descending -Property CreationTimeUTC | Select-Object -First 1 | Add-LogEntry @addLogParam

    This gathers the child items of the System Drive         --> Get-ChildItem $env:SystemDrive
    Sorts them by their CreationTimeUTC in descending order  --> Sort-Object -Descending -Property CreationTimeUTC 
    Selects the first item in the list                       --> Select-Object -First 1
    Adds the file name (not full path) to the log file       --> Add-LogEntry @addLogParam

.NOTES
    Revision history:
    ------------------------------------------------------------------------------------------------------------
    Version 1 - Owen Ballentine
    ------------------------------------------------------------------------------------------------------------
    
#>
}