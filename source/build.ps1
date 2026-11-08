param(
    [string]$LLVM='C:\Program Files\LLVM\bin',
    [string]$WindowsSdkLib='C:\Program Files (x86)\Windows Kits\10\Lib\10.0.22621.0\um\x86',
    [string]$OutputDir=(Join-Path $PSScriptRoot 'build')
)
$ErrorActionPreference='Stop'
New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
$object=Join-Path $OutputDir 'HG2JP.obj'
$dll=Join-Path $OutputDir 'HG2JP.dll'
& (Join-Path $LLVM 'clang.exe') -target i686-pc-windows-msvc -O2 -ffreestanding -fno-stack-protector -c (Join-Path $PSScriptRoot 'HG2JP.c') -o $object
if($LASTEXITCODE){throw 'Compile failed'}
& (Join-Path $LLVM 'lld-link.exe') /dll /noentry /machine:x86 /nodefaultlib ('/def:'+(Join-Path $PSScriptRoot 'HG2JP.def')) ('/out:'+$dll) $object (Join-Path $WindowsSdkLib 'Gdi32.Lib') (Join-Path $WindowsSdkLib 'Kernel32.Lib')
if($LASTEXITCODE){throw 'Link failed'}
Get-FileHash -LiteralPath $dll
