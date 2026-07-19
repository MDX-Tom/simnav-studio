#!/usr/bin/env python3
from __future__ import annotations

import json
import os
import shutil
import subprocess
import sys
import tempfile
import time
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[2]
CHECKS = [
    ("RouteParity", ROOT / "Tools/RouteParity/route_parity.py"),
    ("TrackParity", ROOT / "Tools/TrackParity/track_parity.py"),
    ("ProcedureParity", ROOT / "Tools/ProcedureParity/procedure_parity.py"),
]


def run_check(name: str, script: Path, environment: dict[str, str]) -> dict[str, Any]:
    started = time.monotonic()
    completed = subprocess.run(
        [sys.executable, str(script)],
        cwd=ROOT,
        env=environment,
        text=True,
        capture_output=True,
    )
    duration_ms = int((time.monotonic() - started) * 1000)
    return {
        "name": name,
        "script": str(script.relative_to(ROOT)),
        "status": "passed" if completed.returncode == 0 else "failed",
        "returncode": completed.returncode,
        "duration_ms": duration_ms,
        "stdout": completed.stdout.strip(),
        "stderr": completed.stderr.strip(),
    }


def main() -> int:
    source_database = ROOT / "NavPlanner/Resources/Database/navdata.sqlite"
    with tempfile.TemporaryDirectory(prefix="NavPlannerParity-", dir="/private/tmp") as temporary_directory:
        parity_database = Path(temporary_directory) / "navdata.sqlite"
        shutil.copy2(source_database, parity_database)
        parity_database.chmod(0o600)
        environment = os.environ.copy()
        environment.pop("SDKROOT", None)
        environment["NAVPLANNER_PARITY_DATABASE"] = str(parity_database)
        results = [run_check(name, script, environment) for name, script in CHECKS]
    failed = [result for result in results if result["returncode"] != 0]
    print(json.dumps({"checks": results}, ensure_ascii=False, indent=2))
    if failed:
        names = ", ".join(result["name"] for result in failed)
        print(f"Parity checks failed: {names}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
