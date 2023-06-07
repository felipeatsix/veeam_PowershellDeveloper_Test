# veeam_PowershellDeveloper_Test
QA Integration Team test

## Challenge Criteria
- Implement a script that synchronizes two folders: source and replica.<br>
- The script should maintain a full, identical copy of source folder at replica folder.<br>
- The task should be done only using native PowerShell cmdlets.<br>
- Synchronization must be one-way: after the synchronization content of the replica folder should be modified to exactly match content of the source folder.
- File creation/copying/removal operations should be logged to a file and to the console output.<br>
- Folder paths and log file path should be provided using the command line arguments.<br>
- Do not use robocopy and similar utilities.

## My Solution Syntax
```Powershell
Sync-Directory [-Source] <String> [-Destination] <String> [[-LogFilePath] <String>] [-IncludeLogTime] [-Force] [-WhatIf] [-Confirm] [CommonParameters]
```

## My Solution Example
```Powershell
Sync-Directory -Source c:\source -Destination c:\destination -LogFilePath c:\log.txt
```

## Limitations
- Subfolders won't be deleted from destination folders, only its contents.
- `Source` and `Destination` parameters won't work with `relative paths`.