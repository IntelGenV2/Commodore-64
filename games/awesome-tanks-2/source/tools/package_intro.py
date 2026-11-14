import os
from pathlib import Path
from resident import resident
ROOT = Path(__file__).resolve().parents[1]
work = ROOT / "build/startup"
work.mkdir(parents=True, exist_ok=True)
intro = (ROOT / "assets/studio-256.prg").read_bytes()
jar = Path(os.environ["KICKASS_JAR"]).resolve()
from resident import tanks_inner
import subprocess
native = ROOT / "build/native.prg"
compressed = work / "game-sfx.prg"
subprocess.run(["exomizer", "sfx", "2061", native, "-n", "-o", compressed], check=True)
game = tanks_inner(native.read_bytes(), compressed)
(ROOT / "release/tanks.prg").write_bytes(resident(intro, game, work, "java", jar, inner_game=True))
