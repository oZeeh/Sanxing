#!/usr/bin/env python3
"""Standard-library-only analysis for canonical Sanxing experiment bundles."""

from __future__ import annotations

import csv
import datetime as dt
import hashlib
import html
import json
import math
import os
import platform
import shlex
import subprocess
import sys
from pathlib import Path


PERFORMANCE_COUNTS = [100, 500, 1000, 5000, 10000]
PERFORMANCE_THETAS = [0.25, 0.5, 1.0]
ACCURACY_COUNTS = [100, 500, 1000, 5000, 10000]
ACCURACY_THETAS = [0.0, 0.25, 0.5, 1.0]
ORBIT_CASES = ["two_body_orbit_100", "two_body_orbit_200", "two_body_orbit_400"]
SENSITIVITY_CASES = ["burrau_base_001", "burrau_perturbed_001", "burrau_base_0005", "burrau_perturbed_0005"]
TRAJECTORY_CASES = ORBIT_CASES + SENSITIVITY_CASES

PERFORMANCE_COLUMNS = {
    "body_count", "solver", "theta", "sample_count", "elapsed_mean_seconds",
    "elapsed_stddev_seconds", "direct_interactions_mean", "approximated_interactions_mean",
    "tree_node_visits_mean", "speedup_vs_brute_force", "run_id", "target_label", "opt_label",
}
ACCURACY_COLUMNS = {
    "body_count", "theta", "normalized_l2_acceleration_error", "mean_absolute_acceleration_error",
    "max_absolute_acceleration_error", "direct_interactions", "approximated_interactions",
    "tree_node_visits", "run_id", "target_label", "opt_label",
}


def command_output(*args: str) -> str:
    try:
        return subprocess.check_output(args, text=True, stderr=subprocess.DEVNULL).strip()
    except (OSError, subprocess.CalledProcessError):
        return "unavailable"


def experiment_commands(root: Path, run_id: str, target_label: str) -> list[list[str]]:
    commands = [[
        "odin", "run", "engine/src", "-o:speed", "--", "benchmark",
        str(root / "raw/performance.jsonl"), "--summary", str(root / "summary/performance.csv"),
        "--solver", "both", "--thetas", ",".join(map(str, PERFORMANCE_THETAS)),
        "--counts", ",".join(map(str, PERFORMANCE_COUNTS)), "--steps", "10", "--samples", "10",
        "--warmups", "2", "--run-id", run_id, "--target-label", target_label, "--opt-label", "speed",
    ], [
        "odin", "run", "engine/src", "-o:speed", "--", "accuracy",
        str(root / "raw/accuracy.jsonl"), "--summary", str(root / "summary/accuracy.csv"),
        "--counts", ",".join(map(str, ACCURACY_COUNTS)), "--thetas", ",".join(map(str, ACCURACY_THETAS)),
        "--run-id", run_id, "--target-label", target_label, "--opt-label", "speed",
    ]]
    for name in TRAJECTORY_CASES:
        commands.append([
            "odin", "run", "engine/src", "-o:speed", "--", "simulate",
            f"engine/examples/experiments/{name}.json", str(root / f"trajectories/{name}.jsonl"),
            "--diagnostics", str(root / f"trajectories/{name}-diagnostics.jsonl"),
        ])
    return commands


def write_manifest(path: Path, run_id: str, target_label: str) -> None:
    root = path.parent
    commands = experiment_commands(root, run_id, target_label)
    manifest = {
        "schema_version": 2,
        "run_id": run_id,
        "status": "running",
        "created_utc": dt.datetime.now(dt.timezone.utc).isoformat(),
        "git_commit": command_output("git", "rev-parse", "HEAD"),
        # The results directory may already exist as an untracked path inside the repository.
        # The runner verifies all tracked and untracked inputs before creating it.
        "git_dirty": command_output("git", "status", "--porcelain", "--untracked-files=no") != "",
        "odin_version": command_output("odin", "version"),
        "platform": platform.platform(),
        "hostname": platform.node(),
        "machine": platform.machine(),
        "processor": platform.processor() or command_output("sh", "-c", "grep -m1 'model name' /proc/cpuinfo"),
        "logical_cpu_count": os.cpu_count(),
        "python_version": platform.python_version(),
        "target_label": target_label,
        "optimization": "speed",
        "commands": [{"argv": command, "shell": shlex.join(command)} for command in commands],
        "matrices": {
            "performance": {
                "scenario": "scaling_golden_angle_v1", "counts": PERFORMANCE_COUNTS,
                "solvers": ["brute_force", "barnes_hut"], "thetas": PERFORMANCE_THETAS,
                "steps": 10, "samples": 10, "warmups": 2,
            },
            "force_accuracy": {
                "scenario": "force_accuracy_golden_angle_v1", "counts": ACCURACY_COUNTS,
                "reference_solver": "brute_force", "candidate_solver": "barnes_hut",
                "thetas": ACCURACY_THETAS, "exact_control_tolerance": 1e-12,
            },
            "orbit_convergence": {
                "cases": ORBIT_CASES,
                "expected_steps": {"two_body_orbit_100": 100, "two_body_orbit_200": 200, "two_body_orbit_400": 400},
            },
            "trajectory_sensitivity": {"pairs": [
                {"delta_time": 0.001, "steps": 20000, "base": "burrau_base_001", "perturbed": "burrau_perturbed_001"},
                {"delta_time": 0.0005, "steps": 40000, "base": "burrau_base_0005", "perturbed": "burrau_perturbed_0005"},
            ]},
        },
    }
    path.write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def read_csv(path: Path, required: set[str] | None = None) -> list[dict[str, str]]:
    with path.open(newline="", encoding="utf-8") as handle:
        reader = csv.DictReader(handle)
        missing = (required or set()) - set(reader.fieldnames or [])
        if missing:
            raise ValueError(f"{path}: missing CSV columns: {', '.join(sorted(missing))}")
        rows = list(reader)
    if not rows:
        raise ValueError(f"{path}: contains no data rows")
    return rows


def read_jsonl(path: Path):
    with path.open(encoding="utf-8") as handle:
        found = False
        for line_number, line in enumerate(handle, 1):
            if line.strip():
                found = True
                try:
                    yield json.loads(line)
                except json.JSONDecodeError as exc:
                    raise ValueError(f"{path}:{line_number}: {exc}") from exc
        if not found:
            raise ValueError(f"{path}: contains no records")


def finite_float(row: dict[str, str], field: str, context: str) -> float:
    try:
        value = float(row[field])
    except (KeyError, ValueError) as exc:
        raise ValueError(f"{context}: invalid {field}") from exc
    if not math.isfinite(value):
        raise ValueError(f"{context}: non-finite {field}")
    return value


def svg_plot(path: Path, title: str, x_label: str, y_label: str,
             series: list[tuple[str, list[tuple[float, float]]]], log_x: bool = False,
             log_y: bool = False, error_series: dict[str, list[tuple[float, float]]] | None = None) -> None:
    width, height = 900, 520
    left, right, top, bottom = 90, 30, 55, 70
    colors = ["#42c6a4", "#f2b84b", "#7db7ff", "#ef6f6c", "#d39cff", "#ff9f7d"]

    def downsample(values: list[tuple[float, float]], limit: int = 2000) -> list[tuple[float, float]]:
        if len(values) <= limit:
            return values
        return [values[round(index * (len(values) - 1) / (limit - 1))] for index in range(limit)]

    series = [(label, downsample(values)) for label, values in series]
    points = [point for _, values in series for point in values if point[0] > 0 and point[1] >= 0]
    if not points:
        raise ValueError(f"no points for {title}")
    transform_x = (lambda value: math.log10(value)) if log_x else (lambda value: value)
    transform_y = (lambda value: math.log10(max(value, 1e-30))) if log_y else (lambda value: value)
    xs, ys = [transform_x(point[0]) for point in points], [transform_y(point[1]) for point in points]
    xmin, xmax, ymin, ymax = min(xs), max(xs), min(ys), max(ys)
    if xmax == xmin:
        xmax += 1
    if ymax == ymin:
        ymax += 1

    def project(point: tuple[float, float]) -> tuple[float, float]:
        x = left + (transform_x(point[0]) - xmin) / (xmax - xmin) * (width - left - right)
        y = top + (ymax - transform_y(point[1])) / (ymax - ymin) * (height - top - bottom)
        return x, y

    elements = [
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}">',
        '<rect width="100%" height="100%" fill="#111315"/>',
        f'<text x="{width/2}" y="30" text-anchor="middle" fill="#eef2f1" font-family="sans-serif" font-size="20">{html.escape(title)}</text>',
        f'<line x1="{left}" y1="{height-bottom}" x2="{width-right}" y2="{height-bottom}" stroke="#9eaaa5"/>',
        f'<line x1="{left}" y1="{top}" x2="{left}" y2="{height-bottom}" stroke="#9eaaa5"/>',
        f'<text x="{width/2}" y="{height-18}" text-anchor="middle" fill="#eef2f1" font-family="sans-serif">{html.escape(x_label)}</text>',
        f'<text x="20" y="{height/2}" text-anchor="middle" transform="rotate(-90 20 {height/2})" fill="#eef2f1" font-family="sans-serif">{html.escape(y_label)}</text>',
    ]
    for index, (label, values) in enumerate(series):
        color = colors[index % len(colors)]
        sorted_values = sorted(values)
        projected = [project(point) for point in sorted_values]
        elements.append(f'<polyline points="{" ".join(f"{x:.2f},{y:.2f}" for x, y in projected)}" fill="none" stroke="{color}" stroke-width="2"/>')
        errors = dict(error_series.get(label, [])) if error_series else {}
        for point, (x, y) in zip(sorted_values, projected, strict=True):
            if point[0] in errors:
                low, high = max(point[1] - errors[point[0]], 1e-30 if log_y else ymin), point[1] + errors[point[0]]
                _, y_low = project((point[0], low))
                _, y_high = project((point[0], high))
                elements.append(f'<line x1="{x:.2f}" y1="{y_low:.2f}" x2="{x:.2f}" y2="{y_high:.2f}" stroke="{color}"/>')
            elements.append(f'<circle cx="{x:.2f}" cy="{y:.2f}" r="3" fill="{color}"/>')
        elements.append(f'<text x="{left+8}" y="{top + 18 * index}" fill="{color}" font-family="sans-serif" font-size="12">{html.escape(label)}</text>')
    elements.append("</svg>")
    path.write_text("\n".join(elements) + "\n", encoding="utf-8")


def trajectory_separation(base_path: Path, perturbed_path: Path) -> list[dict[str, float]]:
    rows = []
    for index, (base, perturbed) in enumerate(zip(read_jsonl(base_path), read_jsonl(perturbed_path), strict=True)):
        if base.get("step") != perturbed.get("step") or base.get("time") != perturbed.get("time"):
            raise ValueError(f"trajectory frames differ at index {index}")
        left = {body["id"]: body for body in base["bodies"]}
        right = {body["id"]: body for body in perturbed["bodies"]}
        if left.keys() != right.keys():
            raise ValueError("trajectory body IDs differ")
        distances = [math.hypot(left[key]["position"]["x"] - right[key]["position"]["x"], left[key]["position"]["y"] - right[key]["position"]["y"]) for key in left]
        rows.append({"time": float(base["time"]), "mean": sum(distances) / len(distances), "max": max(distances)})
    return rows


def orbit_row(name: str, trajectory: Path, diagnostics: Path) -> dict[str, float | str]:
    frames, metrics = list(read_jsonl(trajectory)), list(read_jsonl(diagnostics))
    if len(frames) != len(metrics):
        raise ValueError(f"{name}: frame and diagnostics counts differ")
    initial, final = frames[0], frames[-1]
    a0 = next(body for body in initial["bodies"] if body["id"] == "a")
    a1 = next(body for body in final["bodies"] if body["id"] == "a")
    position_error = math.hypot(a1["position"]["x"] - a0["position"]["x"], a1["position"]["y"] - a0["position"]["y"])
    initial_energy = float(metrics[0]["total_energy"])
    energy_drifts = [abs(float(metric["total_energy"]) - initial_energy) for metric in metrics]
    initial_momentum = metrics[0]["momentum"]
    momentum_drifts = [math.hypot(metric["momentum"]["x"] - initial_momentum["x"], metric["momentum"]["y"] - initial_momentum["y"]) for metric in metrics]
    energy_scale = max(abs(initial_energy), 1e-30)
    return {
        "case": name, "steps": len(frames) - 1, "position_error": position_error,
        "final_energy_drift": energy_drifts[-1], "max_energy_drift": max(energy_drifts),
        "final_relative_energy_drift": energy_drifts[-1] / energy_scale,
        "max_relative_energy_drift": max(energy_drifts) / energy_scale,
        "final_momentum_drift_norm": momentum_drifts[-1], "max_momentum_drift_norm": max(momentum_drifts),
    }


def write_rows(path: Path, rows: list[dict]) -> None:
    if not rows:
        raise ValueError(f"refusing to write empty table: {path}")
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(rows[0]))
        writer.writeheader()
        writer.writerows(rows)


def normalized_number(text: str) -> str:
    return format(float(text), "g") if text else ""


def expected_performance_keys(manifest: dict) -> set[tuple[int, str, str]]:
    matrix = manifest["matrices"]["performance"]
    keys = {(int(count), "brute_force", "") for count in matrix["counts"]}
    keys.update((int(count), "barnes_hut", format(float(theta), "g")) for count in matrix["counts"] for theta in matrix["thetas"])
    return keys


def expected_accuracy_keys(manifest: dict) -> set[tuple[int, str]]:
    matrix = manifest["matrices"]["force_accuracy"]
    return {(int(count), format(float(theta), "g")) for count in matrix["counts"] for theta in matrix["thetas"]}


def validate_inputs(root: Path, manifest: dict, performance: list[dict[str, str]], accuracy: list[dict[str, str]]) -> None:
    if manifest.get("git_dirty"):
        raise ValueError("manifest records a dirty Git worktree")
    performance_keys = {(int(row["body_count"]), row["solver"], normalized_number(row["theta"])) for row in performance}
    accuracy_keys = {(int(row["body_count"]), normalized_number(row["theta"])) for row in accuracy}
    if performance_keys != expected_performance_keys(manifest):
        raise ValueError("performance summary does not match the manifest matrix")
    if accuracy_keys != expected_accuracy_keys(manifest):
        raise ValueError("accuracy summary does not match the manifest matrix")
    if len(performance) != len(performance_keys) or len(accuracy) != len(accuracy_keys):
        raise ValueError("summary contains duplicate matrix rows")
    raw_performance = list(read_jsonl(root / "raw/performance.jsonl"))
    raw_accuracy = list(read_jsonl(root / "raw/accuracy.jsonl"))
    performance_matrix = manifest["matrices"]["performance"]
    expected_performance_records = len(performance_keys) * int(performance_matrix["samples"])
    if len(raw_performance) != expected_performance_records or len(raw_accuracy) != len(accuracy_keys):
        raise ValueError("raw record counts do not match the manifest matrix")
    if any(row.get("run_id") != manifest["run_id"] for row in raw_performance + raw_accuracy):
        raise ValueError("raw record provenance does not match manifest")
    for kind, rows in (("performance", performance), ("accuracy", accuracy)):
        for index, row in enumerate(rows, 2):
            context = f"{kind} row {index}"
            if row["run_id"] != manifest["run_id"] or row["target_label"] != manifest["target_label"] or row["opt_label"] != manifest["optimization"]:
                raise ValueError(f"{context}: provenance does not match manifest")
            for field, value in row.items():
                if field.endswith(("seconds", "mean", "error", "interactions", "visits")) and value:
                    finite_float(row, field, context)
    if any(int(row["sample_count"]) != int(performance_matrix["samples"]) for row in performance):
        raise ValueError("performance sample counts do not match the manifest matrix")
    expected_steps = dict(manifest["matrices"]["orbit_convergence"]["expected_steps"])
    for pair in manifest["matrices"]["trajectory_sensitivity"]["pairs"]:
        expected_steps[pair["base"]] = pair["steps"]
        expected_steps[pair["perturbed"]] = pair["steps"]
    for name, steps in expected_steps.items():
        frames = list(read_jsonl(root / f"trajectories/{name}.jsonl"))
        diagnostics = list(read_jsonl(root / f"trajectories/{name}-diagnostics.jsonl"))
        if len(frames) != int(steps) + 1 or len(diagnostics) != len(frames):
            raise ValueError(f"{name}: record counts do not match the manifest")


def performance_findings(performance: list[dict[str, str]], thetas: list[float]) -> tuple[list[str], list[str]]:
    findings, warnings = [], []
    brute = {int(row["body_count"]): float(row["elapsed_mean_seconds"]) for row in performance if row["solver"] == "brute_force"}
    for row in performance:
        mean, stddev = float(row["elapsed_mean_seconds"]), float(row["elapsed_stddev_seconds"])
        if mean > 0 and stddev / mean > 0.10:
            warnings.append(f"High timing variability ({stddev / mean:.1%}) for N={row['body_count']}, {row['solver']}, theta={row['theta'] or 'n/a'}.")
    for theta in thetas:
        rows = sorted((row for row in performance if row["solver"] == "barnes_hut" and normalized_number(row["theta"]) == format(theta, "g")), key=lambda row: int(row["body_count"]))
        faster = [int(row["body_count"]) for row in rows if float(row["elapsed_mean_seconds"]) < brute[int(row["body_count"])] ]
        findings.append(f"Barnes-Hut theta={theta:g} first outperformed brute force at N={min(faster)}." if faster else f"Barnes-Hut theta={theta:g} did not outperform brute force in the measured matrix.")
    return findings, warnings


def analyze(root: Path) -> None:
    manifest = json.loads((root / "manifest.json").read_text(encoding="utf-8"))
    summary, figures = root / "summary", root / "figures"
    figures.mkdir(exist_ok=True)
    performance = read_csv(summary / "performance.csv", PERFORMANCE_COLUMNS)
    accuracy = read_csv(summary / "accuracy.csv", ACCURACY_COLUMNS)
    validate_inputs(root, manifest, performance, accuracy)

    runtime_series, runtime_errors, speedup_series = [], {}, []
    configurations = [("brute_force", "")] + [("barnes_hut", format(theta, "g")) for theta in manifest["matrices"]["performance"]["thetas"]]
    for solver, theta in configurations:
        selected = [row for row in performance if row["solver"] == solver and normalized_number(row["theta"]) == theta]
        label = solver if not theta else f"{solver} theta={theta}"
        runtime_series.append((label, [(float(row["body_count"]), float(row["elapsed_mean_seconds"])) for row in selected]))
        runtime_errors[label] = [(float(row["body_count"]), float(row["elapsed_stddev_seconds"])) for row in selected]
        if solver == "barnes_hut":
            speedup_series.append((label, [(float(row["body_count"]), float(row["speedup_vs_brute_force"])) for row in selected]))
    svg_plot(figures / "runtime.svg", "Mean runtime by body count", "Bodies (log10)", "Seconds (log10)", runtime_series, True, True, runtime_errors)
    svg_plot(figures / "speedup.svg", "Barnes-Hut speedup", "Bodies (log10)", "Speedup", speedup_series, True)

    work_series, visit_series = [], []
    for theta in [format(value, "g") for value in manifest["matrices"]["performance"]["thetas"]]:
        selected = [row for row in performance if row["solver"] == "barnes_hut" and normalized_number(row["theta"]) == theta]
        work_series.extend([
            (f"direct theta={theta}", [(float(row["body_count"]), float(row["direct_interactions_mean"])) for row in selected]),
            (f"approximated theta={theta}", [(float(row["body_count"]), float(row["approximated_interactions_mean"])) for row in selected]),
        ])
        visit_series.append((f"theta={theta}", [(float(row["body_count"]), float(row["tree_node_visits_mean"])) for row in selected]))
    svg_plot(figures / "solver-work.svg", "Barnes-Hut force contributions", "Bodies (log10)", "Contributions (log10)", work_series, True, True)
    svg_plot(figures / "tree-node-visits.svg", "Barnes-Hut tree traversal", "Bodies (log10)", "Node visits (log10)", visit_series, True, True)

    accuracy_series = []
    for count in sorted({row["body_count"] for row in accuracy}, key=int):
        selected = [row for row in accuracy if row["body_count"] == count and float(row["theta"]) > 0]
        accuracy_series.append((f"N={count}", [(float(row["theta"]), float(row["normalized_l2_acceleration_error"])) for row in selected]))
    svg_plot(figures / "force-accuracy.svg", "Barnes-Hut acceleration error", "Theta", "Normalized L2 error (log10)", accuracy_series, False, True)

    trajectory_dir = root / "trajectories"
    orbit_names = manifest["matrices"]["orbit_convergence"]["cases"]
    orbit_rows = [orbit_row(name, trajectory_dir / f"{name}.jsonl", trajectory_dir / f"{name}-diagnostics.jsonl") for name in orbit_names]
    write_rows(summary / "orbit-convergence.csv", orbit_rows)
    svg_plot(figures / "orbit-position-error.svg", "Semi-implicit Euler orbit convergence", "Steps per orbit (log10)", "Position error (log10)", [("position error", [(float(row["steps"]), float(row["position_error"])) for row in orbit_rows])], True, True)
    svg_plot(figures / "orbit-energy-drift.svg", "Semi-implicit Euler energy conservation", "Steps per orbit (log10)", "Maximum relative energy drift (log10)", [("energy drift", [(float(row["steps"]), float(row["max_relative_energy_drift"])) for row in orbit_rows])], True, True)
    svg_plot(figures / "orbit-momentum-drift.svg", "Semi-implicit Euler momentum conservation", "Steps per orbit (log10)", "Maximum momentum drift norm (log10)", [("momentum drift", [(float(row["steps"]), float(row["max_momentum_drift_norm"])) for row in orbit_rows])], True, True)

    sensitivity_rows, sensitivity_series = [], []
    for pair in manifest["matrices"]["trajectory_sensitivity"]["pairs"]:
        rows = trajectory_separation(trajectory_dir / f"{pair['base']}.jsonl", trajectory_dir / f"{pair['perturbed']}.jsonl")
        delta_time = format(float(pair["delta_time"]), "g")
        sensitivity_rows.extend({"delta_time": delta_time, **row} for row in rows)
        sensitivity_series.append((f"dt={delta_time}", [(row["time"], row["mean"]) for row in rows if row["time"] > 0]))
    write_rows(summary / "trajectory-separation.csv", sensitivity_rows)
    svg_plot(figures / "trajectory-separation.svg", "Perturbed Burrau trajectory separation", "Simulation time", "Mean separation (log10)", sensitivity_series, False, True)

    findings, warnings = performance_findings(performance, manifest["matrices"]["performance"]["thetas"])
    tolerance = float(manifest["matrices"]["force_accuracy"]["exact_control_tolerance"])
    maximum_exact = max(float(row["normalized_l2_acceleration_error"]) for row in accuracy if float(row["theta"]) == 0)
    findings.append(f"Theta-zero maximum normalized L2 acceleration error was {maximum_exact:.6g} (tolerance {tolerance:.1e}).")
    if maximum_exact > tolerance:
        warnings.append("Theta-zero acceleration error exceeded the declared exact-control tolerance.")
    ordered_orbits = sorted(orbit_rows, key=lambda row: int(row["steps"]))
    for field, label in (("position_error", "orbital position error"), ("max_relative_energy_drift", "maximum relative energy drift")):
        values = [float(row[field]) for row in ordered_orbits]
        if any(right >= left for left, right in zip(values, values[1:])):
            warnings.append(f"{label.capitalize()} did not strictly decrease under timestep refinement.")
        else:
            findings.append(f"{label.capitalize()} decreased at every timestep refinement.")
    findings.append(f"Maximum observed momentum-drift norm across orbit runs was {max(float(row['max_momentum_drift_norm']) for row in orbit_rows):.6g}.")

    report = [
        f"# Sanxing Experiment Report — {manifest['run_id']}", "", "## Key findings", "",
        *[f"- {finding}" for finding in findings], "", "## Warnings", "",
        *([f"- {warning}" for warning in warnings] if warnings else ["- No automated evidence warnings were triggered."]),
        "", "## Generated evidence", "",
        "- Runtime with standard-deviation error bars and speedup are in `figures/runtime.svg` and `figures/speedup.svg`.",
        "- Direct/approximated work and traversal counts are in `figures/solver-work.svg` and `figures/tree-node-visits.svg`.",
        "- Force approximation error is in `summary/accuracy.csv` and `figures/force-accuracy.svg`.",
        "- Orbit convergence and conservation are in `summary/orbit-convergence.csv` and the three orbit figures.",
        "- Perturbed trajectory separation is in `summary/trajectory-separation.csv` and its figure.", "",
        "Timing covers the solver/integrator benchmark path, not complete application runtime. Force error compares accelerations on identical snapshots before integration. The Burrau result reports observed softened-system sensitivity and timestep dependence, not an exact reference trajectory.",
    ]
    (root / "report.md").write_text("\n".join(report) + "\n", encoding="utf-8")


def artifact_digest(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def complete_bundle(root: Path) -> None:
    manifest_path = root / "manifest.json"
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    performance = read_csv(root / "summary/performance.csv", PERFORMANCE_COLUMNS)
    accuracy = read_csv(root / "summary/accuracy.csv", ACCURACY_COLUMNS)
    validate_inputs(root, manifest, performance, accuracy)
    expected = [
        root / "raw/performance.jsonl", root / "raw/accuracy.jsonl",
        root / "summary/performance.csv", root / "summary/accuracy.csv",
        root / "summary/orbit-convergence.csv", root / "summary/trajectory-separation.csv", root / "report.md",
    ]
    expected.extend(root / f"trajectories/{name}{suffix}" for name in TRAJECTORY_CASES for suffix in (".jsonl", "-diagnostics.jsonl"))
    expected.extend(root / f"figures/{name}.svg" for name in (
        "runtime", "speedup", "solver-work", "tree-node-visits", "force-accuracy",
        "orbit-position-error", "orbit-energy-drift", "orbit-momentum-drift", "trajectory-separation",
    ))
    missing = [str(path.relative_to(root)) for path in expected if not path.is_file() or path.stat().st_size == 0]
    if missing:
        raise ValueError(f"bundle is incomplete: {', '.join(missing)}")
    manifest["status"] = "complete"
    manifest["completed_utc"] = dt.datetime.now(dt.timezone.utc).isoformat()
    manifest["artifacts"] = {
        str(path.relative_to(root)): {"bytes": path.stat().st_size, "sha256": artifact_digest(path)}
        for path in sorted(expected)
    }
    manifest_path.write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def main() -> int:
    usage = "usage: analyze_experiments.py manifest <path> <run-id> <target-label> | analyze <results-dir> | complete <results-dir>"
    try:
        if len(sys.argv) == 5 and sys.argv[1] == "manifest":
            write_manifest(Path(sys.argv[2]), sys.argv[3], sys.argv[4])
            return 0
        if len(sys.argv) == 3 and sys.argv[1] == "analyze":
            analyze(Path(sys.argv[2]))
            return 0
        if len(sys.argv) == 3 and sys.argv[1] == "complete":
            complete_bundle(Path(sys.argv[2]))
            return 0
    except (KeyError, OSError, StopIteration, TypeError, ValueError) as exc:
        print(f"experiment analysis failed: {exc}", file=sys.stderr)
        return 1
    print(usage, file=sys.stderr)
    return 2


if __name__ == "__main__":
    raise SystemExit(main())
