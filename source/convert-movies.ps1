param(
    [Parameter(Mandatory=$true)][string]$GameDir,
    [Parameter(Mandatory=$true)][string]$OutputDir,
    [Parameter(Mandatory=$true)][string[]]$Names,
    [Parameter(Mandatory=$true)][string]$FFmpegPath
)
$ErrorActionPreference='Stop'
$ffprobe=Join-Path (Split-Path -Parent $FFmpegPath) 'ffprobe.exe'

function Get-MovieInfo([string]$Path) {
    $json=& $ffprobe -v error -show_entries 'stream=codec_type,codec_name,width,height:format=format_name' -of json $Path
    if($LASTEXITCODE -ne 0){throw "FFprobe could not read $Path"}
    $info=($json -join "`n") | ConvertFrom-Json
    $video=@($info.streams | Where-Object codec_type -eq 'video')
    if($info.format.format_name -ne 'avi' -or $video.Count -ne 1 -or $video[0].width -lt 1 -or $video[0].height -lt 1){
        throw "Expected an AVI with one video stream: $Path"
    }
    $audio=@($info.streams | Where-Object codec_type -eq 'audio')
    return [pscustomobject]@{
        Width=$video[0].width
        Height=$video[0].height
        AudioCount=$audio.Count
        Compatible=($video[0].codec_name -eq 'msvideo1' -and
            @($audio | Where-Object codec_name -ne 'pcm_s16le').Count -eq 0)
    }
}

foreach($name in $Names){
    if($name -notmatch '^[a-z0-9]+\.avi$'){throw "Unexpected movie name: $name"}
    $relative=Join-Path 'Shell\Movies' $name
    $source=Join-Path $GameDir $relative
    if(!(Test-Path -LiteralPath $source -PathType Leaf)){throw "Missing installed game movie: $source"}
    $original=Get-MovieInfo $source
    if($original.Compatible){continue}

    $target=Join-Path $OutputDir $relative
    New-Item -ItemType Directory -Path (Split-Path -Parent $target) -Force | Out-Null
    Write-Host "Converting $name"
    & $FFmpegPath -nostdin -hide_banner -loglevel error -xerror -i $source -map '0:v:0' -map '0:a?' -c:v msvideo1 -q:v 2 -c:a pcm_s16le -y $target
    if($LASTEXITCODE -ne 0){throw "FFmpeg conversion failed: $name"}
    $converted=Get-MovieInfo $target
    if(!$converted.Compatible -or $original.AudioCount -ne $converted.AudioCount -or
        $original.Width -ne $converted.Width -or $original.Height -ne $converted.Height){
        throw "Unexpected converted movie format: $name"
    }
    Write-Output $relative
}
