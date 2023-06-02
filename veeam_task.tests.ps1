Describe "Sync-Directory Tests" {
    BeforeAll {
        # Define the paths for the test folders
        $sourcePath = "$PSSCriptRoot\Tests\Source"
        $destinationPath = "$PSSCriptRoot\Tests\Destination"

        # Create the test folders
        New-Item -ItemType Directory -Path $sourcePath
        New-Item -ItemType Directory -Path $destinationPath
        
        # Create subfolders
        New-Item -ItemType Directory -Path "$sourcePath\SubFolder1"
        New-Item -ItemType Directory -Path "$sourcePath\SubFolder2"

        # Create some test files in the source folder
        New-Item -ItemType File -Path (Join-Path -Path $sourcePath -ChildPath "File1.txt") -Force
        New-Item -ItemType File -Path (Join-Path -Path $sourcePath -ChildPath "File2.txt") -Force
        New-Item -ItemType File -Path (Join-Path -Path "$sourcePath\SubFolder1" -ChildPath "File3.txt") -Force
        New-Item -ItemType File -Path (Join-Path -Path "$sourcePath\SubFolder2" -ChildPath "File4.txt") -Force

        # Load Sync-Directory function
        . "$PSScriptRoot\veeam_task.ps1"
    }
    AfterAll {
        # Clean up the test folders and files
        Remove-Item -Path "$PSSCriptRoot\Tests" -Recurse -Force
    }
    Context "Positive Tests" {
        It "Should synchronize files from source to destination" {
            # Run the Sync-Directory function
            Sync-Directory -Source "$PSSCriptRoot\Tests\Source" -Destination "$PSSCriptRoot\Tests\Destination" -LogFilePath "$PSSCriptRoot\Tests\Log.txt"

            # Check if the files are synchronized in the destination folder
            $destinationFiles = Get-ChildItem -Path "$PSSCriptRoot\Tests\Destination" -Recurse -File
            ($destinationFiles.directory | Select-Object -ExpandProperty name -unique) | Should -Contain "Subfolder1"
            ($destinationFiles.directory | Select-Object -ExpandProperty name -unique) | Should -Contain "Subfolder2"
            $destinationFiles | Should -HaveCount 4
            $destinationFiles.name | Should -Contain "File1.txt"
            $destinationFiles.name | Should -Contain "File2.txt"
            $destinationFiles.name | Should -Contain "File3.txt"
            $destinationFiles.name | Should -Contain "File4.txt"
            (Split-path $destinationFiles[2].Directory.fullname -Leaf) | Should -Be "SubFolder1"
            (Split-path $destinationFiles[3].Directory.fullname -Leaf) | Should -Be "SubFolder2"
        }
        It "Should remove items when a file is removed from the source" {
            # Remove a file from the source
            Remove-Item "$sourcePath\File1.txt" -Force
            # Run the sync function again
            Sync-Directory -Source "$PSSCriptRoot\Tests\Source" -Destination "$PSSCriptRoot\Tests\Destination" -LogFilePath "$PSSCriptRoot\Tests\Log_2.txt" -Force
            # Check if files are synchronized in the destination folder
            $destinationFiles = Get-ChildItem -Path "$PSSCriptRoot\Tests\Destination" -Recurse -File
            $destinationFiles.name | Should -Not -Contain "File1.txt"
        }
        It "Generates log files" {
            Test-Path $PSScriptRoot\Tests\Log.txt | Should -BeTrue
            Test-Path $PSScriptRoot\Tests\Log_2.txt | Should -BeTrue
        }
    }
    Context "Negative tests" {        
        It "Errors out when any of the folder parameters arguments are not directories" {
            { Sync-Directory -Source "$PSSCriptRoot\Tests\Source\file1.txt" -Destination "$PSSCriptRoot\Tests\Destination" -LogFilePath "$PSSCriptRoot\Tests\Log.txt" } | Should -Throw
        }        
    }
}