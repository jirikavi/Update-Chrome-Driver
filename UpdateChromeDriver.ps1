Param(
	[Parameter(Position=0,Mandatory=$false,ValueFromPipeline=$True)][string]$chromeDriverDir= "C:\WebDriver\bin\"
)

$chromeDriverFileLocation = $(Join-Path $chromeDriverDir "chromedriver.exe")
$chromeVersion = [System.Diagnostics.FileVersionInfo]::GetVersionInfo("C:\Program Files (x86)\Google\Chrome\Application\chrome.exe").FileVersion
$chromeMajorVersion = $chromeVersion.split(".")[0]

if (-Not (Test-Path $chromeDriverDir -PathType Container)) {
  $dir = New-Item -ItemType directory -Path $chromeDriverDir
}

# set up `env:path` for the Chrome driver (only possible when running as Administrator)
if (-Not ($env:Path -split ";").Contains($chromeDriverDir)) {
  # check if admin otherwise throw
  $currentPrincipal = New-Object Security.Principal.WindowsPrincipal( [Security.Principal.WindowsIdentity]::GetCurrent() )
  if ( !($currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) )
  {
     throw "Error: You must run the script as administrator"
  }
  $env:Path = "$($env:Path);$($chromeDriverDir)"
  [System.Environment]::SetEnvironmentVariable('Path', $env:Path, 'Machine')
  Write-Output "Updated 'env:Path' for Chrome driver directory: $($chromeDriverDir)"
}

if (Test-Path $chromeDriverFileLocation -PathType Leaf) {
  # get version of current chromedriver.exe
  $chromeDriverFileVersion = (& $chromeDriverFileLocation --version)
  $chromeDriverFileVersionHasMatch = $chromeDriverFileVersion -match "ChromeDriver (\d+\.\d+\.\d+(\.\d+)?)"
  $chromeDriverCurrentVersion = $matches[1]

  if (-Not $chromeDriverFileVersionHasMatch) {
    Exit
  }
}
else {
  # if chromedriver.exe not found, will download it
  $chromeDriverCurrentVersion = ''
}

if ($chromeMajorVersion -lt 73) {
  # for chrome versions < 73 will use chromedriver v2.46 (which supports chrome v71-73)
  $chromeDriverExpectedVersion = "2.46"
  $chromeDriverVersionUrl = "https://chromedriver.storage.googleapis.com/LATEST_RELEASE"
}
else {
  $chromeDriverExpectedVersion = $chromeVersion.split(".")[0..2] -join "."
  $chromeDriverVersionUrl = "https://chromedriver.storage.googleapis.com/LATEST_RELEASE_" + $chromeDriverExpectedVersion
}

$chromeDriverLatestVersion = Invoke-RestMethod -Uri $chromeDriverVersionUrl

Write-Output "chrome version:       $chromeVersion"
Write-Output "chromedriver version: $chromeDriverCurrentVersion"
Write-Output "chromedriver latest:  $chromeDriverLatestVersion"

$needUpdateChromeDriver = $chromeDriverCurrentVersion -ne $chromeDriverLatestVersion
if ($needUpdateChromeDriver) {
  $chromeDriverZipLink = "https://chromedriver.storage.googleapis.com/" + $chromeDriverLatestVersion + "/chromedriver_win32.zip"
  Write-Output "Will download $chromeDriverZipLink"

  $chromeDriverZipFileLocation = $(Join-Path $chromeDriverDir "chromedriver_win32.zip")

  Invoke-WebRequest -Uri $chromeDriverZipLink -OutFile $chromeDriverZipFileLocation
  Expand-Archive $chromeDriverZipFileLocation -DestinationPath $chromeDriverDir -Force
  Remove-Item -Path $chromeDriverZipFileLocation -Force
  $chromeDriverFileVersion = (& $chromeDriverFileLocation --version)
  Write-Output "chromedriver updated to version $chromeDriverFileVersion"
}
else {
  Write-Output "chromedriver is actual"
}
