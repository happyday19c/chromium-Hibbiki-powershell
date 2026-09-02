# Downloads a Chromium build and deploys the extracted Chrome-bin contents to bin.
# The script never terminates chrome.exe; it waits for the user to close it.
[CmdletBinding()]
param(
    [string]$DownloadUrl = 'https://github.com/Hibbiki/chromium-win64/releases/latest/download/chrome.7z',
    [string]$InstallRoot = 'C:\Program Files\Chromium',
    [string]$SevenZipPath = 'C:\Program Files\7-Zip\7z.exe',
    [string]$LatestReleaseApiUrl = 'https://api.github.com/repos/Hibbiki/chromium-win64/releases/latest'
)

$ErrorActionPreference = 'Stop'

function Wait-ForChromeToExit {
    while (Get-Process -Name 'chrome' -ErrorAction SilentlyContinue) {
        Write-Warning 'chrome.exe is currently running. Close every Chromium/Chrome window before continuing.'
        Read-Host 'After chrome.exe has exited, press Enter to check again'
    }
}

function Get-InstalledChromiumVersion {
    param([string]$ChromePath)

    if (-not (Test-Path -LiteralPath $ChromePath -PathType Leaf)) {
        return 'Not installed'
    }

    $Version = (Get-Item -LiteralPath $ChromePath).VersionInfo.ProductVersion
    if ([string]::IsNullOrWhiteSpace($Version)) {
        return 'Unknown'
    }
    return $Version
}

function Get-LatestChromiumRelease {
    param([string]$ReleaseApiUrl)

    $Release = Invoke-RestMethod -Uri $ReleaseApiUrl
    if ([string]::IsNullOrWhiteSpace($Release.tag_name)) {
        throw "The latest release response did not contain a tag_name."
    }
    return $Release.tag_name
}

if (-not (Test-Path -LiteralPath $SevenZipPath -PathType Leaf)) {
    throw "7-Zip was not found at '$SevenZipPath'. Install 7-Zip or provide its executable path with -SevenZipPath."
}

$BinPath = Join-Path $InstallRoot 'bin'
$TemporaryDirectory = Join-Path ([System.IO.Path]::GetTempPath()) ("ChromiumUpdate-{0}" -f [guid]::NewGuid())
$ArchivePath = Join-Path $TemporaryDirectory 'chrome.7z'
$ExtractionPath = Join-Path $TemporaryDirectory 'extracted'
$ChromePath = Join-Path $BinPath 'chrome.exe'

try {
    $InstalledVersion = Get-InstalledChromiumVersion -ChromePath $ChromePath
    $LatestVersion = Get-LatestChromiumRelease -ReleaseApiUrl $LatestReleaseApiUrl
    Write-Host "Installed Chromium version: $InstalledVersion"
    Write-Host "Latest Chromium version:    $LatestVersion"

    New-Item -ItemType Directory -Path $TemporaryDirectory | Out-Null
    New-Item -ItemType Directory -Path $ExtractionPath | Out-Null

    Write-Host "Downloading Chromium from $DownloadUrl"
    Invoke-WebRequest -Uri $DownloadUrl -OutFile $ArchivePath

    Write-Host 'Extracting archive to a temporary directory'
    & $SevenZipPath x "-o$ExtractionPath" -y $ArchivePath
    if ($LASTEXITCODE -ne 0) {
        throw "7-Zip extraction failed with exit code $LASTEXITCODE."
    }

    $ChromeBinDirectory = Get-ChildItem -LiteralPath $ExtractionPath -Directory -Recurse |
        Where-Object { $_.Name -eq 'Chrome-bin' } |
        Select-Object -First 1
    if ($null -eq $ChromeBinDirectory) {
        throw "The archive did not contain a Chrome-bin directory."
    }

    Wait-ForChromeToExit

    New-Item -ItemType Directory -Path $BinPath -Force | Out-Null
    Write-Host "Copying Chromium files to $BinPath"
    Get-ChildItem -LiteralPath $ChromeBinDirectory.FullName -Force |
        Copy-Item -Destination $BinPath -Recurse -Force

    Write-Host 'Chromium update completed successfully.'
}
finally {
    if (Test-Path -LiteralPath $TemporaryDirectory) {
        Remove-Item -LiteralPath $TemporaryDirectory -Recurse -Force
    }
}
