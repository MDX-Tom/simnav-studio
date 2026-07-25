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
CASES_PATH = TMP_DIR / "navplanner_track_parity_cases.json"
PROBE_BINARY = TMP_DIR / "NavPlannerTrackParityProbe"
MODULE_CACHE = TMP_DIR / "NavPlannerTrackParityModuleCache"
PROCEDURE_REGRESSION_PATHS = [
    ROOT / "Tools/TrackParity/Fixtures/zppp_zbaa_fr24_procedure.json",
    ROOT / "Tools/TrackParity/Fixtures/zbaa_zsss_partial_sid_procedure_first.json",
    ROOT / "Tools/TrackParity/Fixtures/zbaa_zppp_parallel_runway_mebna.json",
]


def reference_database_path(root: Path) -> Path:
    configured = os.environ.get("NAVPLANNER_PARITY_DATABASE", "").strip()
    return Path(configured) if configured else root / "NavPlanner/Resources/Database/navdata.sqlite"

sys.dont_write_bytecode = True
sys.path.insert(0, str(ROOT / "Tools/RouteParity"))
from route_parity import payload_summary  # noqa: E402


TRACK_CASES: list[dict[str, str]] = [
    {"name": "track KLAX-KPSP airway", "departure": "KLAX", "arrival": "KPSP", "seed_route": "DODGR V370 GARNE"},
    {"name": "track KLAX-KPSP fill", "departure": "KLAX", "arrival": "KPSP", "seed_route": "DODGR *** GARNE"},
    {"name": "track ZBAA-ZSPD auto", "departure": "ZBAA", "arrival": "ZSPD", "seed_route": ""},
    {"name": "track VHHH-WSSS auto", "departure": "VHHH", "arrival": "WSSS", "seed_route": ""},
    {"name": "track dateline NFFN-NSTU", "departure": "NFFN", "arrival": "NSTU", "seed_route": ""},
]

ERROR_CASES: list[dict[str, Any]] = [
    {
        "name": "error imported track too short",
        "departure": "KLAX",
        "arrival": "KPSP",
        "track_points": [{"lat": 33.9, "lon": -118.1}],
    },
    {
        "name": "error unresolved departure",
        "departure": "ZZZZ",
        "arrival": "KPSP",
        "seed_departure": "KLAX",
        "seed_arrival": "KPSP",
        "seed_route": "DODGR V370 GARNE",
    },
]

COMPARE_FIELDS = [
    "route_display",
    "legs",
    "point_count",
    "point_signature",
    "geometry",
    "selected_procedures",
    "selected_runways",
    "message_kind",
    "source_provider",
    "source_track_count",
]


def number_value(value: Any) -> float | None:
    try:
        if value is None:
            return None
        number = float(value)
    except (TypeError, ValueError):
        return None
    return number if number == number else None


def track_points_from_payload(payload: dict[str, Any], max_points: int = 80) -> list[dict[str, float]]:
    points: list[dict[str, float]] = []
    for item in payload.get("points", []) or []:
        lat = number_value(item.get("lat"))
        lon = number_value(item.get("lon"))
        if lat is None or lon is None:
            continue
        if points and round(points[-1]["lat"], 7) == round(lat, 7) and round(points[-1]["lon"], 7) == round(lon, 7):
            continue
        points.append({"lat": lat, "lon": lon})

    if len(points) <= max_points:
        return points

    indices = {
        round(index * (len(points) - 1) / (max_points - 1))
        for index in range(max_points)
    }
    return [points[index] for index in sorted(indices)]


def track_payload_summary(payload: dict[str, Any]) -> dict[str, Any]:
    summary = payload_summary(payload)
    if "error" in summary:
        return summary
    source = payload.get("source") or {}
    summary["source_provider"] = source.get("provider", "")
    summary["source_track_count"] = len(source.get("track_points") or [])
    return summary


def build_cases(database: Any) -> list[dict[str, Any]]:
    cases: list[dict[str, Any]] = []
    for case in TRACK_CASES:
        seed_payload = database.resolve_route(case["departure"], case["arrival"], case["seed_route"])
        cases.append({
            "name": case["name"],
            "departure": case["departure"],
            "arrival": case["arrival"],
            "track_points": track_points_from_payload(seed_payload),
        })

    for case in ERROR_CASES:
        track_points = case.get("track_points")
        if track_points is None:
            seed_payload = database.resolve_route(
                case["seed_departure"],
                case["seed_arrival"],
                case["seed_route"],
            )
            track_points = track_points_from_payload(seed_payload)
        cases.append({
            "name": case["name"],
            "departure": case["departure"],
            "arrival": case["arrival"],
            "track_points": track_points,
        })
    return cases


def run_web_reference(root: Path) -> tuple[list[dict[str, Any]], dict[str, Any]]:
    sys.path.insert(0, str(root / "NavPlanner-web"))
    from src.planner_database import NavDatabase

    database = NavDatabase(reference_database_path(root))
    cases = build_cases(database)
    results: dict[str, Any] = {}
    for case in cases:
        try:
            payload = database.match_imported_track_route(
                case["departure"],
                case["arrival"],
                case["track_points"],
            )
            results[case["name"]] = track_payload_summary(payload)
        except Exception as error:  # Web 参考以 ValueError 表达 API 错误。
            results[case["name"]] = {"error": str(error)}
    return cases, results


def compile_swift_probe(root: Path) -> None:
    sources = [
        root / "NavPlanner/Core/Models/NavModels.swift",
        root / "NavPlanner/Core/LocalDataStore/SQLiteDatabase.swift",
        root / "NavPlanner/Core/LocalDataStore/LocalDataStore.swift",
        root / "NavPlanner/Core/PlannerCore/PlannerService.swift",
        root / "Tools/TrackParity/TrackParityProbe.swift",
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


def run_swift_probe(root: Path, cases: list[dict[str, Any]]) -> dict[str, Any]:
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
        if abs(float(web_payload.get("distance_nm", 0)) - float(swift_payload.get("distance_nm", 0))) > 0.01:
            issues.append({
                "case": name,
                "field": "distance_nm",
                "web": web_payload.get("distance_nm"),
                "swift": swift_payload.get("distance_nm"),
            })
    return issues


def load_swift_regression_cases() -> list[dict[str, Any]]:
    return [
        json.loads(path.read_text(encoding="utf-8"))
        for path in PROCEDURE_REGRESSION_PATHS
    ]


def compare_swift_regressions(
    regression_cases: list[dict[str, Any]],
    swift_results: dict[str, Any],
) -> list[dict[str, Any]]:
    issues: list[dict[str, Any]] = []
    for case in regression_cases:
        name = case["name"]
        payload = swift_results.get(name) or {}
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
                    "swift": actual.get(field),
                    "expected": expected,
                })
    return issues


def main() -> int:
    parser = argparse.ArgumentParser(description="对照 NavPlanner iOS Swift track-match 与 NavPlanner-web 参考输出。")
    parser.add_argument("--dump", action="store_true", help="输出完整 Web / Swift 摘要 JSON。")
    args = parser.parse_args()

    cases, web_results = run_web_reference(ROOT)
    regression_cases = load_swift_regression_cases()
    swift_results = run_swift_probe(ROOT, cases + regression_cases)
    issues = compare_results(web_results, swift_results)
    issues.extend(compare_swift_regressions(regression_cases, swift_results))

    if args.dump:
        print(json.dumps({
            "cases": cases + regression_cases,
            "web": web_results,
            "swift": swift_results,
        }, ensure_ascii=False, indent=2, sort_keys=True))

    summary = {
        "cases": len(cases) + len(regression_cases),
        "issues": issues,
    }
    print(json.dumps(summary, ensure_ascii=False, indent=2, sort_keys=True))
    return 1 if issues else 0


if __name__ == "__main__":
    raise SystemExit(main())
