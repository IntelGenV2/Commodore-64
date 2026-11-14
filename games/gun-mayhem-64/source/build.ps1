param([string]$Python='python')
$ErrorActionPreference = 'Stop'
Push-Location $PSScriptRoot
try {
    New-Item -ItemType Directory -Force -Path 'build\files' | Out-Null
    & $Python tools\generate_port.py
    if ($LASTEXITCODE -ne 0) { throw 'Asset generation failed' }
    & $Python tools\build_menu_music.py
    if ($LASTEXITCODE -ne 0) { throw 'Menu music assembly failed' }
    java -jar $env:KICKASS_JAR src\port.asm -o build\files\gunmayhem.prg -symbolfile -vicesymbols
    if ($LASTEXITCODE -ne 0) { throw 'Assembly failed' }
    java -jar $env:KICKASS_JAR src\loader.asm -o build\files\loader.prg -symbolfile -vicesymbols
    if ($LASTEXITCODE -ne 0) { throw 'Loader assembly failed' }
    & $Python tools\package_port.py
    if ($LASTEXITCODE -ne 0) { throw 'Disk creation failed' }
    Get-Item build\gunmayhem64.d64 | Select-Object FullName,Length
} finally {
    Pop-Location
}
