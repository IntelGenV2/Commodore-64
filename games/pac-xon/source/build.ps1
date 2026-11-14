param([string]$Compiler='cl65', [string]$Python='python')
$ErrorActionPreference = 'Stop'
Push-Location $PSScriptRoot
try {
    New-Item -ItemType Directory -Force build,release | Out-Null
    $objects=@()
    foreach ($unit in 'main.c','display.c','game.c','machine.s','actors.s','menu_music.s') {
        $obj='build/'+[IO.Path]::GetFileNameWithoutExtension($unit)+'.o'
        & $Compiler -t c64 -g -Oirs --static-locals -c -o $obj "src/$unit"
        if ($LASTEXITCODE) {throw "Compile failed for $unit"}
        $objects+=$obj
    }
    & $Compiler -t c64 -Wl '-D,__HIMEM__=49152' -Wl '-D,__STACKSIZE__=512' -Ln build/pacxon.lbl -m build/pacxon.map -o build/game.prg @objects
    if ($LASTEXITCODE) {throw 'Link failed'}
    & $Compiler -t none -c -o build/menu_sid.o src/menu_sid.s
    if ($LASTEXITCODE) {throw 'SID header assembly failed'}
    & $Compiler -t none -C src/sid.cfg -o release/pacxon-title.sid build/menu_sid.o build/menu_music.o
    if ($LASTEXITCODE) {throw 'Standalone SID link failed'}
    & $Python -B tools/pack.py
    if ($LASTEXITCODE) {throw 'Packaging failed'}
    Get-Item release/pacxon.prg | Select-Object Name,Length
} finally {Pop-Location}
