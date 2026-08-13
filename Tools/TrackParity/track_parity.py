#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[2]
FIXTURES = ROOT / "Tools/TrackParity/Fixtures"
CASES_PATH = FIXTURES / "cases.json"
EXPECTED_PATH = FIXTURES / "expected.json"
PROCEDURE_REGRESSION_PATHS = [
    FIXTURES / "zppp_zbaa_fr24_procedure.json",
    FIXTURES / "zbaa_zsss_partial_sid_procedure_first.json",
    FIXTURES / "zbaa_zppp_parallel_runway_mebna.json",
]

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
    "route_display",
    "point_count",
    "distance_nm",
    "selected_procedures",
    "selected_runways",
    "message_kind",
    "source_provider",
    "source_track_count",
]


def swift_results(database: Path, cases: list[dict[str, Any]]) -> dict[str, Any]:
    sources = [
        ROOT / "NavPlanner/Core/Models/NavModels.swift",
        ROOT / "NavPlanner/Core/LocalDataStore/SQLiteDatabase.swift",
        ROOT / "NavPlanner/Core/LocalDataStore/LocalDataStore.swift",
        ROOT / "NavPlanner/Core/PlannerCore/PlannerService.swift",
        ROOT / "Tools/TrackParity/TrackParityProbe.swift",
    ]
    return run_swift_probe(
        ROOT,
        database,
        cases,
        sources,
        "TrackParityProbe",
    )


def compare_procedure_regressions(
    regression_cases: list[dict[str, Any]],
    results: dict[str, Any],
) -> list[dict[str, Any]]:
    issues: list[dict[str, Any]] = []
    for case in regression_cases:
        name = case["name"]
        payload = results.get(name) or {}
        selected = payload.get("selected_procedures") or {}
        runways = payload.get("selected_runways") or {}
        legs = payload.get("legs") or []
        procedure_items = payload.get("selected_procedure_items") or {}
        actual = {
            "sid.procedure": (selected.get("sid") or {}).get("procedure"),
            "sid.transition": (selected.get("sid") or {}).get("transition"),
            "star.procedure": (selected.get("star") or {}).get("procedure"),
            "star.transition": (selected.get("star") or {}).get("transition"),
            "approach.procedure": (selected.get("approach") or {}).get("procedure"),
            "approach.transition": (selected.get("approach") or {}).get("transition"),
            "departure_runway": runways.get("departure"),
            "arrival_runway": runways.get("arrival"),
            "enroute_start": legs[0].get("entry") if legs else None,
            "enroute_end": legs[-1].get("exit") if legs else None,
        }
        for procedure_type in ("sid", "star", "approach"):
            item_idents = procedure_items.get(procedure_type) or []
            actual[f"{procedure_type}.items_first"] = item_idents[0] if item_idents else None
            actual[f"{procedure_type}.items_last"] = item_idents[-1] if item_idents else None
        for field, expected in (case.get("expected") or {}).items():
            if actual.get(field) != expected:
                issues.append({
                    "case": name,
                    "field": field,
                    "expected": expected,
                    "actual": actual.get(field),
                })
    return issues


def main() -> int:
    parser = argparse.ArgumentParser(
        description="校验 Swift PlannerService track-match 固化行为。"
    )
    parser.add_argument(
        "--dump",
        action="store_true",
        help="输出当前数据库元数据、关键字段与完整摘要 hash，不执行期望比较。",
    )
    args = parser.parse_args()

    database = database_path(ROOT)
    base_cases = load_json(CASES_PATH)
    regression_cases = [load_json(path) for path in PROCEDURE_REGRESSION_PATHS]
    cases = base_cases + regression_cases
    results = swift_results(database, cases)
    actual = snapshot_document(ROOT, database, results, VISIBLE_FIELDS)
    if args.dump:
        print(json.dumps(actual, ensure_ascii=False, indent=2, sort_keys=True))
        return 0

    expected = load_json(EXPECTED_PATH)
    issues = compare_snapshot_documents(expected, actual)
    issues.extend(compare_procedure_regressions(regression_cases, results))
    print(json.dumps({
        "cases": len(cases),
        "database": actual["baseline"]["database"],
        "issues": issues,
    }, ensure_ascii=False, indent=2, sort_keys=True))
    return 1 if issues else 0


if __name__ == "__main__":
    raise SystemExit(main())
