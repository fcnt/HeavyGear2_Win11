param(
    [Parameter(Mandatory=$true)][string]$GameDir,
    [Parameter(Mandatory=$true)][string]$OutputDir
)
$ErrorActionPreference='Stop'
$encoding=[Text.Encoding]::GetEncoding(932)
$presetDir=Join-Path $GameDir 'Shell\bindings'
$files=@(Get-Item -LiteralPath (Join-Path $GameDir 'Bindings.def'))
$files+=@(Get-ChildItem -LiteralPath $presetDir -File | Where-Object Extension -in '.dff','.dft')

$names=@{
    'ESC'='Esc'; 'ESCAPE'='Esc'
    'Left Alt'='左 Alt'; 'Right Alt'='右 Alt'
    'Left Ctrl'='左 Ctrl'; 'Right Ctrl'='右 Ctrl'
    'Left Shift'='左 Shift'; 'Right Shift'='右 Shift'
    'Left Arrow'='左矢印'; 'Right Arrow'='右矢印'
    'Up Arrow'='上矢印'; 'Down Arrow'='下矢印'
}
$controlPattern='(?im)(?<prefix>^\s*BINDINGS\s+"(?<action>[^"\r\n]+)"[ \t]+CONTROL[ \t]+")(?<key>[^"\r\n]+)"'
foreach($file in $files){
    $original=[IO.File]::ReadAllText($file.FullName,$encoding)
    $updated=[regex]::Replace($original,$controlPattern,{
        param($match)
        $key=$match.Groups['key'].Value
        $action=$match.Groups['action'].Value
        if($action -eq 'Full Stop' -and $key -in '^','Joystick0 Button 5'){
            $key='Space'
        } elseif($names.ContainsKey($key)){
            $key=$names[$key]
        } else {
            $key=$key -replace '^Numpad ', 'テンキー ' -replace ' ﾎﾞﾀﾝ (?=\d+$)', ' ボタン '
        }
        return $match.Groups['prefix'].Value+$key+'"'
    })
    if($original -ceq $updated){continue}

    $relative=$file.FullName.Substring($GameDir.TrimEnd('\').Length+1)
    $target=Join-Path $OutputDir $relative
    New-Item -ItemType Directory -Path (Split-Path -Parent $target) -Force | Out-Null
    [IO.File]::WriteAllText($target,$updated,$encoding)
    Write-Output $relative
}
