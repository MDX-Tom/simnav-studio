#!/usr/bin/env python3
from __future__ import annotations

import hashlib
import json
import os
import sqlite3
import subprocess
import tempfile
from pathlib import Path
from typing import Any, Iterable
from urllib.parse import quote


FIXTURE_SCHEMA_VERSION = 1


def database_path(root: Path) -> Path:
    configured = os.environ.get("NAVPLANNER_PARITY_DATABASE", "").strip()
    candidates = [
        Path(configured) if configured else None,
        root / "NavPlanner/Resources/Database/navdata.sqlite",
        root / "database/e_dfd_PMDG_release.s3db",
    ]
    for candidate in candidates:
        if candidate is not None and candidate.is_file():
            return candidate.resolve()
    searched = ", ".join(str(path) for path in candidates if path is not None)
    raise FileNotFoundError(
        "Parity regression requires a local navigation database. "
        f"Set NAVPLANNER_PARITY_DATABASE or provide one of: {searched}"
    )


def database_metadata(path: Path) -> dict[str, Any]:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)

    current_airac = ""
    revision = ""
    connection = sqlite3.connect(
        f"file:{quote(str(path.resolve()))}?mode=ro",
        uri=True,
    )
    try:
        row = connection.execute(
            "SELECT current_airac, revision FROM tbl_header LIMIT 1"
        ).fetchone()
        if row:
            current_airac = "" if row[0] is None else str(row[0])
            revision = "" if row[1] is None else str(row[1])
    finally:
        connection.close()

    return {
        "sha256": digest.hexdigest(),
        "size_bytes": path.stat().st_size,
        "current_airac": current_airac,
        "revision": revision,
    }


def load_json(path: Path) -> Any:
    return json.loads(path.read_text(encoding="utf-8"))


def canonical_sha256(payload: Any) -> str:
    encoded = json.dumps(
        payload,
        ensure_ascii=False,
        sort_keys=True,
        separators=(",", ":"),
    ).encode("utf-8")
    return hashlib.sha256(encoded).hexdigest()


def result_snapshot(payload: dict[str, Any], visible_fields: Iterable[str]) -> dict[str, Any]:
    snapshot = {
        field: payload[field]
        for field in visible_fields
        if field in payload
    }
    snapshot["summary_sha256"] = canonical_sha256(payload)
    return snapshot


def snapshot_document(
    root: Path,
    database: Path,
    results: dict[str, dict[str, Any]],
    visible_fields: Iterable[str],
) -> dict[str, Any]:
    return {
        "schema_version": FIXTURE_SCHEMA_VERSION,
        "baseline": {
            "database": database_metadata(database),
        },
        "results": {
            name: result_snapshot(payload, visible_fields)
            for name, payload in sorted(results.items())
        },
    }


def compare_snapshot_documents(
    expected: dict[str, Any],
    actual: dict[str, Any],
) -> list[dict[str, Any]]:
    issues: list[dict[str, Any]] = []
    if expected.get("schema_version") != FIXTURE_SCHEMA_VERSION:
        issues.append({
            "case": "__fixture__",
            "field": "schema_version",
            "expected": FIXTURE_SCHEMA_VERSION,
            "actual": expected.get("schema_version"),
        })

    expected_database = (expected.get("baseline") or {}).get("database") or {}
    actual_database = (actual.get("baseline") or {}).get("database") or {}
    for field in ("sha256", "size_bytes", "current_airac", "revision"):
        if expected_database.get(field) != actual_database.get(field):
            issues.append({
                "case": "__database__",
                "field": field,
                "expected": expected_database.get(field),
                "actual": actual_database.get(field),
            })

    expected_results = expected.get("results") or {}
    actual_results = actual.get("results") or {}
    for name in sorted(set(expected_results) | set(actual_results)):
        if name not in expected_results:
            issues.append({
                "case": name,
                "field": "__case__",
                "expected": "missing",
                "actual": "present",
            })
            continue
        if name not in actual_results:
            issues.append({
                "case": name,
                "field": "__case__",
                "expected": "present",
                "actual": "missing",
            })
            continue
        expected_result = expected_results[name]
        actual_result = actual_results[name]
        for field in sorted(set(expected_result) | set(actual_result)):
            if expected_result.get(field) != actual_result.get(field):
                issues.append({
                    "case": name,
                    "field": field,
                    "expected": expected_result.get(field),
                    "actual": actual_result.get(field),
                })
    return issues


def run_swift_probe(
    root: Path,
    database: Path,
    cases: list[dict[str, Any]],
    sources: list[Path],
    probe_name: str,
) -> dict[str, Any]:
    environment = os.environ.copy()
    environment.pop("SDKROOT", None)
    with tempfile.TemporaryDirectory(
        prefix=f"SimNav{probe_name}-",
        dir="/private/tmp",
    ) as temporary_directory:
        temporary_root = Path(temporary_directory)
        cases_path = temporary_root / "cases.json"
        probe_binary = temporary_root / probe_name
        module_cache = temporary_root / "ModuleCache"
        cases_path.write_text(
            json.dumps(cases, ensure_ascii=False, indent=2),
            encoding="utf-8",
        )
        command = [
            "xcrun",
            "swiftc",
            "-module-cache-path",
            str(module_cache),
            *[str(source) for source in sources],
            "-lsqlite3",
            "-o",
            str(probe_binary),
        ]
        subprocess.run(command, cwd=root, env=environment, check=True)
        output = subprocess.check_output(
            [str(probe_binary), str(database), str(cases_path)],
            cwd=root,
            env=environment,
            text=True,
        )
    return json.loads(output)
