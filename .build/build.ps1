# This file cannot be invoked directly; it simply contains a bunch of Invoke-Build tasks. To use it, invoke
# _init.ps1 which declares three global functions (build, clean, rebuild), then invoke one of those functions.

[CmdletBinding()]
param([string]$Configuration = 'Release')

use 14.0 MSBuild

# Useful paths used by  tasks.
$script:NodeJsDir = "$env:ProgramFiles\nodejs\"
$script:RepositoryRoot = "$PsScriptRoot\.." | Resolve-Path
$script:NuGetPath = "$PsScriptRoot\nuget.exe" | Resolve-Path
$script:DistDir = "$RepositoryRoot\dist"

# Helper function for clearer logging of each task.
function Write-Info {
    param ([string] $Message)
    
    Write-Host "## $Message ##" -ForegroundColor Magenta
}

task Init  {
    # Check that the nodejs folder exists and contains node.exe.
    if (-not (Test-Path $NodeJsDir)) {
        throw "Cannot locate nodejs folder at $NodeJsDir"
    }
    $NodeJsPath = "$NodeJsDir\node.exe"
    if (-not (Test-Path $NodeJsPath)) {
        throw "node.exe file not found at $NodeJsPath"
    }

    # Extract the package version number from node.exe
    $script:Version = (Get-Item $NodeJsPath).VersionInfo.ProductVersion
    if (-not $Version) {
        throw "Unable to retrieve the version number from $NodeJsPath"
    }
    Write-Info "Version = $Version"
}


# Clean task, deletes all build output folders.
task Clean  {
    Write-Info 'Cleaning build output'
    
    if (Test-Path $DistDir) {
        Remove-Item $DistDir -Force -Recurse
    }
}


# Bundles the nodejs files into a self-extracting archive.
task Compress  Init, {
    Write-Info 'Compressing nodejs files'

    $SevenZipPath = "$env:ProgramFiles\7-Zip\7z.exe"
    if (-not (Test-Path $SevenZipPath)) {
        throw "File not found: $SevenZipPath`r`nThis script requires the 64-bit version of 7-zip to be installed on this machine."
    }

    Start-Process -FilePath $SevenZipPath `
                  -ArgumentList @('a', '-bb3', '-r', '-sfx', "$DistDir\nodejs-sfx.exe", "*") `
                  -WorkingDirectory $NodeJsDir `
                  -NoNewWindow `
                  -Wait
}


task Package  Compress,  {
    Write-Info 'Generating NuGet package'

    # Temporarily insert the node version number in to the props file.
    $PropsFilePath = "$RepositoryRoot\RedGate.ThirdParty.NodeJs.props"
    $Encoding = New-Object 'System.Text.UTF8Encoding' $False
    $OriginalContents = [System.IO.File]::ReadAllText($PropsFilePath, $Encoding)
    $NewContents = $OriginalContents -replace '(?<=\<NodeJsVersion\>).*?(?=\</NodeJsVersion\>)', $Version.ToString()
    [System.IO.File]::WriteAllText($PropsFilePath, $NewContents, $Encoding)

    # Run NuGet pack.
    try {
        $NuSpecPath = "$RepositoryRoot\RedGate.ThirdParty.NodeJs.nuspec" | Resolve-Path
        $Parameters = @(
            'pack',
            "$NuSpecPath",
            '-Version', $Version,
            '-OutputDirectory', $DistDir
        )
        & $NuGetPath $Parameters
    }
    
    # Reinstate the original props file.
    finally {
        [System.IO.File]::WriteAllText($PropsFilePath, $OriginalContents, $Encoding)
    }
}


task Build  Package
task Default  Build