<#

    General Toolkit

#>

Function Confirm-RunningElevated
{
[cmdletbinding()]
[OutputType([bool])]
Param()
    If(([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator"))
    {
        Write-Output $true
    }
    else
    {
        Write-Output $false
    }
}

Function Resume-AsElevated
{
[cmdletbinding()]
Param(
    $scriptFilePath
    #Easily obtained from $myInvocation.MyCommand.Definition
    )

    If (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator"))
    {
        # We are not running "as Administrator" - so relaunch as administrator
   
        # Create a new process object that starts PowerShell
        $newProcess = new-object System.Diagnostics.ProcessStartInfo "PowerShell"
   
        # Specify the current script path and name as a parameter
        $newProcess.Arguments = $scriptFilePath
   
        # Indicate that the process should be elevated
        $newProcess.Verb = "runas"
   
        # Start the new process
        [System.Diagnostics.Process]::Start($newProcess)
   
        # Exit from the current, unelevated, process
        exit   
    }
}
<#

.LINK
    http://blogs.msdn.com/b/virtual_pc_guy/archive/2010/09/23/a-self-elevating-powershell-script.aspx

#>

Function Add-ModuleParentFolder
{
[cmdletbinding()]
Param(
    $path = (Get-Location | Select-Object -ExpandProperty Path)
)

    If(-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator"))
    {
        Write-Warning -Message "You do not have Administrator rights.`nPlease re-run this script as an Administrator!"
        Break
    }

    #Adds $path to the PSModulePath environment variable

    $currentPathList = [Environment]::GetEnvironmentVariable("PSModulePath")
    
    If($currentPathList.Split(";").Trim().ToLower() -contains $path.Trim().ToLower())
    {
        Write-Output "$path already exists in PSModulePath"
    }
    Else
    {
        $currentPathList += ";$path"
        [Environment]::SetEnvironmentVariable("PSModulePath",$currentPathList, "Machine")
        Write-Output "$path has been added to PSModulePath. Restart PowerShell to complete the addition."
    }

}
<#
.SYNOPSIS
    Adds -Path to the PSModulePath environment variable, so modules underneath this parent directory can be loaded in future.

    Path defaults to the current path if not defined.

    Requires admin rights as it is making a change to the registry in the backend.

    PowerShell must be restarted to access the updated environment variable.
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
            Write-Verbose -Message "Module $Name has been loaded."
            Write-Output "Module $Name has been loaded."
        }
        else
        {
            Write-Error -Message "ERROR: PowerShell Module '$name' cannot be found on this system. $([environment]::NewLine)Check the module exists under one of the following locations and the user account ($($env:USERDOMAIN)\$($env:USERNAME)) has sufficient permissions to access it: $([Environment]::NewLine)$($env:PSModulePath.Split(";") -join [Environment]::NewLine)"
        }
    }
    else
    {
        Write-Verbose -Message "$name is already loaded"
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

Function Confirm-FilesExist
{
[cmdletbinding()]
Param(
    [parameter(Mandatory=$True,ValueFromPipeline=$True,ValueFromPipelinebyPropertyName=$True)][string]$sourceFolder,
        #Full Path to the Source Folder
    [string]$fileExtensionFilter = "*",
        #The filter string to use for the file extension
    [int]$numDaysSinceLastWriteTime = 0,
        #The number of days since the last write time (inclusive) to keep files for
    [int]$numMinFilesToKeep = 1,
        #The minimum number of files that should remain in the folder after older items are deleted
    [int64]$minSizeInBytes = 0,
        #The minimum file size in bytes.  Use the KB, MB and GB operators to determine exact values for larger sizes.
    [switch]$recurse,
        #Recurse through the sub-directories
    [switch]$force
        #Force the action
    )


    [scriptBlock]$fileFilter = {$_.Length -ge $minSizeInBytes}

    If($numDaysSinceLastWriteTime -gt 0)
    {
        $fileFilter = {$fileFilter.ToString() -and $_.LastWriteTime -ge (Get-Date).AddDays(-$numDaysSinceLastWriteTime)}
    }

    [bool]$filesExist = [bool]((Get-ChildItem -File -Path $sourceFolder -Filter $fileExtensionFilter -Recurse:$recurse -Force:$force |
                          Where-Object -FilterScript $fileFilter |
                           Measure-Object |
                            Where-Object -FilterScript {$_.Count -ge $numMinFilesToKeep}
                               ) -ne $null)
    
    $output = New-Object -TypeName PSCustomObject -Property @{
        filesExist = $true
        sourceFolder = $sourceFolder
        fileExtensionFilter = $fileExtensionFilter
        numDaysSinceLastWriteTime = $numDaysSinceLastWriteTime
        recurse = $recurse
        force = $force
    }

    Write-Output $output
}
<#
.NOTES 
    Requires v3+ because of how Get-ChildItem is called

.DESCRIPTION
    Returns a custom object. Use the "filesExist" output for boolean logic.  The other parameters are provided for piping to other cmdlets and functions.
    
    Checks that there are at least (more than or equal to) -numMinFilesToKeep files 
     matching the -fileExtensionFilter 
      that are at least -minSizeInBytes bytes
       and have been last written to since -numDaysSinceLastWriteTime days ago (inclusive).
#>

Function Remove-ObsoleteFiles
{
[cmdletbinding()]
Param(
    [parameter(Mandatory=$True,ValueFromPipeline=$True,ValueFromPipelinebyPropertyName=$True)][string]$sourceFolder,
        #Full Path to the Source Folder
    [parameter(ValueFromPipelinebyPropertyName=$True)][string]$fileExtensionFilter = "*",
        #The filter string to use for the file extension
    [parameter(ValueFromPipelinebyPropertyName=$True)][int]$numDaysSinceLastWriteTime = 0,
        #The number of days since the last write time (inclusive) to keep files for
    [parameter(ValueFromPipelinebyPropertyName=$True)][switch]$recurse,
        #Recurse through the sub-directories
    [parameter(ValueFromPipelinebyPropertyName=$True)][switch]$force,
        #Force the action
    [parameter(ValueFromPipelinebyPropertyName=$True)][switch]$whatIf
        #Simulate the action
    )

        Get-ChildItem -File -Path $sourceFolder -Filter "$fileExtensionFilter" -Recurse:$recurse -Force:$force |
         Where-Object -FilterScript {$_.LastWriteTime -lt (Get-Date).AddDays(-$numDaysSinceLastWriteTime)} |
          Remove-Item -Force:$force -WhatIf:$whatIf
}
<#
.NOTES 
    Requires v3+ because of how Get-ChildItem is called

.DESCRIPTION
    Does not return any objects.

    Will remove items from the -sourceFolder
     that match the optional -fileExtensionFilter
      and have not been written to since -numDaysSinceLastWriteTime ago
#>