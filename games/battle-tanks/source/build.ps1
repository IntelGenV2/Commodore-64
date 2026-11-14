param([string]$Compiler='cl65', [string]$Python='python')
$ErrorActionPreference = 'Stop'
Push-Location $PSScriptRoot
try {
    New-Item -ItemType Directory -Force build | Out-Null
    & $Compiler -t c64 -Oirs --static-locals -Wl '-D,__HIMEM__=49152' -Wl '-D,__STACKSIZE__=1024' -m build\battletanks.map -Ln build\battletanks.lbl -o build\battletanks-native.prg src\main.c src\display.c src\engine.c src\hardware.s src\audio.s
    if ($LASTEXITCODE -ne 0) { throw 'C64 build failed' }
    & $Python tools\build_startup.py
    if ($LASTEXITCODE -ne 0) { throw 'Studio 256 startup build failed' }
    & $Python tools\make_d64.py build\battletanks.prg build\battletanks.d64
    if ($LASTEXITCODE -ne 0) { throw 'Disk build failed' }
    Get-Item build\battletanks.prg,build\battletanks.d64 | Select-Object Name,Length
} finally { Pop-Location }
