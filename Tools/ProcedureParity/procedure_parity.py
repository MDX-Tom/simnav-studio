#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[2]
FIXTURES = ROOT / "Tools/ProcedureParity/Fixtures"
CASES_PATH = FIXTURES / "cases.json"
EXPECTED_PATH = FIXTURES / "expected.json"

sys.dont_write_bytecode = True
sys.path.insert(0, str(ROOT / "Tools/Parity"))
from fixture_support import (  # noqa: E402
    compare_snapshot_documents,
    database_path,
    load_json,
    run_swift_probe,
    snapshot_document,
)


VISIBLE_FIELDS = [
    "error",
    "item_count",
    "path_count",
    "primary_count",
    "missed_count",
]


def swift_results(database: Path, cases: list[dict[str, Any]]) -> dict[str, Any]:
    sources = [
        ROOT / "NavPlanner/Core/Models/NavModels.swift",
        ROOT / "NavPlanner/Core/LocalDataStore/SQLiteDatabase.swift",
        ROOT / "NavPlanner/Core/LocalDataStore/LocalDataStore.swift",
        ROOT / "NavPlanner/Core/PlannerCore/PlannerService.swift",
        ROOT / "Tools/ProcedureParity/ProcedureParityProbe.swift",
    ]
    return run_swift_probe(
        ROOT,
        database,
        cases,
        sources,
        "ProcedureParityProbe",
    )


def main() -> int:
    parser = argparse.ArgumentParser(
        description="校验 Swift PlannerService Procedure 几何固化行为。"
    )
    parser.add_argument(
        "--dump",
        action="store_true",
        help="输出当前数据库元数据、关键字段与完整摘要 hash，不执行期望比较。",
    )
    args = parser.parse_args()

    database = database_path(ROOT)
    cases = load_json(CASES_PATH)
    results = swift_results(database, cases)
    actual = snapshot_document(ROOT, database, results, VISIBLE_FIELDS)
    if args.dump:
        print(json.dumps(actual, ensure_ascii=False, indent=2, sort_keys=True))
        return 0

    expected = load_json(EXPECTED_PATH)
    issues = compare_snapshot_documents(expected, actual)
    print(json.dumps({
        "cases": len(cases),
        "database": actual["baseline"]["database"],
        "issues": issues,
    }, ensure_ascii=False, indent=2, sort_keys=True))
    return 1 if issues else 0


if __name__ == "__main__":
    raise SystemExit(main())
