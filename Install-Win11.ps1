param(
    [string]$GameDir,
    [string]$CuePath,
    [string]$DiscRoot,
    [string]$FFmpegPath,
    [switch]$Interactive,
    [string]$ResultPath
)
$ErrorActionPreference='Stop'

function Install-GamePatch {
    $exeHash='C1690A6E471FBB0CAEA1A81BDF135875C7284243AF8AF1B9CB7FF535274E6F9F'
    $default=Join-Path ${env:ProgramFiles(x86)} 'Cyberfront\Heavy Gear 2'
    if(!$GameDir){
        $defaultExe=Join-Path $default 'Heavy Gear 2.exe'
        if((Test-Path -LiteralPath $defaultExe -PathType Leaf) -and (Get-FileHash -LiteralPath $defaultExe).Hash -eq $exeHash){
            $GameDir=$default
            Write-Host "Found Heavy Gear 2: $GameDir"
        }
    }
    if($Interactive){Add-Type -AssemblyName System.Windows.Forms}
    if(!$GameDir -and $Interactive){
        $selector=[Windows.Forms.FolderBrowserDialog]::new()
        try {
            $selector.Description='Heavy Gear 2.exe が入っているゲームフォルダを選んでください。'
            $selector.ShowNewFolderButton=$false
            if(Test-Path -LiteralPath $default){$selector.SelectedPath=$default}
            if($selector.ShowDialog() -ne 'OK'){return 'Installation cancelled.'}
            $GameDir=$selector.SelectedPath
        } finally {$selector.Dispose()}
    }
    if(!$GameDir){throw 'Specify the installed game folder with -GameDir.'}
    $GameDir=(Resolve-Path -LiteralPath $GameDir).ProviderPath
    $exe=Join-Path $GameDir 'Heavy Gear 2.exe'
    $win11Exe=Join-Path $GameDir 'Heavy Gear 2 Win11.exe'
    if((Get-FileHash -LiteralPath $exe).Hash -ne $exeHash){throw 'Unsupported Heavy Gear 2.exe. Use the supported Cyberfront Japanese edition.'}
    if((Test-Path -LiteralPath $win11Exe) -and (Get-FileHash -LiteralPath $win11Exe).Hash -ne $exeHash){
        throw 'The existing Heavy Gear 2 Win11.exe is different.'
    }
    if(Get-Process -Name 'Heavy Gear 2','Heavy Gear 2 Win11' -ErrorAction SilentlyContinue){
        throw 'Close Heavy Gear 2 before installing.'
    }
    $mixer=Join-Path $GameDir 'earmusf.exe'
    if((Test-Path -LiteralPath $mixer) -and (Get-FileHash -LiteralPath $mixer).Hash -ne '1A81F7408D6D803A57EB94AC20C14529978B5D6520BC0947DB9F01DE1A41423A'){
        throw 'Unexpected startup mixer helper.'
    }
    if(!$DiscRoot){
        $DiscRoot=[IO.DriveInfo]::GetDrives() | Where-Object {
            $_.DriveType -eq 'CDRom' -and $_.IsReady -and
                (Test-Path -LiteralPath (Join-Path $_.RootDirectory.FullName 'Setup\iasinst.exe')) -and
                ((Get-FileHash -LiteralPath (Join-Path $_.RootDirectory.FullName 'Setup\iasinst.exe')).Hash -eq '2D721D5DA4122F43DC2302F899CA7A9CEAF5692EA2686053E8A9F2C09038DBFC')
        } | Select-Object -First 1 -ExpandProperty Name
    }
    if(!$DiscRoot){throw 'Mount HG2JP.CUE before running the installer.'}
    $audio=Join-Path $GameDir 'CDDA'
    $tracks=2..19 | ForEach-Object {'Track{0:00}' -f $_}
    function Get-MissingAudioTracks([string]$extension) {
        $tracks | Where-Object {!(Test-Path -LiteralPath (Join-Path $audio "$_.$extension") -PathType Leaf)}
    }
    if(!$CuePath -and (Get-MissingAudioTracks 'mp3') -and (Get-MissingAudioTracks 'wav')){
        $CuePath=@($GameDir,$PSScriptRoot) | ForEach-Object {
            Join-Path $_ 'HG2JP.CUE'
        } | Where-Object {Test-Path -LiteralPath $_ -PathType Leaf} | Select-Object -First 1
        if(!$CuePath -and $Interactive){
            $selector=[Windows.Forms.OpenFileDialog]::new()
            try {
                $selector.Title='HG2JP.CUE を選んでください。IMG と同じフォルダに置きます。'
                $selector.Filter='CUE disc image (*.cue)|*.cue'
                if($selector.ShowDialog() -ne 'OK'){return 'Installation cancelled.'}
                $CuePath=$selector.FileName
            } finally {$selector.Dispose()}
        }
        if(!$CuePath){throw 'Put HG2JP.CUE beside the game or installer, or specify -CuePath.'}
    }
    if($CuePath){$CuePath=(Resolve-Path -LiteralPath $CuePath).ProviderPath}

    if(!$FFmpegPath){
        $ffmpeg=Get-Command ffmpeg.exe -CommandType Application -All -ErrorAction SilentlyContinue | Where-Object {
            Test-Path -LiteralPath (Join-Path (Split-Path -Parent $_.Source) 'ffprobe.exe') -PathType Leaf
        } | Select-Object -First 1
        if($ffmpeg){$FFmpegPath=$ffmpeg.Source}
    }
    if(!$FFmpegPath){$FFmpegPath=& (Join-Path $PSScriptRoot 'source\get-ffmpeg.ps1')}
    $FFmpegPath=(Resolve-Path -LiteralPath $FFmpegPath).ProviderPath
    if((Split-Path -Leaf $FFmpegPath) -ne 'ffmpeg.exe' -or
        !(Test-Path -LiteralPath $FFmpegPath -PathType Leaf) -or
        !(Test-Path -LiteralPath (Join-Path (Split-Path -Parent $FFmpegPath) 'ffprobe.exe') -PathType Leaf)){
        throw 'Use a Windows FFmpeg build containing ffmpeg.exe and ffprobe.exe in the same folder.'
    }

    $lock=$null
    try {
        $lock=[IO.FileStream]::new((Join-Path $GameDir 'Win11-install.lock'),[IO.FileMode]::OpenOrCreate,
            [IO.FileAccess]::ReadWrite,[IO.FileShare]::None,4096,[IO.FileOptions]::DeleteOnClose)
    } catch [UnauthorizedAccessException] {
        if(!$Interactive -or $ResultPath){throw}
        $result=Join-Path ([IO.Path]::GetTempPath()) ('HG2-install-'+[guid]::NewGuid().ToString('N')+'.txt')
        try {
            $quoted=@($PSCommandPath,$GameDir,$CuePath,$DiscRoot,$result,$FFmpegPath) | ForEach-Object {"'"+("$($_)".Replace("'","''"))+"'"}
            $command='& {0} -GameDir {1} -CuePath {2} -DiscRoot {3} -ResultPath {4} -FFmpegPath {5}' -f $quoted
            $encoded=[Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($command))
            $start=@{FilePath=(Join-Path $PSHOME 'powershell.exe'); Verb='RunAs'; WindowStyle='Hidden';
                ArgumentList="-NoProfile -ExecutionPolicy Bypass -EncodedCommand $encoded"; PassThru=$true; Wait=$true}
            $worker=Start-Process @start
            $report=Get-Content -LiteralPath $result -Raw -Encoding UTF8
            if($worker.ExitCode){throw $report}
            return $report.Trim()
        } finally {
            if(Test-Path -LiteralPath $result){Remove-Item -LiteralPath $result}
        }
    }

    $stage=Join-Path $GameDir ('Win11-stage-'+[guid]::NewGuid().ToString('N'))
    $backup=$null
    $changes=[Collections.Generic.List[object]]::new()
    $audioAdded=$false
    $mixerMoved=$false
    try {
        New-Item -ItemType Directory -Path $stage | Out-Null
        $payload=Join-Path $PSScriptRoot 'payload'
        $source=Join-Path $PSScriptRoot 'source'
        $files=[ordered]@{}
        & (Join-Path $source 'patch-game.ps1') -GameDir $GameDir -OutputDir $stage
        & (Join-Path $source 'extract-ear.ps1') -DiscRoot $DiscRoot -OutputDll (Join-Path $stage 'earpds.dll')
        foreach($name in 'shell.dll','hg2sim.dll','earpds.dll'){$files[$name]=Join-Path $stage $name}
        $files['Heavy Gear 2 Win11.exe']=$exe
        foreach($name in 'Launch-Win11.cmd','Launch-Win11.ps1','Initialize-Inmm.ps1'){
            $files[$name]=Join-Path $PSScriptRoot $name
        }
        $inmm=Join-Path $PSScriptRoot 'vendor\_inmm238.zip'
        if((Get-FileHash -LiteralPath $inmm).Hash -ne 'D6FAE62F81F2A189BA1774EB2CE14C9A1C1215F104EC9A955870076CE002AA5A'){
            throw 'Package checksum mismatch: _inmm238.zip'
        }
        $inmmStage=Join-Path $stage 'inmm'
        Expand-Archive -LiteralPath $inmm -DestinationPath $inmmStage
        foreach($name in '_inmm.dll','_inmmserv.exe'){$files[$name]=Join-Path $inmmStage $name}
        foreach($entry in (Get-Content -LiteralPath (Join-Path $PSScriptRoot 'payload-sha256.json') -Raw | ConvertFrom-Json)){
            $file=Join-Path $payload $entry.Path
            if((Get-FileHash -LiteralPath $file).Hash -ne $entry.SHA256){throw "Package checksum mismatch: $($entry.Path)"}
            $relative=Split-Path -Leaf $entry.Path
            if($relative -eq 'hg2cd.ear' -and (Test-Path -LiteralPath (Join-Path $GameDir $relative))){continue}
            $files[$relative]=$file
        }
        $audioStage=Join-Path $stage 'CDDA'
        $newAudio=!(Test-Path -LiteralPath $audio -PathType Container)
        $archiveWav=$false
        $missingMp3=@(Get-MissingAudioTracks 'mp3')
        if($missingMp3.Count){
            $wavSource=$audio
            $archiveWav=!(Get-MissingAudioTracks 'wav')
            if(!$archiveWav){
                $wavSource=Join-Path $stage 'CDDA-wav'
                & (Join-Path $source 'extract-cdda.ps1') -Cue $CuePath -OutputDir $wavSource | Out-Null
            }
            New-Item -ItemType Directory -Path $audioStage | Out-Null
            foreach($track in $missingMp3){
                $wav=Join-Path $wavSource "$track.wav"
                $name="$track.mp3"
                $mp3=Join-Path $audioStage $name
                Write-Host "Encoding $name (128 kbps)"
                & $FFmpegPath -nostdin -hide_banner -loglevel error -xerror -i $wav -map '0:a:0' -map_metadata -1 -c:a libmp3lame -b:a 128k -y $mp3
                if($LASTEXITCODE -ne 0){throw "FFmpeg MP3 encoding failed: $name"}
                if(!$newAudio){$files[(Join-Path 'CDDA' $name)]=$mp3}
            }
        }
        $stagedFiles=[ordered]@{}
        $overlay=Join-Path $stage 'overlay'
        $movies=Get-Content -LiteralPath (Join-Path $PSScriptRoot 'movies.json') -Raw | ConvertFrom-Json
        foreach($relative in (& (Join-Path $source 'convert-movies.ps1') -GameDir $GameDir -OutputDir $overlay -Names $movies -FFmpegPath $FFmpegPath)){
            $stagedFiles[$relative]=Join-Path $overlay $relative
        }
        foreach($relative in (& (Join-Path $source 'patch-bindings.ps1') -GameDir $GameDir -OutputDir $overlay)){
            $stagedFiles[$relative]=Join-Path $overlay $relative
        }
        foreach($entry in $files.GetEnumerator()){
            $target=Join-Path $GameDir $entry.Key
            if(!(Test-Path -LiteralPath (Split-Path -Parent $target) -PathType Container)){
                throw "Incomplete game installation: $target"
            }
            if((Test-Path -LiteralPath $target) -and
                ((Get-FileHash -LiteralPath $target).Hash -eq (Get-FileHash -LiteralPath $entry.Value).Hash)){continue}
            $staged=Join-Path $overlay $entry.Key
            New-Item -ItemType Directory -Path (Split-Path -Parent $staged) -Force | Out-Null
            [IO.File]::Copy($entry.Value,$staged)
            $stagedFiles[$entry.Key]=$staged
        }
        if(!$stagedFiles.Count -and !$newAudio -and !$archiveWav -and !(Test-Path -LiteralPath $mixer)){
            return 'The Win11 package is already applied.'
        }
        $backup=Join-Path $GameDir ('Win11-transfer-backup-'+(Get-Date -Format 'yyyyMMdd-HHmmss')+'-'+[guid]::NewGuid().ToString('N').Substring(0,8))
        $originals=Join-Path $backup 'Original'
        New-Item -ItemType Directory -Path $originals | Out-Null
        if($newAudio){[IO.Directory]::Move($audioStage,$audio); $audioAdded=$true}
        foreach($entry in $stagedFiles.GetEnumerator()){
            $target=Join-Path $GameDir $entry.Key
            $saved=$null
            if(Test-Path -LiteralPath $target -PathType Leaf){
                $saved=Join-Path $originals $entry.Key
                New-Item -ItemType Directory -Path (Split-Path -Parent $saved) -Force | Out-Null
                [IO.File]::Replace($entry.Value,$target,$saved)
            } else {
                [IO.File]::Move($entry.Value,$target)
            }
            $changes.Add(@{Relative=$entry.Key; Target=$target; Saved=$saved})
        }
        if($archiveWav){
            $savedAudio=Join-Path $originals 'CDDA'
            New-Item -ItemType Directory -Path $savedAudio -Force | Out-Null
            foreach($track in $tracks){
                $wav=Join-Path $audio "$track.wav"
                $saved=Join-Path $savedAudio "$track.wav"
                [IO.File]::Move($wav,$saved)
                $changes.Add(@{Target=$wav; Saved=$saved})
            }
        }
        if(Test-Path -LiteralPath $mixer){
            [IO.File]::Move($mixer,(Join-Path $originals 'earmusf.exe'))
            $mixerMoved=$true
        }
        $added=@($changes | Where-Object {!$_.Saved} | ForEach-Object {$_.Relative})
        if($audioAdded){$added+='CDDA'}
        [IO.File]::WriteAllLines((Join-Path $backup 'Added.txt'),[string[]]$added)
        return "Installed successfully. Backup: $backup"
    } catch {
        $failure=$_
        foreach($item in $changes){
            if($item.Saved){[IO.File]::Copy($item.Saved,$item.Target,$true)}
            else {Remove-Item -LiteralPath $item.Target}
        }
        if($mixerMoved){[IO.File]::Move((Join-Path $originals 'earmusf.exe'),$mixer)}
        if($audioAdded){[IO.Directory]::Move($audio,$audioStage)}
        throw $failure
    } finally {
        $prefix=$GameDir.TrimEnd('\')+'\'
        $stageFull=[IO.Path]::GetFullPath($stage)
        if($stageFull.StartsWith($prefix,[StringComparison]::OrdinalIgnoreCase) -and
            (Split-Path -Leaf $stageFull) -match '^Win11-stage-[0-9a-f]{32}$' -and
            (Test-Path -LiteralPath $stageFull)){
            try {Remove-Item -LiteralPath $stageFull -Recurse -Force}
            finally {$lock.Dispose()}
        } else {
            $lock.Dispose()
        }
    }
}

try {
    $message=Install-GamePatch
    if($ResultPath){[IO.File]::WriteAllText($ResultPath,$message)}
    else {Write-Host $message}
} catch {
    if($ResultPath){[IO.File]::WriteAllText($ResultPath,$_.Exception.Message)}
    else {Write-Host $_.Exception.Message -ForegroundColor Red}
    exit 1
}
