$ErrorActionPreference='Stop'
$version='9.0.2'
$build="ffmpeg-$version-essentials_build"
$archiveHash='60F467265B1E312373DBCD92200C2618A74850F98D3D078E94296BB3FA2047BA'
$hashes=[ordered]@{
    'ffmpeg.exe'='3256173F3F8BFFD7DF12227C68ADF68025EDB1832273A9530688A7BB1ED8EDEC'
    'ffprobe.exe'='F0D36ECBBDD3BCFAC3EFA078C96C7271C2E68B3810595552AC3B7F17E9A65C52'
}
$cache=Join-Path $env:LOCALAPPDATA "Cyberfront\Heavy Gear 2\Tools\$build"
New-Item -ItemType Directory -Path $cache -Force | Out-Null
$lock=[IO.FileStream]::new((Join-Path $cache 'download.lock'),[IO.FileMode]::OpenOrCreate,
    [IO.FileAccess]::ReadWrite,[IO.FileShare]::None,4096,[IO.FileOptions]::DeleteOnClose)
$download=$null
try {
    $invalid=@($hashes.Keys | Where-Object {
        $path=Join-Path $cache $_
        !(Test-Path -LiteralPath $path -PathType Leaf) -or (Get-FileHash -LiteralPath $path).Hash -ne $hashes[$_]
    })
    if($invalid.Count){
        Write-Host "Downloading FFmpeg $version Essentials (about 110 MiB)..."
        $download=(New-TemporaryFile).FullName
        $ProgressPreference='SilentlyContinue'
        $urls=@(
            "https://github.com/GyanD/codexffmpeg/releases/download/$version/$build.zip"
            "https://www.gyan.dev/ffmpeg/builds/packages/$build.zip"
        )
        $downloaded=$false
        foreach($url in $urls){
            try {
                Invoke-WebRequest -UseBasicParsing -TimeoutSec 300 -OutFile $download -Uri $url
                $downloaded=$true
                break
            } catch {$downloadError=$_.Exception.Message}
        }
        if(!$downloaded){
            throw "Could not download FFmpeg. Check your Internet connection and retry. $downloadError"
        }
        if((Get-FileHash -LiteralPath $download).Hash -ne $archiveHash){
            throw 'The downloaded FFmpeg archive failed its SHA-256 check.'
        }

        Add-Type -AssemblyName System.IO.Compression.FileSystem
        $zip=[IO.Compression.ZipFile]::OpenRead($download)
        try {
            foreach($name in $hashes.Keys){
                $entry=$zip.GetEntry("$build/bin/$name")
                if(!$entry){throw "Missing file in the verified FFmpeg archive: $name"}
                $path=Join-Path $cache $name
                [IO.Compression.ZipFileExtensions]::ExtractToFile($entry,$path,$true)
                if((Get-FileHash -LiteralPath $path).Hash -ne $hashes[$name]){
                    throw "FFmpeg binary failed its SHA-256 check: $name"
                }
            }
        } finally {$zip.Dispose()}
    }
    Join-Path $cache 'ffmpeg.exe'
} finally {
    try {if($download){Remove-Item -LiteralPath $download -Force}}
    finally {$lock.Dispose()}
}
