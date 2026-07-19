#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[2]
TMP_DIR = Path("/private/tmp")
CASES_PATH = TMP_DIR / "navplanner_route_parity_cases.json"
PROBE_BINARY = TMP_DIR / "NavPlannerRouteParityProbe"
MODULE_CACHE = TMP_DIR / "NavPlannerRouteParityModuleCache"


def reference_database_path(root: Path) -> Path:
    configured = os.environ.get("NAVPLANNER_PARITY_DATABASE", "").strip()
    return Path(configured) if configured else root / "NavPlanner/Resources/Database/navdata.sqlite"

CASES: list[dict[str, str]] = [
    {"name": "auto ZBAA-ZSPD", "departure": "ZBAA", "arrival": "ZSPD", "route": ""},
    {"name": "auto KLAX-KPSP", "departure": "KLAX", "arrival": "KPSP", "route": ""},
    {"name": "auto RJTT-PHNL", "departure": "RJTT", "arrival": "PHNL", "route": ""},
    {"name": "auto EGLL-KJFK", "departure": "EGLL", "arrival": "KJFK", "route": ""},
    {"name": "auto YSSY-NZAA", "departure": "YSSY", "arrival": "NZAA", "route": ""},
    {"name": "auto VHHH-WSSS", "departure": "VHHH", "arrival": "WSSS", "route": ""},
    {"name": "auto OMDB-EDDF", "departure": "OMDB", "arrival": "EDDF", "route": ""},
    {"name": "auto AGGF-AYKM", "departure": "AGGF", "arrival": "AYKM", "route": ""},
    {"name": "dateline auto NFFN-NSTU", "departure": "NFFN", "arrival": "NSTU", "route": ""},
    {"name": "dateline auto NSTU-NFFN", "departure": "NSTU", "arrival": "NFFN", "route": ""},
    {"name": "dateline auto PHNL-PGUM", "departure": "PHNL", "arrival": "PGUM", "route": ""},
    {"name": "dateline auto NFFN-NSFA", "departure": "NFFN", "arrival": "NSFA", "route": ""},
    {"name": "manual airway DODGR-V370-GARNE", "departure": "KLAX", "arrival": "KPSP", "route": "DODGR V370 GARNE"},
    {"name": "manual direct DODGR-GARNE", "departure": "KLAX", "arrival": "KPSP", "route": "DODGR DCT GARNE"},
    {"name": "manual fill DODGR-GARNE", "departure": "KLAX", "arrival": "KPSP", "route": "DODGR *** GARNE"},
    {"name": "manual lookup priority FRE", "departure": "KLAX", "arrival": "KPSP", "route": "DODGR DCT FRE"},
    {"name": "dateline manual NN-G224-TUT", "departure": "NFFN", "arrival": "NSTU", "route": "NN G224 TUT"},
    {"name": "dateline manual TUT-G224-NN", "departure": "NSTU", "arrival": "NFFN", "route": "TUT G224 NN"},
    {"name": "error leading DCT", "departure": "KLAX", "arrival": "KPSP", "route": "DCT GARNE"},
    {"name": "error missing DCT target", "departure": "KLAX", "arrival": "KPSP", "route": "DODGR DCT"},
    {"name": "error missing airway exit", "departure": "KLAX", "arrival": "KPSP", "route": "DODGR V370"},
    {"name": "error missing fill target", "departure": "KLAX", "arrival": "KPSP", "route": "DODGR ***"},
]

SUMMARY_FIELDS = [
    "route_display",
    "legs",
    "point_count",
    "point_signature",
    "geometry",
    "selected_procedures",
    "selected_runways",
    "message_kind",
]


def selected_summary(payload: dict[str, Any]) -> dict[str, Any]:
    selected = payload.get("selected_procedures") or {}
    output: dict[str, Any] = {}
    for key in ("sid", "star", "approach"):
        item = selected.get(key) or {}
        output[key] = {
            "procedure": item.get("procedure") or item.get("procedure_identifier") or "",
            "transition": item.get("transition") or item.get("transition_identifier") or "",
            "runway": item.get("runway") or "",
        }
    return output


def leg_summary(leg: dict[str, Any]) -> dict[str, Any]:
    return {
        "type": leg.get("type", ""),
        "name": leg.get("name", ""),
        "entry": leg.get("entry", ""),
        "exit": leg.get("exit", ""),
        "transition": leg.get("transition", ""),
        "count": leg.get("count", 0),
    }


def number_value(value: Any) -> float | None:
    try:
        if value is None:
            return None
        number = float(value)
    except (TypeError, ValueError):
        return None
    return number if number == number else None


def round_coord(value: Any) -> float:
    number = number_value(value)
    return round(number, 6) if number is not None else 0.0


def point_signature(points: list[dict[str, Any]]) -> list[str]:
    signature = []
    for point in points:
        ident = point.get("ident") or point.get("label") or ""
        kind = point.get("kind") or ""
        signature.append(f"{ident}|{kind}|{round_coord(point.get('lat')):.6f}|{round_coord(point.get('lon')):.6f}")
    return signature


def unwrap_longitude_near(lon: float, reference_lon: float) -> float:
    adjusted = lon
    while adjusted - reference_lon > 180:
        adjusted -= 360
    while adjusted - reference_lon < -180:
        adjusted += 360
    return adjusted


def geometry_summary(points: list[dict[str, Any]]) -> dict[str, Any]:
    raw_lons = [number for point in points if (number := number_value(point.get("lon"))) is not None]
    if len(raw_lons) < 2:
        return {
            "raw_lon_jump_count": 0,
            "max_raw_lon_delta": 0.0,
            "max_unwrapped_lon_delta": 0.0,
            "unwrapped_lon_span": 0.0,
        }
    raw_deltas = [abs(raw_lons[index] - raw_lons[index - 1]) for index in range(1, len(raw_lons))]
    unwrapped_lons = [raw_lons[0]]
    for lon in raw_lons[1:]:
        unwrapped_lons.append(unwrap_longitude_near(lon, unwrapped_lons[-1]))
    unwrapped_deltas = [abs(unwrapped_lons[index] - unwrapped_lons[index - 1]) for index in range(1, len(unwrapped_lons))]
    return {
        "raw_lon_jump_count": sum(1 for delta in raw_deltas if delta > 180),
        "max_raw_lon_delta": round(max(raw_deltas), 6),
        "max_unwrapped_lon_delta": round(max(unwrapped_deltas), 6),
        "unwrapped_lon_span": round(max(unwrapped_lons) - min(unwrapped_lons), 6),
    }


def payload_summary(payload: dict[str, Any]) -> dict[str, Any]:
    if "error" in payload:
        return {"error": payload.get("error", "")}
    points = payload.get("points", []) or []
    return {
        "route_display": payload.get("route_display", ""),
        "legs": [leg_summary(leg) for leg in payload.get("legs", [])],
        "point_count": len(points),
        "point_signature": point_signature(points),
        "geometry": geometry_summary(points),
        "distance_nm": round(float(payload.get("distance_nm") or 0), 3),
        "selected_procedures": selected_summary(payload),
        "selected_runways": payload.get("selected_runways") or {},
        "message_kind": "error" if payload.get("error") else ("generated" if payload.get("generated") else "manual"),
    }


def run_web_reference(root: Path, cases: list[dict[str, str]]) -> dict[str, Any]:
    sys.path.insert(0, str(root / "NavPlanner-web"))
    from src.planner_database import NavDatabase

    database = NavDatabase(reference_database_path(root))
    results: dict[str, Any] = {}
    for case in cases:
        try:
            payload = database.resolve_route(
                case["departure"],
                case["arrival"],
                case["route"],
                departure_runway=case.get("departureRunway", "ALL"),
                arrival_runway=case.get("arrivalRunway", "ALL"),
            )
            results[case["name"]] = payload_summary(payload)
        except Exception as error:  # Web 参考以 ValueError 表达 API 错误。
            results[case["name"]] = {"error": str(error)}
    return results


def compile_swift_probe(root: Path) -> None:
    sources = [
        root / "NavPlanner/Core/Models/NavModels.swift",
        root / "NavPlanner/Core/LocalDataStore/SQLiteDatabase.swift",
        root / "NavPlanner/Core/LocalDataStore/LocalDataStore.swift",
        root / "NavPlanner/Core/PlannerCore/PlannerService.swift",
        root / "Tools/RouteParity/RouteParityProbe.swift",
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
        for field in SUMMARY_FIELDS:
            if web_payload.get(field) != swift_payload.get(field):
                issues.append({"case": name, "field": field, "web": web_payload.get(field), "swift": swift_payload.get(field)})
        if abs(float(web_payload.get("distance_nm", 0)) - float(swift_payload.get("distance_nm", 0))) > 0.01:
            issues.append({
                "case": name,
                "field": "distance_nm",
                "web": web_payload.get("distance_nm"),
                "swift": swift_payload.get("distance_nm"),
            })
    return issues


def main() -> int:
    parser = argparse.ArgumentParser(description="对照 NavPlanner iOS Swift route resolve 与 NavPlanner-web 参考输出。")
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
