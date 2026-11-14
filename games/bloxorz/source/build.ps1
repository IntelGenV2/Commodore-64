param([string]$Compiler='cl65', [string]$Python='python')
$ErrorActionPreference = 'Stop'
Push-Location $PSScriptRoot
try {
    New-Item -ItemType Directory -Force -Path build,release | Out-Null
    & $Compiler -t c64 -Oirs --static-locals -Wl '-D,__HIMEM__=49152' -Wl '-D,__STACKSIZE__=768' -m build/bloxorz.map -Ln build/bloxorz.lbl -o build/bloxorz.prg src/main.c src/engine.c src/hardware.s src/audio.s
    if ($LASTEXITCODE) { throw 'C64 build failed' }
    # The title bank is copied beneath I/O before screen memory is used.
    $Game = [IO.File]::ReadAllBytes((Resolve-Path 'build/bloxorz.prg'))
    $Bank = [IO.File]::ReadAllBytes((Resolve-Path 'src/menu_bank.bin'))
    $BankOffset = 2 + 0xc000 - [BitConverter]::ToUInt16($Game, 0)
    if ($Game.Length -gt $BankOffset -or $Bank.Length -gt 4096) { throw 'Title bank overlaps a memory boundary' }
    $Image = [byte[]]::new($BankOffset + $Bank.Length)
    $Game.CopyTo($Image, 0)
    $Bank.CopyTo($Image, $BankOffset)
    [IO.File]::WriteAllBytes((Resolve-Path 'build/bloxorz.prg'), $Image)
    & exomizer sfx 2061 build/bloxorz.prg -n -o release/bloxorz64.prg
    if ($LASTEXITCODE) { throw 'Packing failed' }
    & $Python tools/make_d64.py release/bloxorz64.prg release/bloxorz64.d64
    if ($LASTEXITCODE) { throw 'Disk build failed' }
} finally { Pop-Location }
