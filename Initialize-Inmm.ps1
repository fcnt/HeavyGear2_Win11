param(
    [Parameter(Mandatory=$true)][string]$GameDir,
    [string]$RegistryPath='HKCU:\Software\irori\_inmm.dll'
)
$ErrorActionPreference='Stop'
$player=Join-Path $GameDir '_inmmserv.exe'
$playerHash='FF593CC4891E5DD5FF10516BA1A36AAAB604050C19D011A24898ADD4E7F778EF'
if((Get-FileHash -LiteralPath $player).Hash -ne $playerHash){throw 'Unexpected _inmmserv.exe. Reapply the Win11 package.'}
$profile=Get-ItemProperty -LiteralPath $RegistryPath -ErrorAction SilentlyContinue
if($profile -and $null -ne $profile.Version -and $profile.Version -ne 568){
    throw 'The current Windows account has a different _inmm.dll version. Use a separate account or resolve that installation before starting Heavy Gear 2.'
}
if(!$profile){New-Item -Path $RegistryPath -Force | Out-Null}
foreach($setting in @{Version=568; ErrDispLevel=2; ErrLogLevel=3; Enabled=1; SE_Priority=1}.GetEnumerator()){
    if($null -eq $profile.($setting.Key)){
        New-ItemProperty -LiteralPath $RegistryPath -Name $setting.Key -Value $setting.Value -PropertyType DWord -Force | Out-Null
    }
}
if($null -eq $profile.LogName){
    New-ItemProperty -LiteralPath $RegistryPath -Name 'LogName' -Value '_inmm.log' -PropertyType String -Force | Out-Null
}
if(!$profile._inmmserv -or !(Test-Path -LiteralPath $profile._inmmserv -PathType Leaf)){
    New-ItemProperty -LiteralPath $RegistryPath -Name '_inmmserv' -Value $player -PropertyType String -Force | Out-Null
} elseif((Get-FileHash -LiteralPath $profile._inmmserv).Hash -ne $playerHash){
    throw 'The configured _inmm player differs from version 2.38.'
}
