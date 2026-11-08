param(
    [Parameter(Mandatory=$true)][string]$GameDir,
    [Parameter(Mandatory=$true)][string]$OutputDir
)
$ErrorActionPreference='Stop'
$shell=Join-Path $GameDir 'shell.dll'
$sim=Join-Path $GameDir 'hg2sim.dll'
$newShell=Join-Path $OutputDir 'shell.dll'
$newSim=Join-Path $OutputDir 'hg2sim.dll'
$shellTarget='AF62F50759EE776F8E99DECCBD8FA313194465E0A27AF3802BD9E85FFC5428C9'
$simTarget='2BFF81CFE4ED64347E251DFB7CB968CDCB733B329915B9887BA39AF6A02876A3'
$shellHash=(Get-FileHash -LiteralPath $shell).Hash
$simHash=(Get-FileHash -LiteralPath $sim).Hash
$simVersions=@(
    'F482BB9E2809168687B24E4651CD56FC5180DA38B39C669F9DBCA31312256D71',
    'C06D186B6D6FF032595FABEF13FA199EDB33F6A0D367FC245EF8B892F867A3A1',
    'CD8461852F53E3CB7882E2F9B1651CBDC6CB1DC216EE7D60E7AE4EAD1E4544E1',
    'E7A2EF1AE1B04259C1592860AF179A15A634EC6441CE31CD9CCEE2A41F49119F',
    $simTarget
)
if($shellHash -notin @('EB657B47EC55B6A7F315674C432C204B1F6AFB22B0A8F7F1D5938ECC6DB5441C',
    'F8B491B4D9AA0539B4DFAAAF8767E05A674A11F0DE5A0C6035A9E74B917D6B2C',$shellTarget)){
    throw 'Unsupported shell.dll. Use the supported Cyberfront Japanese edition.'
}
if($simHash -notin $simVersions){throw 'Unsupported hg2sim.dll. Use the supported Cyberfront Japanese edition.'}

$colorPatch=Join-Path $PSScriptRoot 'patch-16bit-only.ps1'
if($shellHash -eq $shellTarget){
    [IO.File]::Copy($shell,$newShell)
} else {
    $bytes=[IO.File]::ReadAllBytes($shell)
    foreach($offset in 0x59f03,0x5ac02){$bytes[$offset]=0xeb}
    [IO.File]::WriteAllBytes($newShell,$bytes)
    & $colorPatch -Component Shell -InputDll $newShell -OutputDll $newShell
}
if($simHash -eq $simVersions[0]){
    $bytes=[IO.File]::ReadAllBytes($sim)
    $import=[Text.Encoding]::ASCII.GetBytes('HG2JP.dll'+[char]0)
    [Array]::Copy($import,0,$bytes,1403076,$import.Length)
    [IO.File]::WriteAllBytes($newSim,$bytes)
} else {
    [IO.File]::Copy($sim,$newSim)
}
if($simHash -in $simVersions[0..1]){
    & (Join-Path $PSScriptRoot 'patch-1600x900.ps1') -InputDll $newSim -OutputDll $newSim
}
if($simHash -ne $simTarget){
    & $colorPatch -Component Simulator -InputDll $newSim -OutputDll $newSim
}
if((Get-FileHash -LiteralPath $newShell).Hash -ne $shellTarget -or
    (Get-FileHash -LiteralPath $newSim).Hash -ne $simTarget){
    throw 'Unexpected output from the game patches.'
}
