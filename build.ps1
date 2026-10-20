<#
.SYNOPSIS
    Packs the bg3_levelunlocked mod (the src folder) into dist\bg3_levelunlocked.pak.

.DESCRIPTION
    Uses Divine.exe (LSLib) from the shared _tools folder of the modding base folder ($env:BG3_TOOLS overrides it):
      1. copies src into dist\stage;
      2. converts every Localization\<Language>\*.loca.xml (the text source) into the binary *.loca that the game
         reads, and every *.lsf.lsx (the readable source of a resource file, such as the texture bank _merged.lsf)
         into the binary *.lsf; the sources stay out of the package;
      3. packs dist\stage into the .pak and lists the package contents.
    With -Deploy (or -ModsDir), deploy.ps1 then copies the .pak into the game's Mods folder.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\build.ps1

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\build.ps1 -Deploy

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\build.ps1 -ModsDir "Z:\Mods"
#>
param(
    # Copy the package to the game's Mods folder after the build (see deploy.ps1 for the default folder).
    [switch]$Deploy,
    # Mods folder for the deployment; implies -Deploy.
    [string]$ModsDir
)

$ErrorActionPreference = "Stop"

$ModFolder = "bg3_levelunlocked"
$root = $PSScriptRoot
$source = Join-Path $root "src"
$dist = Join-Path $root "dist"
$pak = Join-Path $dist "$ModFolder.pak"

# The shared tools: $env:BG3_TOOLS, else the first _tools folder above the project.
function Find-Tools {
    if ($env:BG3_TOOLS) {
        return $env:BG3_TOOLS
    }
    $dir = Split-Path $root -Parent
    while ($dir) {
        $candidate = Join-Path $dir "_tools"
        if (Test-Path $candidate) {
            return $candidate
        }
        $dir = Split-Path $dir -Parent
    }
    throw "No _tools folder above $root. Put LSLib (https://github.com/Norbyte/lslib/releases) into a folder _tools\lslib above the project, or set BG3_TOOLS."
}

$divine = Join-Path (Find-Tools) "lslib\Packed\Tools\Divine.exe"
if (-not (Test-Path $divine)) {
    throw "$divine not found. Put LSLib (https://github.com/Norbyte/lslib/releases) into _tools\lslib, or set BG3_TOOLS."
}

New-Item -ItemType Directory -Force $dist | Out-Null
if (Test-Path $pak) {
    Remove-Item $pak
}

# 1. The stage. robocopy, because folder names such as [PAK]_UI are wildcard patterns for PowerShell paths.
$stage = Join-Path $dist "stage"
if (Test-Path -LiteralPath $stage) {
    Remove-Item -LiteralPath $stage -Recurse -Force
}
robocopy $source $stage /E /NFL /NDL /NJH /NJS /NP | Out-Null
# robocopy: exit codes below 8 mean success.
if ($LASTEXITCODE -ge 8) {
    throw "robocopy failed with exit code $LASTEXITCODE"
}

# 2. The texts: .loca.xml (source) -> .loca (what the game reads).
foreach ($xml in @(Get-ChildItem -LiteralPath $stage -Recurse -File -Filter "*.loca.xml")) {
    $loca = $xml.FullName.Substring(0, $xml.FullName.Length - ".xml".Length)
    & $divine --game bg3 --action convert-loca --source $xml.FullName --destination $loca --loglevel warn
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $loca)) {
        throw "Divine.exe convert-loca failed for $($xml.FullName) (exit code $LASTEXITCODE)"
    }
    Remove-Item -LiteralPath $xml.FullName
}
# Resource files: .lsf.lsx (source) -> .lsf (binary, as the game ships its own).
foreach ($lsx in @(Get-ChildItem -LiteralPath $stage -Recurse -File -Filter "*.lsf.lsx")) {
    $lsf = $lsx.FullName.Substring(0, $lsx.FullName.Length - ".lsx".Length)
    & $divine --game bg3 --action convert-resource --source $lsx.FullName --destination $lsf --loglevel warn
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $lsf)) {
        throw "Divine.exe convert-resource failed for $($lsx.FullName) (exit code $LASTEXITCODE)"
    }
    Remove-Item -LiteralPath $lsx.FullName
}

# 3. The package.
& $divine --game bg3 --action create-package --source $stage --destination $pak --compression-method lz4 --loglevel warn
if ($LASTEXITCODE -ne 0) {
    throw "Divine.exe create-package failed with exit code $LASTEXITCODE"
}
Remove-Item -LiteralPath $stage -Recurse -Force

Write-Host "Package contents:"
& $divine --game bg3 --action list-package --source $pak --loglevel warn
if ($LASTEXITCODE -ne 0) {
    throw "Divine.exe list-package failed with exit code $LASTEXITCODE"
}

Write-Host "Built $pak"

if ($Deploy -or $ModsDir) {
    $deployArgs = @{}
    if ($ModsDir) {
        $deployArgs.ModsDir = $ModsDir
    }
    & (Join-Path $root "deploy.ps1") @deployArgs
    exit $LASTEXITCODE
}
