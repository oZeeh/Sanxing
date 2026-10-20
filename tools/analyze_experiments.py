#!/usr/bin/env python3
"""Standard-library-only analysis for canonical Sanxing experiment bundles."""

from __future__ import annotations

import csv
import datetime as dt
import json
import math
import os
import platform
import subprocess
import sys
from pathlib import Path


def command_output(*args: str) -> str:
    try:
        return subprocess.check_output(args, text=True, stderr=subprocess.DEVNULL).strip()
    except (OSError, subprocess.CalledProcessError):
        return "unavailable"


def write_manifest(path: Path, run_id: str, target_label: str) -> None:
    manifest = {
        "schema_version": 1,
        "run_id": run_id,
        "created_utc": dt.datetime.now(dt.timezone.utc).isoformat(),
        "git_commit": command_output("git", "rev-parse", "HEAD"),
        "git_dirty": command_output("git", "status", "--porcelain") != "",
        "odin_version": command_output("odin", "version"),
        "platform": platform.platform(),
        "machine": platform.machine(),
        "processor": platform.processor() or command_output("sh", "-c", "grep -m1 'model name' /proc/cpuinfo"),
        "python_version": platform.python_version(),
        "target_label": target_label,
        "commands": [
            "odin run engine/src -o:speed -- benchmark <raw> --summary <csv> --solver both --thetas 0.25,0.5,1.0 --counts 100,500,1000,5000,10000 --steps 10 --samples 10 --warmups 2",
            "odin run engine/src -o:speed -- accuracy <raw> --summary <csv> --counts 100,500,1000,5000,10000 --thetas 0,0.25,0.5,1.0",
            "odin run engine/src -o:speed -- simulate <fixture> <frames> --diagnostics <metrics>",
        ],
        "performance_matrix": {
            "counts": [100, 500, 1000, 5000, 10000],
            "steps": 10,
            "samples": 10,
            "warmups": 2,
            "thetas": [0.25, 0.5, 1.0],
            "optimization": "speed",
        },
    }
    path.write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def read_csv(path: Path) -> list[dict[str, str]]:
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


def read_jsonl(path: Path):
    with path.open(encoding="utf-8") as handle:
        for line_number, line in enumerate(handle, 1):
            if line.strip():
                try:
                    yield json.loads(line)
                except json.JSONDecodeError as exc:
                    raise ValueError(f"{path}:{line_number}: {exc}") from exc


def svg_plot(path: Path, title: str, x_label: str, y_label: str, series: list[tuple[str, list[tuple[float, float]]]], log_x=False, log_y=False) -> None:
    width, height = 900, 520
    left, right, top, bottom = 90, 30, 55, 70
    colors = ["#42c6a4", "#f2b84b", "#7db7ff", "#ef6f6c", "#d39cff"]
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
    xs = [transform_x(point[0]) for point in points]
    ys = [transform_y(point[1]) for point in points]
    xmin, xmax = min(xs), max(xs)
    ymin, ymax = min(ys), max(ys)
    if xmax == xmin: xmax += 1
    if ymax == ymin: ymax += 1
    def project(point):
        x = left + (transform_x(point[0]) - xmin) / (xmax - xmin) * (width - left - right)
        y = top + (ymax - transform_y(point[1])) / (ymax - ymin) * (height - top - bottom)
        return x, y
    elements = [
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}">',
        '<rect width="100%" height="100%" fill="#111315"/>',
        f'<text x="{width/2}" y="30" text-anchor="middle" fill="#eef2f1" font-family="sans-serif" font-size="20">{title}</text>',
        f'<line x1="{left}" y1="{height-bottom}" x2="{width-right}" y2="{height-bottom}" stroke="#9eaaa5"/>',
        f'<line x1="{left}" y1="{top}" x2="{left}" y2="{height-bottom}" stroke="#9eaaa5"/>',
        f'<text x="{width/2}" y="{height-18}" text-anchor="middle" fill="#eef2f1" font-family="sans-serif">{x_label}</text>',
        f'<text x="20" y="{height/2}" text-anchor="middle" transform="rotate(-90 20 {height/2})" fill="#eef2f1" font-family="sans-serif">{y_label}</text>',
    ]
    for index, (label, values) in enumerate(series):
        color = colors[index % len(colors)]
        projected = [project(point) for point in sorted(values)]
        polyline = " ".join(f"{x:.2f},{y:.2f}" for x, y in projected)
        elements.append(f'<polyline points="{polyline}" fill="none" stroke="{color}" stroke-width="2"/>')
        for x, y in projected:
            elements.append(f'<circle cx="{x:.2f}" cy="{y:.2f}" r="3" fill="{color}"/>')
        legend_y = top + 18 * index
        elements.append(f'<text x="{left+8}" y="{legend_y}" fill="{color}" font-family="sans-serif" font-size="12">{label}</text>')
    elements.append("</svg>")
    path.write_text("\n".join(elements) + "\n", encoding="utf-8")


def trajectory_separation(base_path: Path, perturbed_path: Path) -> list[dict[str, float]]:
    rows = []
    for base, perturbed in zip(read_jsonl(base_path), read_jsonl(perturbed_path), strict=True):
        left = {body["id"]: body for body in base["bodies"]}
        right = {body["id"]: body for body in perturbed["bodies"]}
        if left.keys() != right.keys():
            raise ValueError("trajectory body IDs differ")
        distances = []
        for body_id in left:
            a, b = left[body_id]["position"], right[body_id]["position"]
            distances.append(math.hypot(a["x"] - b["x"], a["y"] - b["y"]))
        rows.append({"time": float(base["time"]), "mean": sum(distances) / len(distances), "max": max(distances)})
    return rows


def orbit_row(name: str, trajectory: Path, diagnostics: Path) -> dict[str, float | str]:
    frames = list(read_jsonl(trajectory))
    metrics = list(read_jsonl(diagnostics))
    initial, final = frames[0], frames[-1]
    a0 = next(body for body in initial["bodies"] if body["id"] == "a")
    a1 = next(body for body in final["bodies"] if body["id"] == "a")
    position_error = math.hypot(a1["position"]["x"] - a0["position"]["x"], a1["position"]["y"] - a0["position"]["y"])
    energy_error = abs(metrics[-1]["total_energy"] - metrics[0]["total_energy"])
    momentum = metrics[-1]["momentum"]
    return {"case": name, "steps": len(frames) - 1, "position_error": position_error, "energy_error": energy_error, "momentum_norm": math.hypot(momentum["x"], momentum["y"])}


def write_rows(path: Path, rows: list[dict]) -> None:
    if not rows:
        return
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(rows[0]))
        writer.writeheader()
        writer.writerows(rows)


def analyze(root: Path) -> None:
    summary = root / "summary"
    figures = root / "figures"
    figures.mkdir(exist_ok=True)
    performance = read_csv(summary / "performance.csv")
    accuracy = read_csv(summary / "accuracy.csv")

    runtime_series = []
    speedup_series = []
    for solver, theta in [("brute_force", ""), ("barnes_hut", "0.25"), ("barnes_hut", "0.5"), ("barnes_hut", "1")]:
        selected = [row for row in performance if row["solver"] == solver and row["theta"] == theta]
        label = solver if not theta else f"{solver} θ={theta}"
        runtime_series.append((label, [(float(row["body_count"]), float(row["elapsed_mean_seconds"])) for row in selected]))
        if solver == "barnes_hut":
            speedup_series.append((label, [(float(row["body_count"]), float(row["speedup_vs_brute_force"])) for row in selected]))
    svg_plot(figures / "runtime.svg", "Mean runtime by body count", "Bodies (log10)", "Seconds (log10)", runtime_series, True, True)
    svg_plot(figures / "speedup.svg", "Barnes–Hut speedup", "Bodies (log10)", "Speedup", speedup_series, True, False)

    accuracy_series = []
    for count in sorted({row["body_count"] for row in accuracy}, key=int):
        selected = [row for row in accuracy if row["body_count"] == count]
        accuracy_series.append((f"N={count}", [(float(row["theta"]), float(row["normalized_l2_acceleration_error"])) for row in selected if float(row["theta"]) > 0]))
    svg_plot(figures / "force-accuracy.svg", "Barnes–Hut acceleration error", "Theta", "Normalized L2 error (log10)", accuracy_series, False, True)

    trajectory_dir = root / "trajectories"
    orbit_rows = [orbit_row(name, trajectory_dir / f"{name}.jsonl", trajectory_dir / f"{name}-diagnostics.jsonl") for name in ("two_body_orbit_100", "two_body_orbit_200", "two_body_orbit_400")]
    write_rows(summary / "orbit-convergence.csv", orbit_rows)
    svg_plot(figures / "orbit-convergence.svg", "Semi-implicit Euler convergence", "Steps per orbit (log10)", "Position error (log10)", [("position error", [(float(row["steps"]), float(row["position_error"])) for row in orbit_rows])], True, True)

    sensitivity_rows = []
    sensitivity_series = []
    for label in ("001", "0005"):
        rows = trajectory_separation(trajectory_dir / f"burrau_base_{label}.jsonl", trajectory_dir / f"burrau_perturbed_{label}.jsonl")
        for row in rows:
            sensitivity_rows.append({"dt": "0.001" if label == "001" else "0.0005", **row})
        sensitivity_series.append((f"dt={'0.001' if label == '001' else '0.0005'}", [(row["time"], row["mean"]) for row in rows if row["time"] > 0]))
    write_rows(summary / "trajectory-separation.csv", sensitivity_rows)
    svg_plot(figures / "trajectory-separation.svg", "Perturbed Burrau trajectory separation", "Simulation time", "Mean separation (log10)", sensitivity_series, False, True)

    run_id = json.loads((root / "manifest.json").read_text(encoding="utf-8"))["run_id"]
    report = [
        f"# Sanxing Experiment Report — {run_id}", "",
        "## Generated evidence", "",
        "- Performance runtime, variability, speedup, and solver-work summaries are in `summary/performance.csv`.",
        "- Force approximation error is in `summary/accuracy.csv`.",
        "- Euler convergence and conservation diagnostics are in `summary/orbit-convergence.csv`.",
        "- Perturbed trajectory separation is in `summary/trajectory-separation.csv`.",
        "- Thesis-ready SVG figures are in `figures/`.", "",
        "The performance scenario is not used as a trajectory-accuracy claim. The Burrau result reports observed softened-system sensitivity and timestep dependence, not an exact reference trajectory.",
    ]
    (root / "report.md").write_text("\n".join(report) + "\n", encoding="utf-8")


def main() -> int:
    if len(sys.argv) < 2:
        print("usage: analyze_experiments.py manifest <path> <run-id> <target-label> | analyze <results-dir>", file=sys.stderr)
        return 2
    if sys.argv[1] == "manifest" and len(sys.argv) == 5:
        write_manifest(Path(sys.argv[2]), sys.argv[3], sys.argv[4])
        return 0
    if sys.argv[1] == "analyze" and len(sys.argv) == 3:
        analyze(Path(sys.argv[2]))
        return 0
    print("invalid arguments", file=sys.stderr)
    return 2


if __name__ == "__main__":
    raise SystemExit(main())
