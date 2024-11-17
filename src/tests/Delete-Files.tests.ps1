Describe "Delete-Files.ps1" {
    BeforeAll {
        $script:mockDirectory = "$PSScriptRoot/mock"
    }
    
    AfterAll {
        Remove-Item -Path $script:mockDirectory -Recurse -Force -Confirm:$false -ErrorAction Ignore
    }

    Context "When a file matches the path, but not the hash" {
        BeforeAll {
            New-Item -ItemType Directory -Path "$script:mockDirectory" -Force -Confirm:$false | Out-Null
            "content1" | Out-File -FilePath "$script:mockDirectory/fileToDelete.txt"
            "content2" | Out-File -FilePath "$script:mockDirectory/fileToDelete2.txt"
            "content3" | Out-File -FilePath "$script:mockDirectory/fileDontDelete.txt"
            New-Item -ItemType Directory -Path "$script:mockDirectory/dirToDelete" -Force -Confirm:$false | Out-Null
            New-Item -ItemType Directory -Path "$script:mockDirectory/dirDontDelete" -Force -Confirm:$false | Out-Null
            "subcontent2" | Out-File -FilePath "$script:mockDirectory/dirDontDelete/fileDontDelete.txt"
            New-Item -ItemType Directory -Path "$script:mockDirectory/dirDontDeleteDepth2/subDirDepth3/subDirDepth4" -Force -Confirm:$false | Out-Null
            "subcontent1" | Out-File -FilePath "$script:mockDirectory/dirDontDeleteDepth2/subDirDepth3/subDirDepth4/fileDontDeleteDepth5.txt"

            @{
                filesToDelete        = @(
                    @{
                        path   = "$script:mockDirectory/fileDontDelete.txt"
                        hashes = @(
                            "3A888546831AE05A0EC1D040DE396262284E4B4FC0066A00D56016BF3955C90E"
                        )
                    }
                    @{
                        path   = "$script:mockDirectory/fileToDelete.txt"
                        hashes = @(
                            "3A888546831AE05A0EC1D040DE396262284E4B4FC0066A00D56016BF3955C90E"
                            (Get-FileHash -Path "$script:mockDirectory/fileToDelete.txt").Hash
                        )
                    }
                    @{
                        path = "$script:mockDirectory/fileToDelete2.txt"
                        hash = (Get-FileHash -Path "$script:mockDirectory/fileToDelete2.txt").Hash
                    }
                    @{
                        path   = "$script:mockDirectory/dirDontDelete/fileDontDelete.txt"
                        hashes = @(
                            (Get-FileHash -Path "$script:mockDirectory/dirDontDelete/fileDontDelete.txt").Hash
                        )
                    }
                )
                directoriesToExclude = @(
                    "dirDontDelete"
                )

            } | ConvertTo-Json -Depth 4 | Out-File -FilePath config.json

            $script:res = ./src/Delete-Files.ps1 -Path $script:mockDirectory -ConfigurationPath config.json -Depth 5
        }

        AfterAll {
            Remove-Item -Path config.json -Force -Confirm:$false
            Remove-Item -Path $script:mockDirectory -Recurse -Force -Confirm:$false
        }

        It "Should output the correct files and directories" {
            $script:res.DeletedFiles | Should -HaveCount 2
            $script:res.DeletedFiles | Should -Contain "./fileToDelete.txt"
            $script:res.DeletedDirectories | Should -HaveCount 1
            $script:res.DeletedDirectories | Should -Contain "./dirToDelete"
        }
        
        It "Should delete the files with the correct hashes." {
            Test-Path -Path "$script:mockDirectory/fileToDelete.txt" | Should -BeFalse
            Test-Path -Path "$script:mockDirectory/fileToDelete2.txt" | Should -BeFalse
        }

        It "Should not delete the file with the wrong hash." {
            Test-Path -Path "$script:mockDirectory/fileDontDelete.txt" | Should -BeTrue
        }

        It "Should not delete files further down than the 'Depth' parameter." {
            Test-Path -Path "$script:mockDirectory/dirDontDeleteDepth2/subDirDepth3/subDirDepth4/fileDontDeleteDepth5.txt" | Should -BeTrue
        }

        It "Should not delete files that matches any 'directoriesToExclude' entries." {
            Test-Path -Path "$script:mockDirectory/dirDontDelete/fileDontDelete.txt" | Should -BeTrue
        }

        It "Should delete empty directories" {
            Test-Path -Path "$script:mockDirectory/dirToDelete" | Should -BeFalse
        }
    }
}