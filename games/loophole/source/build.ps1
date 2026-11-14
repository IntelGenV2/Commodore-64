param([string]$Compiler='cl65', [string]$Python='python', [string]$DiskTool='c1541')
$ErrorActionPreference = 'Stop'
Push-Location $PSScriptRoot
try {
    New-Item -ItemType Directory -Force -Path build,release | Out-Null
    & $Python tools/art.py
    if ($LASTEXITCODE) { throw 'Pixel-art build failed' }
    foreach ($unit in 'game.c','passes.c','save.c','sound.c','machine.s') {
        $object = 'build/' + [IO.Path]::GetFileNameWithoutExtension($unit) + '.o'
        & $Compiler -t c64 -Oirs --static-locals -c -o $object "src/$unit"
        if ($LASTEXITCODE) { throw "Compilation failed for $unit" }
    }
    & $Compiler -t c64 -Wl '-D,__HIMEM__=47104' -Ln build/loophole.lbl -o release/loophole.prg build/game.o build/passes.o build/save.o build/sound.o build/machine.o
    if ($LASTEXITCODE) { throw 'Link failed' }
    foreach ($album in 'victory','worlds') {
        $cOptions = @()
        $asmOptions = @()
        if ($album -eq 'worlds') {
            $cOptions = @('-D', 'WORLD_ALBUM=1')
            $asmOptions = @('--asm-define', 'WORLD_ALBUM=1')
        }
        & $Compiler -t none -Oirs --static-locals @cOptions -c -o "build/$album-player.o" src/sid_player.c
        if ($LASTEXITCODE) { throw "$album SID player compilation failed" }
        & $Compiler -t none @asmOptions -c -o "build/$album-entry.o" src/sid_entry.s
        if ($LASTEXITCODE) { throw "$album SID entry assembly failed" }
        & $Compiler -t none -C src/sid.cfg -o "release/loophole-$album.sid" "build/$album-entry.o" "build/$album-player.o" build/sound.o
        if ($LASTEXITCODE) { throw "$album SID link failed" }
    }
    & $Python tools/package_disk.py $DiskTool
    if ($LASTEXITCODE) { throw 'Disk packaging failed' }
    Get-Item -LiteralPath release/loophole.prg,release/loophole.d64,release/loophole-victory.sid,release/loophole-worlds.sid | Select-Object Name,Length
} finally {
    Pop-Location
}
