param([string]$Compiler='cl65', [string]$Python='python', [string]$DiskTool='c1541')
$ErrorActionPreference = 'Stop'
Push-Location $PSScriptRoot
try {
    New-Item -ItemType Directory -Force -Path build,release | Out-Null
    & $Python tools/assets.py
    if ($LASTEXITCODE) {throw 'Asset generation failed'}
    $objects = @()
    foreach ($unit in 'main.c','game.c','enemy.c','display.c','input.c','sound.c','save.c','assets.c','hardware.s','music.s') {
        $obj = 'build/' + [IO.Path]::GetFileNameWithoutExtension($unit) + '.o'
        & $Compiler -t c64 -Ors -g --static-locals -c -o $obj "src/$unit"
        if ($LASTEXITCODE) {throw "Compilation failed for $unit"}
        $objects += $obj
    }
    & $Compiler -t c64 -Wl '-D,__HIMEM__=49152' -Wl '-D,__STACKSIZE__=384' -Ln build/tanks.lbl -m build/tanks.map -o build/runtime.prg @objects
    if ($LASTEXITCODE) {throw 'Link failed'}
    & $Python tools/pack.py
    if ($LASTEXITCODE) {throw 'Boot packaging failed'}
    & $Python tools/package_intro.py
    if ($LASTEXITCODE) {throw 'Studio 256 startup packaging failed'}
    & $Python -B tools/update_disk.py $DiskTool
    if ($LASTEXITCODE) { throw 'Disk update failed' }
    Get-Item release/tanks.d64
} finally { Pop-Location }
