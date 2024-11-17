[CmdletBinding()]
param (
    [Parameter(Mandatory = $false)]
    [ValidateScript({ $_ | Test-Path -PathType Container })]
    [string]
    $Path = ".",

    [Parameter(Mandatory = $false)]
    [ValidateScript({ $_ | Test-Path -PathType Leaf })]
    [string]
    $ConfigurationPath,

    [Parameter(Mandatory = $false)]
    [int]
    $Depth = 10
)

#* Import config file
$config = Get-Content $ConfigurationPath | ConvertFrom-Json -Depth 4 -AsHashtable -NoEnumerate

#* Change location to Path
Push-Location -Path $Path

#* Get directories
$rootDirectory = Get-Item -Path "."
$directories = Get-ChildItem -Recurse -Depth $Depth -Force -Directory
$directoriesToProcess = @(
    $rootDirectory
)

#* Process exclusions
foreach ($directory in $directories) {
    $directoryFullPath = $directory.FullName
    $directoryRelativePath = Resolve-Path -Relative -Path $directory.FullName
    
    #* Skip .git directory
    if ($directoryRelativePath -eq ".git" -or $directoryRelativePath -like ".git/*" -or $directoryRelativePath -like "*/.git" -or $directoryRelativePath -like "*/.git/*") {
        continue
    }
    
    #* Skip excluded directories
    $skip = $false
    foreach ($entry in $config.directoriesToExclude) {
        $entryFullPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($entry)

        if ("$directoryFullPath/".StartsWith("$entryFullPath/")) {
            $skip = $true
            break
        }
    }
    if ($skip) {
        Write-Debug "[$directoryRelativePath] - File is in directory in the 'directoriesToExclude' property in the configuration file. Skipping."
        continue
    }

    $directoriesToProcess += $directory
}

#* Initialize output object
$output = @{
    DeletedFiles       = @()
    DeletedDirectories = @()
}

#* Process files
$index_filehashes = @{}
foreach ($directory in $directoriesToProcess) {
    
    $files = Get-ChildItem -Path $directory.FullName -File -Force
    foreach ($file in $files) {
        $fileRelativePath = Resolve-Path -Relative -Path $file.FullName

        foreach ($entry in $config.filesToDelete) {
            if (Test-Path -Path $entry.path) {
                $entryRelativePath = Resolve-Path -Relative -Path $entry.path
                
                if ($fileRelativePath -eq $entryRelativePath) {
                    if (!$index_filehashes.ContainsKey($fileRelativePath)) {
                        $index_filehashes.Add($fileRelativePath, (Get-FileHash -Path $file.FullName).Hash)
                    }
                    $fileHash = $index_filehashes[$fileRelativePath]

                    if ($entry.hash -and $entry.hash -eq $fileHash -or $entry.hashes -contains $fileHash) {
                        Write-Host "[$fileRelativePath] - Matched hash. Deleting file. Hash [$fileHash]"
                        $file | Remove-Item -Force -Confirm:$false
                        $output.DeletedFiles += $fileRelativePath
                    }
                    else {
                        Write-Debug "[$fileRelativePath] - No matching hashes. Skipping"
                    }
                }
            }
        }
    }
}

#* Delete empty directories
foreach ($directory in ($directoriesToProcess | Sort-Object -Descending { $_.FullName.Split("/").Count })) {
    $directoryFullPath = $directory.FullName
    $directoryRelativePath = Resolve-Path -Relative -Path $directory.FullName
        
    if ($directory.GetFiles().Count -eq 0 -and $directory.GetDirectories().Count -eq 0) {
        Write-Host "[$directoryRelativePath] - Directory is empty. Deleting directory."
        $directory | Remove-Item -Force -Confirm:$false
        $output.DeletedDirectories += $directoryRelativePath
    }
    else {
        Write-Debug "[$directoryRelativePath] - Directory is not empty. Skipping"
    }
}

Pop-Location

#* Return
return $output