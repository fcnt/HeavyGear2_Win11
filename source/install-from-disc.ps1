param(
    [Parameter(Mandatory=$true)][string]$GameDir,
    [Parameter(Mandatory=$true)][string]$DiscRoot,
    [Parameter(Mandatory=$true)][string]$CuePath,
    [Parameter(Mandatory=$true)][string]$FFmpegPath
)
$ErrorActionPreference='Stop'
$setup=Join-Path $DiscRoot 'Setup'
if((Get-FileHash -LiteralPath (Join-Path $setup 'data\Heavy Gear 2.exe')).Hash -ne 'C1690A6E471FBB0CAEA1A81BDF135875C7284243AF8AF1B9CB7FF535274E6F9F'){
    throw 'Use the Cyberfront Japanese edition game CD.'
}

$parent=Split-Path -Parent $GameDir
New-Item -ItemType Directory -Path $parent -Force | Out-Null
$parent=(Resolve-Path -LiteralPath $parent).ProviderPath
$stage=Join-Path $parent ('HG2-install-'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $stage | Out-Null
try {
    Write-Host 'Copying game data from the CD...'
    # DATA_J95 contains the bindings used by the original Japanese installation.
    foreach($tree in 'data','DATA_J95'){
        Get-ChildItem -LiteralPath (Join-Path $setup $tree) -Force |
            Copy-Item -Destination $stage -Recurse -Force
    }
    $movieDir=Join-Path $stage 'Shell\Movies'
    Get-ChildItem -LiteralPath (Join-Path $setup 'movies') -File -Filter '*.avi' |
        Copy-Item -Destination $movieDir
    foreach($name in 'default.ldl','language.ldl','string.ldl','string_e.ldl','STRING_J.LDL','loop.wav','setup.bmp','txt.ico'){
        Copy-Item -LiteralPath (Join-Path $setup $name) -Destination $stage
    }
    Copy-Item -LiteralPath (Join-Path $DiscRoot 'HELP') -Destination (Join-Path $stage 'help') -Recurse
    Copy-Item -LiteralPath (Join-Path $setup 'mprofile\options.cfg') -Destination (Join-Path $stage 'Shell\texts\options.cfg')
    New-Item -ItemType Directory -Path (Join-Path $stage 'SAVE') | Out-Null

    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $zip=[IO.Compression.ZipFile]::OpenRead((Join-Path $setup 'zip\zfs.zip'))
    try {
        foreach($name in 'alp.zfs','rim555.zfs','rim565.zfs'){
            $entry=$zip.GetEntry($name)
            if(!$entry){throw "Missing texture archive on the CD: $name"}
            [IO.Compression.ZipFileExtensions]::ExtractToFile($entry,(Join-Path $stage $name))
        }
    } finally {$zip.Dispose()}
    Get-ChildItem -LiteralPath $stage -File -Recurse -Force | Where-Object IsReadOnly |
        ForEach-Object {$_.IsReadOnly=$false}

    $installer=Join-Path (Split-Path -Parent $PSScriptRoot) 'Install-Win11.ps1'
    $result=Join-Path $stage 'Win11-patch-result.txt'
    $powershell=Join-Path $PSHOME 'powershell.exe'
    & $powershell -NoProfile -ExecutionPolicy Bypass -File $installer -GameDir $stage -DiscRoot $DiscRoot -CuePath $CuePath -FFmpegPath $FFmpegPath -ResultPath $result | Out-Host
    $patchExit=$LASTEXITCODE
    $report=Get-Content -LiteralPath $result -Raw -Encoding UTF8
    if($patchExit){throw $report}
    Remove-Item -LiteralPath $result
    [IO.Directory]::Move($stage,$GameDir)
    return ($report.Trim().Replace($stage,$GameDir)+[Environment]::NewLine+"Launch: "+(Join-Path $GameDir 'Launch-Win11.cmd'))
} finally {
    $stageFull=[IO.Path]::GetFullPath($stage)
    $prefix=$parent.TrimEnd('\')+'\'
    if($stageFull.StartsWith($prefix,[StringComparison]::OrdinalIgnoreCase) -and
        (Split-Path -Leaf $stageFull) -match '^HG2-install-[0-9a-f]{32}$' -and
        (Test-Path -LiteralPath $stageFull)){
        Remove-Item -LiteralPath $stageFull -Recurse -Force
    }
}
