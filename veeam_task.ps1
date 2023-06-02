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
        [string]$Source,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({
                $path = $_
                (Test-Path $path) -and (Get-Item $path).PSIsContainer
            })]
        [string]$Destination,

        [Parameter(Mandatory = $false)]
        [string]$LogFilePath = (Join-Path -Path $PSScriptRoot -ChildPath "SyncDirectory_Log_$(Get-Date -Format 'dd-MM_hh-mm-ss').txt"),

        [Parameter(Mandatory = $false)]
        [switch]$Force
    )
    begin {
        Write-Verbose "Generating log file: $LogFilePath"

        # Open the log file with a filestream instance for both synchronous and asynchronous read and write operations.
        $fileStream = [System.IO.File]::Open($LogFilePath, 'Append', 'Write', 'Read')
        $fileWriter = [System.IO.StreamWriter]::new($fileStream)

        # Let's log all script operation
        try {
            Start-Transcript -Path $LogFilePath -Append
        }
        catch {
            Write-Log -ErrorMessage "Error starting transcript: $($_.Exception.Message)"
        }

        # Let's read and count all files on source and destination folders
        Write-Verbose -message "Reading source files..."
        $sourceFiles = Get-ChildItem -Path $Source -Recurse -File
        Write-Log -message "Source files count: $($sourceFiles.count)"

        Write-Verbose -message "Reading destination files..."
        $destinationFiles = Get-ChildItem -Path $Destination -Recurse -File
        Write-Log -message "Destination files count: $($destinationFiles.count)"
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
                    Write-Log -message "Copy directory $($file.Directory.FullName) => $destinationSubFolder..."
                    try {
                        New-Item -ItemType Directory -Path $destinationSubfolder -Force -ErrorAction Stop | Out-Null
                    }
                    catch {
                        Write-Log -ErrorMessage "Failed to create directory: $destinationSubfolder. Error: $($_.Exception.Message)"
                        # Using return will exit the process block in case of a failure here and move to the end block where we need to do some cleanup operations
                        return
                    }
                }
                # Copy file to destination
                Write-Log -message "Copy file $($file.fullname) => $destinationPath"
                try {
                    bla
                    Copy-Item -Path $file.FullName -Destination $destinationPath -Force -ErrorAction Stop
                }
                catch {
                    Write-Log -ErrorMessage "Failed to copy file: $($file.fullname) => $destinationPath. Error: $($_.Exception.Message)"
                    # Using return will exit the process block in case of a failure here and move to the end block where we need to do some cleanup operations
                    return
                }
            }
        }
        # Remove any files in destination folder that no longer exists in source folder
        foreach ($file in $destinationFiles) {
            Write-Verbose "Verifying files that no longer exists in the source..."
            $sourcePath = Join-Path -Path $source -ChildPath $file.FullName.replace($destination, "")
            if (-not (Test-Path -Path $sourcePath)) {
                Write-Log "Removing file $($file.Fullname)"
                if (($Force.IsPresent) -or ($PSCmdlet.ShouldProcess("Remove $($file.fullname)"))) {
                    Remove-Item -Path $file.FullName -Force
                }
            }
        }
    }
    end {
        # Update the files count after operation is done
        $sourceFiles = Get-ChildItem -Path $Source -Recurse -File
        Write-Log -message "Source files final count: $($sourceFiles.count)"
        $destinationFiles = Get-ChildItem -Path $Destination -Recurse -File
        Write-Log -message "Destination files final count: $($destinationFiles.count)"        
        # Clean up file streams and stop transcript
        $fileWriter.Dispose()
        $fileStream.Dispose()
        try {
            Stop-Transcript
        }
        catch {
            Write-Log -ErrorMessage "Error stopping transcript: $($_.Exception.Message)"
        }
    }
}

# Let's create a helper function for fine grained customized logging
function Write-Log($Message, $ErrorMessage) {
    if ($Message) {
        Write-Output "[INFO]: $Message"
        $fileWriter.WriteLine("[INFO]: $Message")
    }
    if ($ErrorMessage) {
        Write-Error "[ERROR]: $ErrorMessage"
        $fileWriter.WriteLine("[ERROR] $ErrorMessage")
    }
}