param(
    [Parameter(Mandatory=$true)][string]$DiscRoot,
    [Parameter(Mandatory=$true)][string]$OutputDll
)
$ErrorActionPreference='Stop'
$inputFile=Join-Path $DiscRoot 'Setup\iasinst.exe'
if((Get-FileHash -LiteralPath $inputFile).Hash -ne '2D721D5DA4122F43DC2302F899CA7A9CEAF5692EA2686053E8A9F2C09038DBFC'){
    throw 'Use the mounted Cyberfront Japanese game disc (HG2JP).'
}
$container=[IO.File]::ReadAllBytes($inputFile)
$driver=New-Object byte[] 233472
[Array]::Copy($container,547600,$driver,0,$driver.Length)
$original=$OutputDll+'.original'
try {
    [IO.File]::WriteAllBytes($original,$driver)
    & (Join-Path $PSScriptRoot 'patch-ear-inmm.ps1') -InputDll $original -OutputDll $OutputDll
} finally {
    if(Test-Path -LiteralPath $original){Remove-Item -LiteralPath $original}
}
if((Get-FileHash -LiteralPath $OutputDll).Hash -ne '265E43304E4194489F10340227DDB5B4137D87D13E4191C1405ED08A1EC665BC'){
    throw 'Unexpected output from the EAR sound patch.'
}
