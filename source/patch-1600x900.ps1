param([Parameter(Mandatory=$true)][string]$InputDll,
      [Parameter(Mandatory=$true)][string]$OutputDll)
$ErrorActionPreference='Stop'
if((Get-FileHash -LiteralPath $InputDll).Hash -ne 'C06D186B6D6FF032595FABEF13FA199EDB33F6A0D367FC245EF8B892F867A3A1'){
    throw 'Expected the inspected Japanese simulator with the text fix applied.'
}
$bytes=[IO.File]::ReadAllBytes((Resolve-Path -LiteralPath $InputDll).Path)

# Redirect the simulator mode lookup at RVA 0x2A2E0 into .text padding.
# For 1600x900 or 1600x1200 at 16bpp, set the height of mode 6
# before the renderer copies the table, then return 6. All other modes
# continue through the original lookup. CALL/POP gives a relocated base
# for the writable height field at RVA 0x15A8DC.
$stub=[byte[]](('81 7c 24 04 40 06 00 00 75 2d 83 7c 24 0c 10 75 26 8b 54 24 08 81 fa 84 03 00 00 74 08 81 fa b0 04 00 00 75 12 e8 00 00 00 00 58 89 90 b2 b9 01 00 b8 06 00 00 00 c3 55 8b ec 8b 55 10 e9 a4 b3 ee ff' -split ' ') | ForEach-Object {[Convert]::ToByte($_,16)})
$jump=[byte[]](0xe9,0x1b,0x4c,0x11,0x00,0x90)
[Array]::Copy($jump,0,$bytes,0x296e0,$jump.Length)
[Array]::Copy($stub,0,$bytes,0x13e300,$stub.Length)
[Array]::Copy([BitConverter]::GetBytes([uint32](0x13df00+$stub.Length)),0,$bytes,0x1d0,4)
[IO.File]::WriteAllBytes($OutputDll,$bytes)
