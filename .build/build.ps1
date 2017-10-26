# This file cannot be invoked directly; it simply contains a bunch of Invoke-Build tasks. To use it, invoke
# _init.ps1 which declares three global functions (build, clean, rebuild), then invoke one of those functions.

# NuGet package build number. Translates to the fourth digit in the NuGet package version,
# so that we can build multiple versions of this package that share the same version of nodejs.
# This assumes that the nodejs version will contain exactly three digits. When bumping the version number
# of nodejs, this should be reset to 0. When making a new release of this package, this value should be
# incremented.
$PackageBuildNumber = 0

# Useful paths used by  tasks.
$script:NodeJsDir = "$env:SystemDrive\Program Files\nodejs\"
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

    # Extract the node version number from node.exe
    $script:NodeVersion = (Get-Item $NodeJsPath).VersionInfo.ProductVersion
    if (-not $NodeVersion) {
        throw "Unable to retrieve the version number from $NodeJsPath"
    }
    Write-Info "Node version = $NodeVersion"

    # Establish the package version.
    $script:PackageVersion = "$NodeVersion.$PackageBuildNumber"
    Write-Info "Package version = $PackageVersion"
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

    $SevenZipPath = "$env:SystemDrive\Program Files\7-Zip\7z.exe"
    if (-not (Test-Path $SevenZipPath)) {
        throw "File not found: $SevenZipPath`r`nThis script requires the 64-bit version of 7-zip to be installed on this machine."
    }

    Start-Process -FilePath $SevenZipPath `
                  -ArgumentList @('a', '-bb3', '-r', '-sfx', "$DistDir\nodejs-sfx.exe", '*') `
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
    $NewContents = $OriginalContents -replace '(?<=\<NodeJsVersion\>).*?(?=\</NodeJsVersion\>)', $NodeVersion.ToString()
    [System.IO.File]::WriteAllText($PropsFilePath, $NewContents, $Encoding)

    # Run NuGet pack.
    try {
        $NuSpecPath = "$RepositoryRoot\RedGate.ThirdParty.NodeJs.nuspec" | Resolve-Path
        $Parameters = @(
            'pack',
            "$NuSpecPath",
            '-Version', $PackageVersion,
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
task Rebuild  Clean, Build
task Default  Build