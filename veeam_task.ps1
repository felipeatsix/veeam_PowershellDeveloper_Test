function Sync-Directory {
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
        $fileStream = [System.IO.File]::Open($LogFilePath, 'Append', 'Write', 'Read')
        $fileWriter = [System.IO.StreamWriter]::new($fileStream)
        try {
            Start-Transcript -Path $LogFilePath -Append
        }
        catch {
            Write-Log -ErrorMessage "Error starting transcript: $($_.Exception.Message)"
        }

        Write-Verbose -message "Reading source files..."
        $sourceFiles = Get-ChildItem -Path $Source -Recurse -File
        Write-Log -message "Source files count: $($sourceFiles.count)"
        
        Write-Verbose -message "Reading destination files..."
        $destinationFiles = Get-ChildItem -Path $Destination -Recurse -File
        Write-Log -message "Destination files count: $($destinationFiles.count)"
    }
    process {
        # For each source file that does not exist in destination, copy it over.
        # If a given file is contained in a subfolder, copy the subfolder first.
        foreach ($file in $sourceFiles) {            
            $destinationPath = Join-Path -Path $destination -ChildPath $file.fullname.replace($source, "")
            $destinationFile = Get-Item -Path $destinationPath -ErrorAction SilentlyContinue

            if (-not $destinationFile -or $file.LastWriteTime -gt $destinationFile.LastWriteTime) {
                $destinationSubfolder = Split-Path -Path $destinationPath -Parent
                if (-not (Test-Path -Path $destinationSubfolder)) {
                    Write-Log -message "Copy directory $($file.Directory.FullName) => $destinationSubFolder..."
                    try {
                        New-Item -ItemType Directory -Path $destinationSubfolder -Force -ErrorAction Stop | Out-Null
                    }
                    catch {
                        Write-Log -ErrorMessage "Failed to create directory: $destinationSubfolder. Error: $($_.Exception.Message)"
                        throw
                    }
                }
                # Copy file to destination
                Write-Log -message "Copy file $($file.fullname) => $destinationPath"
                try {
                    Copy-Item -Path $file.FullName -Destination $destinationPath -Force -ErrorAction Stop
                }
                catch {
                    Write-Log -ErrorMessage "Failed to copy file: $($file.fullname) => $destinationPath. Error: $($_.Exception.Message)"
                    throw
                }                
            }
        }
        # For each file that exists in destination but no longer exists in source, remove it.
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
        try {
            Stop-Transcript
        }
        catch {
            Write-Log -ErrorMessage "Error stopping transcript: $($_.Exception.Message)"
        }                
        $sourceFiles = Get-ChildItem -Path $Source -Recurse -File
        Write-Log -message "Source files final count: $($sourceFiles.count)"
        $destinationFiles = Get-ChildItem -Path $Destination -Recurse -File
        Write-Log -message "Destination files final count: $($destinationFiles.count)"
        $fileWriter.Dispose()
        $fileStream.Dispose()
    }
}

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
