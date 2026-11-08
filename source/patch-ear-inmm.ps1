param(
    [Parameter(Mandatory=$true)][string]$InputDll,
    [Parameter(Mandatory=$true)][string]$OutputDll
)
$ErrorActionPreference='Stop'
if((Get-FileHash -LiteralPath $InputDll).Hash -ne '8CA3A33D709B9328927D129FC4ECFF3E4D216F37A4C3613B331D4A62AD190228'){
    throw 'Expected the inspected 32-bit EAR sound DLL.'
}
$bytes=[IO.File]::ReadAllBytes((Resolve-Path -LiteralPath $InputDll).Path)
$ascii=[Text.Encoding]::ASCII
[Array]::Copy($ascii.GetBytes('_inmm.dll'),0,$bytes,0x2cc54,9)
for($entry=0x2ca6c;[BitConverter]::ToUInt32($bytes,$entry);$entry+=4){
    $name=[BitConverter]::ToUInt32($bytes,$entry)+2
    $bytes[$name]=[byte][char]'_'
}
# Look up the game's local EAR settings using an absolute path.
# GetCurrentDirectoryA accepts the original two arguments in reverse order.
[Array]::Copy($ascii.GetBytes('GetCurrentDirectoryA'),0,$bytes,0x2ccf2,20)
$directoryArguments=[byte[]](0x8d,0x8d,0xe0,0xfe,0xff,0xff,0x51,0x68,0x04,0x01,0x00,0x00)
[Array]::Copy($directoryArguments,0,$bytes,0x596d,$directoryArguments.Length)
[Array]::Copy($ascii.GetBytes('\hg2cd.ear'+[char]0),0,$bytes,0x2f228,11)
[IO.File]::WriteAllBytes($OutputDll,$bytes)
