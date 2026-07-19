#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import os
import subprocess
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[2]
TMP_DIR = Path("/private/tmp")
CASES_PATH = TMP_DIR / "navplanner_procedure_parity_cases.json"
PROBE_BINARY = TMP_DIR / "NavPlannerProcedureParityProbe"
MODULE_CACHE = TMP_DIR / "NavPlannerProcedureParityModuleCache"


def reference_database_path(root: Path) -> Path:
    configured = os.environ.get("NAVPLANNER_PARITY_DATABASE", "").strip()
    return Path(configured) if configured else root / "NavPlanner/Resources/Database/navdata.sqlite"

TABLES = {
    "sid": "tbl_sids",
    "star": "tbl_stars",
    "approach": "tbl_iaps",
}

CASES: list[dict[str, str]] = [
    {"name": "sid RF BIAR ASKU1D RW19", "type": "sid", "airport": "BIAR", "procedure": "ASKU1D", "transition": "RW19"},
    {"name": "star RF MTCH NOSO1L RW05", "type": "star", "airport": "MTCH", "procedure": "NOSO1L", "transition": "RW05"},
    {"name": "approach missed holding 07FA R05-P ALL", "type": "approach", "airport": "07FA", "procedure": "R05-P", "transition": "ALL"},
    {"name": "approach transition merge 07FA R05-P ADONE", "type": "approach", "airport": "07FA", "procedure": "R05-P", "transition": "ADONE"},
    {"name": "approach ZULS R10L LS995", "type": "approach", "airport": "ZULS", "procedure": "R10L", "transition": "LS995"},
    {"name": "empty missing approach", "type": "approach", "airport": "XXXX", "procedure": "NOPE", "transition": "ALL"},
]

COMPARE_FIELDS = [
    "item_count",
    "item_signature",
    "path_count",
    "path_signature",
    "primary_count",
    "primary_signature",
    "missed_count",
    "missed_signature",
]


def number_value(value: Any) -> float | None:
    try:
        if value is None:
            return None
        number = float(value)
    except (TypeError, ValueError):
        return None
    return number if number == number else None


def string_value(value: Any) -> str:
    return "" if value is None else str(value)


def round_coord(value: Any) -> float:
    number = number_value(value)
    return round(number, 6) if number is not None else 0.0


def point_signature(points: list[dict[str, Any]]) -> list[str]:
    return [
        f"{round_coord(point.get('lat')):.6f}|{round_coord(point.get('lon')):.6f}"
        for point in points
    ]


def item_signature(items: list[dict[str, Any]]) -> list[str]:
    signature: list[str] = []
    for item in items:
        signature.append("|".join([
            string_value(item.get("seqno")),
            string_value(item.get("waypoint_identifier")),
            string_value(item.get("path_termination")),
            string_value(item.get("route_type")),
            f"{round_coord(item.get('waypoint_latitude')):.6f}",
            f"{round_coord(item.get('waypoint_longitude')):.6f}",
            string_value(item.get("center_waypoint")),
            f"{round_coord(item.get('center_waypoint_latitude')):.6f}",
            f"{round_coord(item.get('center_waypoint_longitude')):.6f}",
        ]))
    return signature


def payload_summary(payload: dict[str, Any]) -> dict[str, Any]:
    if "error" in payload:
        return {"error": payload.get("error", "")}
    items = payload.get("items") or []
    path = payload.get("path") or []
    primary = payload.get("primary_path") or []
    missed = payload.get("missed_path") or []
    return {
        "item_count": len(items),
        "item_signature": item_signature(items),
        "path_count": len(path),
        "path_signature": point_signature(path),
        "primary_count": len(primary),
        "primary_signature": point_signature(primary),
        "missed_count": len(missed),
        "missed_signature": point_signature(missed),
    }


def run_web_reference(root: Path, cases: list[dict[str, str]]) -> dict[str, Any]:
    import sys

    sys.path.insert(0, str(root / "NavPlanner-web"))
    from src.planner_database import NavDatabase

    database = NavDatabase(reference_database_path(root))
    results: dict[str, Any] = {}
    for case in cases:
        try:
            payload = database.procedure_geometry(
                airport=case["airport"],
                table=TABLES[case["type"]],
                procedure=case["procedure"],
                transition=case["transition"],
            )
            results[case["name"]] = payload_summary(payload)
        except Exception as error:
            results[case["name"]] = {"error": str(error)}
    return results


def compile_swift_probe(root: Path) -> None:
    sources = [
        root / "NavPlanner/Core/Models/NavModels.swift",
        root / "NavPlanner/Core/LocalDataStore/SQLiteDatabase.swift",
        root / "NavPlanner/Core/LocalDataStore/LocalDataStore.swift",
        root / "NavPlanner/Core/PlannerCore/PlannerService.swift",
        root / "Tools/ProcedureParity/ProcedureParityProbe.swift",
    ]
    command = [
        "xcrun",
        "swiftc",
        "-module-cache-path",
        str(MODULE_CACHE),
        *[str(source) for source in sources],
        "-lsqlite3",
        "-o",
        str(PROBE_BINARY),
    ]
    subprocess.run(command, cwd=root, check=True)


def run_swift_probe(root: Path, cases: list[dict[str, str]]) -> dict[str, Any]:
    CASES_PATH.write_text(json.dumps(cases, ensure_ascii=False, indent=2), encoding="utf-8")
    compile_swift_probe(root)
    output = subprocess.check_output([str(PROBE_BINARY), str(root), str(CASES_PATH)], text=True)
    return json.loads(output)


def compare_results(web_results: dict[str, Any], swift_results: dict[str, Any]) -> list[dict[str, Any]]:
    issues: list[dict[str, Any]] = []
    for name, web_payload in web_results.items():
        swift_payload = swift_results.get(name)
        if swift_payload is None:
            issues.append({"case": name, "field": "__case__", "web": "present", "swift": "missing"})
            continue
        if "error" in web_payload or "error" in swift_payload:
            if web_payload != swift_payload:
                issues.append({"case": name, "field": "error", "web": web_payload, "swift": swift_payload})
            continue
        for field in COMPARE_FIELDS:
            if web_payload.get(field) != swift_payload.get(field):
                issues.append({"case": name, "field": field, "web": web_payload.get(field), "swift": swift_payload.get(field)})
    return issues


def main() -> int:
    parser = argparse.ArgumentParser(description="对照 NavPlanner iOS Swift Procedure 几何与 NavPlanner-web 参考输出。")
    parser.add_argument("--dump", action="store_true", help="输出完整 Web / Swift 摘要 JSON。")
    args = parser.parse_args()

    web_results = run_web_reference(ROOT, CASES)
    swift_results = run_swift_probe(ROOT, CASES)
    issues = compare_results(web_results, swift_results)

    if args.dump:
        print(json.dumps({"web": web_results, "swift": swift_results}, ensure_ascii=False, indent=2, sort_keys=True))

    summary = {
        "cases": len(CASES),
        "issues": issues,
    }
    print(json.dumps(summary, ensure_ascii=False, indent=2, sort_keys=True))
    return 1 if issues else 0


if __name__ == "__main__":
    raise SystemExit(main())
