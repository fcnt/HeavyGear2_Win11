param(
    [Parameter(Mandatory=$true)][string]$Cue,
    [Parameter(Mandatory=$true)][string]$OutputDir
)
$ErrorActionPreference='Stop'
$cuePath=(Resolve-Path -LiteralPath $Cue).Path
$lines=Get-Content -LiteralPath $cuePath
$image=$null
$tracks=@()
foreach($line in $lines){
    if($line -match '^\s*FILE\s+"([^"]+)"\s+BINARY\s*$'){
        if($image -or [IO.Path]::GetFileName($Matches[1]) -ne $Matches[1]){
            throw 'Expected a single BINARY image beside the CUE.'
        }
        $image=Join-Path (Split-Path -Parent $cuePath) $Matches[1]
    } elseif($line -match '^\s*TRACK\s+(\d+)\s+(MODE1/2352|AUDIO)\s*$'){
        $track=@{ Number=[int]$Matches[1]; Type=$Matches[2]; Index0=$null; Index1=$null }
        $tracks+=$track
    } elseif($line -match '^\s*INDEX\s+(0[01])\s+(\d+):(\d{2}):(\d{2})\s*$'){
        if(!$tracks.Count -or [int]$Matches[3] -ge 60 -or [int]$Matches[4] -ge 75){
            throw 'Invalid CUE index.'
        }
        $track[('Index'+[int]$Matches[1])]=([long]$Matches[2]*60+[int]$Matches[3])*75+[int]$Matches[4]
    } elseif($line -match '^\s*(FILE|TRACK|INDEX)\b'){
        throw "Unsupported CUE entry: $line"
    }
}
if(!$image -or $tracks.Count -ne 19 -or $tracks[0].Type -ne 'MODE1/2352'){
    throw 'Expected the Japanese Heavy Gear II disc with 18 audio tracks.'
}
$inputFile=[IO.File]::OpenRead($image)
try {
    if($inputFile.Length % 2352){throw 'The disc image has a partial sector.'}
    $endSector=[long]($inputFile.Length/2352)
    $ranges=for($i=1;$i -lt $tracks.Count;$i++){
        $track=$tracks[$i]
        $next=if($i+1 -lt $tracks.Count){$tracks[$i+1]}
        $end=if(!$next){$endSector} elseif($null -ne $next.Index0){$next.Index0} else {$next.Index1}
        if($track.Number -ne $i+1 -or $track.Type -ne 'AUDIO' -or
            $null -eq $track.Index1 -or $track.Index1 -le $tracks[$i-1].Index1 -or
            $end -le $track.Index1 -or $end -gt $endSector){
            throw "Invalid sector range for track $($track.Number)."
        }
        [pscustomobject]@{Number=$track.Number; Offset=$track.Index1*2352; Bytes=[int](($end-$track.Index1)*2352)}
    }
    $destination=$ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($OutputDir)
    if(Test-Path -LiteralPath $destination){throw 'The output directory already exists.'}
    $stage=$destination+'.'+[guid]::NewGuid().ToString('N')
    New-Item -ItemType Directory -Path $stage | Out-Null
    $buffer=New-Object byte[] (1024*1024)
    $ascii=[Text.Encoding]::ASCII
    foreach($range in $ranges){
        $name='Track{0:00}.wav' -f $range.Number
        $path=Join-Path $stage $name
        $writer=[IO.BinaryWriter]::new([IO.File]::Open($path,[IO.FileMode]::CreateNew))
        try {
            $writer.Write($ascii.GetBytes('RIFF'))
            $writer.Write([uint32]($range.Bytes+36))
            $writer.Write($ascii.GetBytes('WAVEfmt '))
            $writer.Write([uint32]16)
            $writer.Write([uint16]1)
            $writer.Write([uint16]2)
            $writer.Write([uint32]44100)
            $writer.Write([uint32]176400)
            $writer.Write([uint16]4)
            $writer.Write([uint16]16)
            $writer.Write($ascii.GetBytes('data'))
            $writer.Write([uint32]$range.Bytes)
            $inputFile.Position=$range.Offset
            $remaining=$range.Bytes
            while($remaining -gt 0){
                $read=$inputFile.Read($buffer,0,[Math]::Min($remaining,$buffer.Length))
                if(!$read){throw "Unexpected end of image during $name."}
                $writer.Write($buffer,0,$read)
                $remaining-=$read
            }
        } finally {$writer.Dispose()}
    }
    [IO.Directory]::Move($stage,$destination)
    $ranges
} finally {$inputFile.Dispose()}
