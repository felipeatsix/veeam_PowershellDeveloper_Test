function Sync-Directory {
    <#
    .SYNOPSIS
    Synchronizes two folders, source and replica

    .DESCRIPTION
    This function will synchronize a source folder within a replica folder on every run.
    If any content is removed from source, that content would be removed from the replica on next run, keeping content exactly the same on every run.
    The script will also copy subfolder structures, but it won't remove subfolders, only its contents if necessary.

    .PARAMETER Source
    [MANDATORY] Provides the source folder absolute path

    .PARAMETER Destination
    [MANDATORY] Provides the destination folder absolute path

    .PARAMETER LogFilePath
    [OPTIONAL] Provides a path and a file name for logging.
    If no path is provided, a new .txt file is going to be auto generated on same path as the script location.

    .PARAMETER IncludeLogTime
    [OPTIONAL] Includes the date for the information messages in the log file in the format "dd-MM_hh-ss"

    .PARAMETER Force
    [OPTIONAL] It surpasses the confirmation prompt when files needs to be removed from replica folder.

    .EXAMPLE
    Sync-Directory -Source c:\source -Destination c:\destination -LogFilePath c:\log.txt
    This command will synchronize folder c:\source within c:\destination and log the whole operation in c:\log.txt

    .EXAMPLE
    Sync-Directory -Source c:\source -Destination c:\destination -LogFilePath c:\log.txt -Force
    This command will do exactly the same as example 1, but it will surpass confirmation prompt in case files needs to be removed from destination.
#>
    [Cmdletbinding(SupportsShouldProcess = $true, ConfirmImpact = "High")]
    Param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({
                $path = $_
                (Test-Path $path) -and (Get-Item $path).PSIsContainer
            })]
        [string] $Source,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({
                $path = $_
                (Test-Path $path) -and (Get-Item $path).PSIsContainer
            })]
        [string] $Destination,

        [Parameter(Mandatory = $false)]
        [string] $LogFilePath = (Join-Path -Path $PSScriptRoot -ChildPath "SyncDirectory_Log_$(Get-Date -Format 'dd-MM_hh-mm-ss').txt"),

        [Parameter(Mandatory = $false)]
        [switch] $IncludeLogTime,

        [Parameter(Mandatory = $false)]
        [switch] $Force
    )
    begin {
        Write-Verbose "Generating log file: $LogFilePath"

        # Open the log file with a filestream instance for asynchronous write operations from Write-Log helper function
        $fileStream = [System.IO.File]::Open($LogFilePath, 'Append', 'Write', 'Read')
        $fileWriter = [System.IO.StreamWriter]::new($fileStream)

        $baseLogParams = @{
            InformationLevel = $null
            FileWriter       = $fileWriter
            Message          = $null
            IncludeLogTime   = $IncludeLogTime.IsPresent
        }
        $logInfo = $baseLogParams.Clone()
        $logInfo.InformationLevel = "Info"
        $logError = $baseLogParams.Clone()
        $logError.InformationLevel = "Error"

        # Let's read and count all files on source and destination folders
        Write-Verbose -message "Reading source files..."
        $sourceFiles = Get-ChildItem -Path $Source -Recurse -File
        $logInfo.Message = "Source files count: $($sourceFiles.count)"
        Write-Log @logInfo

        Write-Verbose -message "Reading destination files..."
        $destinationFiles = Get-ChildItem -Path $Destination -Recurse -File
        $logInfo.Message = "Destination files count: $($destinationFiles.count)"
        Write-Log @logInfo
    }
    process {
        foreach ($file in $sourceFiles) {
            # For each file in source file, build the destination path for it and then use Get-Item to later verify if it is already synchronized or not
            $destinationPath = Join-Path -Path $destination -ChildPath $file.fullname.replace($source, "")
            $destinationFile = Get-Item -Path $destinationPath -ErrorAction SilentlyContinue

            # Verify file state
            if (-not $destinationFile -or $file.LastWriteTime -gt $destinationFile.LastWriteTime) {
                # In case file is not in sync state, verify if it is contained within a subfolder, if so, create the folder first
                $destinationSubfolder = Split-Path -Path $destinationPath -Parent
                if (-not (Test-Path -Path $destinationSubfolder)) {
                    $logInfo.Message = "Copying directory $($file.Directory.FullName) => $destinationSubFolder..."
                    Write-Log @logInfo
                    try {
                        New-Item -ItemType Directory -Path $destinationSubfolder -Force -ErrorAction Stop | Out-Null
                    }
                    catch {
                        $logError.Message = "Failed to create directory: $destinationSubfolder. Error: $($_.Exception.Message)"
                        Write-Log @logError
                        # Exit process block and jump to end block
                        return
                    }
                }
                # Copy file to destination
                $logInfo.Message = "Copying file $($file.fullname) => $destinationPath"
                Write-Log @logInfo
                try {
                    Copy-Item -Path $file.FullName -Destination $destinationPath -Force -ErrorAction Stop
                }
                catch {
                    $logError.Messsage = "Failed to copy file: $($file.fullname) => $destinationPath. Error: $($_.Exception.Message)"
                    Write-Log @logError
                    # Exit process block and jump to end block
                    return
                }
            }
        }
        # Remove any files in destination folder that no longer exists in source folder
        Write-Verbose "Verifying files that no longer exists in the source..."
        foreach ($file in $destinationFiles) {
            $sourcePath = Join-Path -Path $source -ChildPath $file.FullName.replace($destination, "")
            if (-not (Test-Path -Path $sourcePath)) {
                $logInfo.Message = "Removing file $($file.Fullname)"
                Write-Log @logInfo
                if (($Force.IsPresent) -or ($PSCmdlet.ShouldProcess("Remove $($file.fullname)"))) {
                    try {
                        Remove-Item -Path $file.FullName -Force
                    }
                    catch {
                        $logError.Message = "Failed to remove file: $($file.FullName)"
                        Write-Log @logError
                    }
                }
            }
        }
    }
    end {
        # Update the files count after operation is done
        $sourceFiles = Get-ChildItem -Path $Source -Recurse -File
        $logInfo.Message = "Source files final count: $($sourceFiles.count)"
        Write-Log @logInfo
        $destinationFiles = Get-ChildItem -Path $Destination -Recurse -File
        $logInfo.Message = "Destination files final count: $($destinationFiles.count)"
        Write-Log @logInfo
        # Clean up file streams
        $fileWriter.Dispose()
        $fileStream.Dispose()
    }
}
# Let's create a wrapper function for fine grained customized logging
function Write-Log {
    Param(
        [string] $Message,

        [ValidateSet("Info", "Error")]
        [string] $InformationLevel,

        [System.IO.StreamWriter] $FileWriter,

        [switch] $IncludeLogTime
    )
    $text = $null
    if ($IncludeLogTime) {
        $text = "[$(Get-Date -Format "dd-MM_hh-mm")]"
    }
    switch ($InformationLevel) {
        "INFO" {
            $text += "[INFO]: $Message"
            Write-Output $text
        }
        "ERROR" {
            $text += "[ERROR]: $Message"
            Write-Error $text
        }
    }
    $FileWriter.WriteLine($text)
}