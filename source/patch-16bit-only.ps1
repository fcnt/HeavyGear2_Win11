param(
    [Parameter(Mandatory=$true)][ValidateSet('Shell','Simulator')][string]$Component,
    [Parameter(Mandatory=$true)][string]$InputDll,
    [Parameter(Mandatory=$true)][string]$OutputDll
)
$ErrorActionPreference='Stop'
$experimentalSimulator='E7A2EF1AE1B04259C1592860AF179A15A634EC6441CE31CD9CCEE2A41F49119F'
$expected=@{
    Shell=@('F8B491B4D9AA0539B4DFAAAF8767E05A674A11F0DE5A0C6035A9E74B917D6B2C')
    Simulator=@('CD8461852F53E3CB7882E2F9B1651CBDC6CB1DC216EE7D60E7AE4EAD1E4544E1',$experimentalSimulator)
}
$inputHash=(Get-FileHash -LiteralPath $InputDll).Hash
if($inputHash -notin $expected[$Component]){
    throw "Unexpected input DLL for the 16-bit $Component patch."
}
$bytes=[IO.File]::ReadAllBytes((Resolve-Path -LiteralPath $InputDll).Path)
if($Component -eq 'Shell'){
    # The graphics dropdown loops over display modes. Skip the current
    # entry unless its bit depth (the local at EBP-0x24) is 16.
    $hook=[byte[]](0xe9,0xfe,0x5b,0x13,0x00,0x90,0x90)
    $filter=[byte[]](0x83,0x7d,0xdc,0x10,0x0f,0x85,0x72,0xa2,0xec,0xff,0x8b,0x4d,0xd8,0x0f,0xaf,0x4d,0xbc,0xe9,0xee,0xa3,0xec,0xff)
    [Array]::Copy($hook,0,$bytes,0x9ad7d,$hook.Length)
    [Array]::Copy($filter,0,$bytes,0x1d0980,$filter.Length)
    [Array]::Copy([BitConverter]::GetBytes([uint32]0x1d0596),0,$bytes,0x1b8,4)
} else {
    if($inputHash -eq $experimentalSimulator){
        # Restore the 16-bit widescreen mode stub and original texture
        # conversion before applying the fallback to an older install.
        $mode=[byte[]](('81 7c 24 04 40 06 00 00 75 2d 83 7c 24 0c 10 75 26 8b 54 24 08 81 fa 84 03 00 00 74 08 81 fa b0 04 00 00 75 12 e8 00 00 00 00 58 89 90 b2 b9 01 00 b8 06 00 00 00 c3 55 8b ec 8b 55 10 e9 a4 b3 ee ff' -split ' ') | ForEach-Object {[Convert]::ToByte($_,16)})
        [Array]::Clear($bytes,0x13e300,90)
        [Array]::Copy($mode,0,$bytes,0x13e300,$mode.Length)
        [Array]::Clear($bytes,0x13e370,19)
        [Array]::Copy([byte[]](0x8b,0x46,0x1c,0x33,0xc9),0,$bytes,0x28cb5,5)
        [Array]::Copy([BitConverter]::GetBytes([uint32]0x13df42),0,$bytes,0x1d0,4)
    }
    # SimMain passes width, height and depth to the mode lookup.
    # Replace MOV EDX,[EDI+0x5c] with PUSH 16 / POP EDX, preserving
    # the requested dimensions and all other simulator parameters.
    [Array]::Copy([byte[]](0x6a,0x10,0x5a),0,$bytes,0x61b,3)
}
[IO.File]::WriteAllBytes($OutputDll,$bytes)
