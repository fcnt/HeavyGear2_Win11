param([string]$GameDir=$PSScriptRoot)
$ErrorActionPreference='Stop'
$logDir=Join-Path $env:LOCALAPPDATA 'Cyberfront\Heavy Gear 2'
try {New-Item -ItemType Directory -Path $logDir -Force | Out-Null}
catch {$logDir=$env:TEMP}
$logFile=Join-Path $logDir 'Launch-Win11.log'
function Write-LaunchLog([string]$message) {
    try {Add-Content -LiteralPath $logFile -Value ((Get-Date -Format o)+' '+$message) -Encoding UTF8} catch {}
}
try {
    $GameDir=(Resolve-Path -LiteralPath $GameDir).Path
    $exe=Join-Path $GameDir 'Heavy Gear 2 Win11.exe'
    $originalExe=Join-Path $GameDir 'Heavy Gear 2.exe'
    Write-LaunchLog ('Request: exe='+$exe+'; workingDirectory='+$GameDir)
    if(-not(Test-Path -LiteralPath $exe -PathType Leaf)){throw 'Heavy Gear 2 Win11.exe was not found.'}
    $game=Get-Process -Name 'Heavy Gear 2','Heavy Gear 2 Win11' -ErrorAction SilentlyContinue | Where-Object {
        try {$_.Path -in @($exe,$originalExe)} catch {$false}
    } | Select-Object -First 1
    if($game) {Write-LaunchLog ('Existing process: '+$game.Id)}
    else {
        if(Test-Path -LiteralPath (Join-Path $GameDir '_inmm.dll')){
            & (Join-Path $GameDir 'Initialize-Inmm.ps1') -GameDir $GameDir
        }
        $startInfo=New-Object System.Diagnostics.ProcessStartInfo
        $startInfo.FileName=$exe
        $startInfo.WorkingDirectory=$GameDir
        $startInfo.UseShellExecute=$false
        $startInfo.EnvironmentVariables['__COMPAT_LAYER']='RunAsInvoker'
        Write-LaunchLog 'Starting directly with compatibility layer RunAsInvoker'
        $game=[System.Diagnostics.Process]::Start($startInfo)
        Write-LaunchLog ('Started process: '+$game.Id)
    }
    $deadline=[DateTime]::UtcNow.AddSeconds(15)
    do {
        if($game.HasExited){throw ('ゲームは画面表示前に終了しました。終了コード: '+$game.ExitCode)}
        $game.Refresh()
        if($game.MainWindowHandle -ne [IntPtr]::Zero){break}
        Start-Sleep -Milliseconds 100
    } while([DateTime]::UtcNow -lt $deadline)
    if($game.MainWindowHandle -eq [IntPtr]::Zero){throw 'ゲームの画面を15秒以内に確認できませんでした。'}
    Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class HG2LaunchWindow {
    [DllImport("user32.dll")] public static extern bool ShowWindowAsync(IntPtr hwnd,int command);
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hwnd);
}
'@
    [void][HG2LaunchWindow]::ShowWindowAsync($game.MainWindowHandle,9)
    [void][HG2LaunchWindow]::SetForegroundWindow($game.MainWindowHandle)
    Start-Sleep -Seconds 2
    if($game.HasExited){throw ('ゲームは起動直後に終了しました。終了コード: '+$game.ExitCode)}
    $game.Refresh()
    Write-LaunchLog ('Ready: pid='+$game.Id+'; window='+$game.MainWindowHandle+'; responding='+$game.Responding)
    exit 0
} catch {
    $message=$_.Exception.Message
    Write-LaunchLog ('ERROR: '+$message)
    Add-Type -AssemblyName System.Windows.Forms
    [void][Windows.Forms.MessageBox]::Show(('ゲームを起動できませんでした。'+[Environment]::NewLine+$message+[Environment]::NewLine+[Environment]::NewLine+'起動記録: '+$logFile),'Heavy Gear 2 起動エラー')
    exit 1
}
