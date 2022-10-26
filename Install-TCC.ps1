param
(
    # The folder where TCC will be installed to
    [Parameter(Position = 0, Mandatory = $false)]
    [string]$Destination,

    # If enabled, will prevent addition of TCC to your PATH environment variable
    [switch]$NoPath,

    # Skips all prompts and just installs, mainly intended for use if we need to re-run as admin.
    [switch]$SkipPrompts
);

$ErrorActionPreference = 'Stop';
$MAIN_DOWNLOAD = 'http://download.savannah.gnu.org/releases/tinycc/tcc-0.9.27-win64-bin.zip';
$HEADER_DOWNLOAD = 'http://download.savannah.gnu.org/releases/tinycc/winapi-full-for-0.9.27.zip';

Add-Type -Assembly 'System.IO.Compression.FileSystem';

if ([string]::IsNullOrEmpty($Destination)) { $Destination = (Join-Path $ENV:ProgramFiles 'TCC'); }
if ((Test-Path $Destination) -AND (-NOT $SkipPrompts))
{
    [string]$AlternatePath = Join-Path $Destination 'TCC';
    Write-Host "The directory $Destination already exists. Would you like to use $AlternatePath instead?";
    [string]$Answer = Read-Host -Prompt "Use alternate path? (y/n)";
    if ($Answer -EQ 'y') { $Destination = $AlternatePath; }
    Write-Host;
}

if (-NOT $SkipPrompts)
{
    Write-Host "TCC will be installed to $(Join-Path $Destination 'tcc.exe')";
    if ($NoPath) { Write-Host 'TCC will NOT be added to your path environment variable.'; }
    else { Write-Host 'TCC will be added to your path environment variable.'; }
    [string]$Answer = Read-Host -Prompt "Is this correct? (y/n)";
    if ($Answer -NE 'y') { Exit; }
}

try
{ # Check if we need elevation
    [bool]$IsAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] 'Administrator');
    if (-NOT $NoPath -AND (-NOT $IsAdmin)) { throw; } # If we want to set the system PATH variable, we need to elevate
    if (-NOT (Test-Path $Destination)) { New-Item -ItemType Directory -Path $Destination -ErrorAction SilentlyContinue -ErrorVariable PermissionError | Out-Null; }
    if ($PermissionError) { throw; }
    [string]$TestFile = Join-Path $Destination 'TestingFile.txt';
    Set-Content -Path $TestFile -Value 'Checking permissions.' -ErrorAction SilentlyContinue -ErrorVariable PermissionError;
    if ($PermissionError) { throw; }
    Remove-Item -Path $TestFile -ErrorAction SilentlyContinue -ErrorVariable PermissionError;
    if ($PermissionError) { throw; }
}
catch
{
    Write-Host 'Administrator permissions are required, requesting elevation...';
    if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] 'Administrator'))
    {
        if ([int](Get-CimInstance -Class Win32_OperatingSystem | Select-Object -ExpandProperty BuildNumber) -GE 6000)
        {
            $CommandLine = "-File `"$($MyInvocation.MyCommand.Path)`" -Destination `"$Destination`" -SkipPrompts";
            if ($NoPath) { $CommandLine += ' -NoPath'; }
            try { Start-Process -FilePath 'PowerShell.exe' -Verb RunAs -ArgumentList $CommandLine; }
            catch { Write-Error 'Failed to elevate to administrator.'; Exit; }
        }
    }
    else { Write-Error 'Could not access folder, but am already administrator!'; Exit; }
    if (-NOT $NoPath) { Write-Host 'You may need to restart your terminal before you can use TCC.'; }
    Exit;
}

# We should now have the required permissions.
# If we are not adding to PATH and the directory is writeable, we continue as non-admin.

if (-NOT (Test-Path $Destination)) { New-Item -ItemType Directory -Path $Destination | Out-Null; }

[string]$MainFile = Join-Path $Destination 'TCC_Main.zip';
[string]$HeadersFile = Join-Path $Destination 'TCC_Headers.zip';
[string]$TempFolder = Join-Path $Destination 'TCC_EXTRACT_TEMP';

Write-Host 'Downloading TCC...';
Invoke-WebRequest -Uri $MAIN_DOWNLOAD -UseBasicParsing -OutFile $MainFile;
Invoke-WebRequest -Uri $HEADER_DOWNLOAD -UseBasicParsing -OutFile $HeadersFile;

Write-Host 'Extracting archives...';
Expand-Archive $MainFile -DestinationPath $TempFolder;
Expand-Archive $HeadersFile -DestinationPath $TempFolder;

# It is assumed that each of the archives has a single top-level directory. If this ever changes, this will need to be updated:
$MainZip = [IO.Compression.ZipFile]::OpenRead($MainFile);
$MainDirName = ($MainZip.Entries | Where-Object { ($_.FullName.Split('/').Length -EQ 2) -AND ($_.FullName.EndsWith('/')) })[0].FullName;
$MainZip.Dispose();

$HeaderZip = [IO.Compression.ZipFile]::OpenRead($HeadersFile);
$HeaderDirName = ($HeaderZip.Entries | Where-Object { ($_.FullName.Split('/').Length -EQ 2) -AND ($_.FullName.EndsWith('/')) })[0].FullName;
$HeaderZip.Dispose();

Write-Host 'Merging folders...';
Get-ChildItem -Path "$(Join-Path $TempFolder $MainDirName)*" | Copy-Item -Destination $Destination -Recurse -Force;
Get-ChildItem -Path "$(Join-Path $TempFolder $HeaderDirName)*" | Copy-Item -Destination $Destination -Recurse -Force;

Write-Host 'Cleaning up...';
Remove-Item $MainFile;
Remove-Item $HeadersFile;
Remove-Item $TempFolder -Recurse;

if (-NOT $NoPath)
{
    $PathPath = 'Registry::HKEY_LOCAL_MACHINE\System\CurrentControlSet\Control\Session Manager\Environment';
    Write-Host 'Adding to system PATH environment variable...';
    $CurrentPATH = (Get-ItemProperty -Path $PathPath -Name 'PATH').Path;
    if ([string]::IsNullOrWhitespace($CurrentPATH)) { Write-Error 'Could not retrieve the system PATH'; Exit; }

    if ($CurrentPath.Contains($Destination.TrimEnd(('\', '/')))) # If the TCC install dir is on the path, regardless of trailing slash or not
    {
        Write-Host '  It looks like this TCC installation is already in your system PATH, so it will not be edited.';
    }
    else
    {
        $NewPATH = "$CurrentPATH;$Destination";
        Set-ItemProperty -Path $PathPath -Name 'PATH' -Value $NewPATH
        Write-Host '  You may need to restart your terminal before you can use TCC.';
    }
}

Write-Host 'Finished!';