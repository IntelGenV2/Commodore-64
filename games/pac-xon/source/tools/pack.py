import os
from pathlib import Path
from resident import resident
ROOT = Path(__file__).resolve().parents[1]
work = ROOT / "build/startup"
work.mkdir(parents=True, exist_ok=True)
intro = (ROOT / "assets/studio-256.prg").read_bytes()
jar = Path(os.environ["KICKASS_JAR"]).resolve()
game = (ROOT / "build/game.prg").read_bytes()
(ROOT / "release/pacxon.prg").write_bytes(resident(intro, game, work, "java", jar))
