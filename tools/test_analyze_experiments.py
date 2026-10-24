#!/usr/bin/env python3
"""Tests for the standard-library experiment analyzer."""

from __future__ import annotations

import csv
import json
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
import analyze_experiments as analyzer


class AnalyzerTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory()
        self.root = Path(self.temporary.name)

    def tearDown(self) -> None:
        self.temporary.cleanup()

    def write_csv(self, path: Path, rows: list[dict[str, object]]) -> None:
        path.parent.mkdir(parents=True, exist_ok=True)
        with path.open("w", newline="", encoding="utf-8") as handle:
            writer = csv.DictWriter(handle, fieldnames=list(rows[0]))
            writer.writeheader()
            writer.writerows(rows)

    def create_bundle(self) -> None:
        for directory in ("raw", "summary", "trajectories", "figures"):
            (self.root / directory).mkdir()
        manifest = {
            "schema_version": 2,
            "run_id": "test-run",
            "status": "running",
            "git_dirty": False,
            "target_label": "test-target",
            "optimization": "speed",
            "matrices": {
                "performance": {"counts": [2], "thetas": [0.5], "samples": 1},
                "force_accuracy": {"counts": [2], "thetas": [0, 0.5], "exact_control_tolerance": 1e-12},
                "orbit_convergence": {"cases": analyzer.ORBIT_CASES, "expected_steps": {name: 1 for name in analyzer.ORBIT_CASES}},
                "trajectory_sensitivity": {"pairs": [
                    {"delta_time": 0.001, "steps": 1, "base": "burrau_base_001", "perturbed": "burrau_perturbed_001"},
                    {"delta_time": 0.0005, "steps": 1, "base": "burrau_base_0005", "perturbed": "burrau_perturbed_0005"},
                ]},
            },
        }
        (self.root / "manifest.json").write_text(json.dumps(manifest), encoding="utf-8")
        common = {"run_id": "test-run", "target_label": "test-target", "opt_label": "speed"}
        performance = [
            {**common, "body_count": 2, "solver": "brute_force", "theta": "", "sample_count": 1,
             "elapsed_mean_seconds": 2, "elapsed_stddev_seconds": 0.1, "direct_interactions_mean": 2,
             "approximated_interactions_mean": 0, "tree_node_visits_mean": 0, "speedup_vs_brute_force": 1},
            {**common, "body_count": 2, "solver": "barnes_hut", "theta": 0.5, "sample_count": 1,
             "elapsed_mean_seconds": 1, "elapsed_stddev_seconds": 0.2, "direct_interactions_mean": 1,
             "approximated_interactions_mean": 1, "tree_node_visits_mean": 3, "speedup_vs_brute_force": 2},
        ]
        accuracy = [
            {**common, "body_count": 2, "theta": theta, "normalized_l2_acceleration_error": error,
             "mean_absolute_acceleration_error": error, "max_absolute_acceleration_error": error,
             "direct_interactions": 2, "approximated_interactions": 0, "tree_node_visits": 3}
            for theta, error in ((0, 0), (0.5, 0.01))
        ]
        self.write_csv(self.root / "summary/performance.csv", performance)
        self.write_csv(self.root / "summary/accuracy.csv", accuracy)
        (self.root / "raw/performance.jsonl").write_text('{"record_type":"benchmark","run_id":"test-run"}\n' * 2, encoding="utf-8")
        (self.root / "raw/accuracy.jsonl").write_text('{"record_type":"solver_accuracy","run_id":"test-run"}\n' * 2, encoding="utf-8")

        initial = {"step": 0, "time": 0.0, "bodies": [
            {"id": "a", "position": {"x": 0.0, "y": 0.0}},
            {"id": "b", "position": {"x": 1.0, "y": 0.0}},
        ]}
        final = {"step": 1, "time": 1.0, "bodies": [
            {"id": "a", "position": {"x": 0.1, "y": 0.0}},
            {"id": "b", "position": {"x": 0.9, "y": 0.0}},
        ]}
        diagnostics = [
            {"step": 0, "time": 0.0, "total_energy": -1.0, "momentum": {"x": 0.0, "y": 0.0}},
            {"step": 1, "time": 1.0, "total_energy": -0.99, "momentum": {"x": 1e-15, "y": 0.0}},
        ]
        for name in analyzer.TRAJECTORY_CASES:
            frames = [initial, final]
            if "perturbed" in name:
                frames = [initial, {**final, "bodies": [
                    {"id": "a", "position": {"x": 0.1001, "y": 0.0}},
                    {"id": "b", "position": {"x": 0.9, "y": 0.0}},
                ]}]
            (self.root / f"trajectories/{name}.jsonl").write_text("".join(json.dumps(row) + "\n" for row in frames), encoding="utf-8")
            (self.root / f"trajectories/{name}-diagnostics.jsonl").write_text("".join(json.dumps(row) + "\n" for row in diagnostics), encoding="utf-8")

    def test_manifest_records_all_matrices_and_exact_commands(self) -> None:
        path = self.root / "manifest.json"
        analyzer.write_manifest(path, "run-1", "target-1")
        manifest = json.loads(path.read_text(encoding="utf-8"))
        self.assertEqual(manifest["schema_version"], 2)
        self.assertEqual(set(manifest["matrices"]), {"performance", "force_accuracy", "orbit_convergence", "trajectory_sensitivity"})
        self.assertEqual(len(manifest["commands"]), 2 + len(analyzer.TRAJECTORY_CASES))
        self.assertIn("argv", manifest["commands"][0])

    def test_analyze_and_complete_bundle(self) -> None:
        self.create_bundle()
        analyzer.analyze(self.root)
        analyzer.complete_bundle(self.root)
        manifest = json.loads((self.root / "manifest.json").read_text(encoding="utf-8"))
        self.assertEqual(manifest["status"], "complete")
        self.assertIn("figures/solver-work.svg", manifest["artifacts"])
        report = (self.root / "report.md").read_text(encoding="utf-8")
        self.assertIn("Theta-zero maximum", report)
        self.assertIn("High timing variability", report)

    def test_missing_matrix_row_is_rejected(self) -> None:
        self.create_bundle()
        rows = analyzer.read_csv(self.root / "summary/accuracy.csv")[:-1]
        self.write_csv(self.root / "summary/accuracy.csv", rows)
        with self.assertRaisesRegex(ValueError, "does not match"):
            analyzer.analyze(self.root)

    def test_trajectory_alignment_is_required(self) -> None:
        base = self.root / "base.jsonl"
        perturbed = self.root / "perturbed.jsonl"
        frame = {"step": 0, "time": 0, "bodies": [{"id": "a", "position": {"x": 0, "y": 0}}]}
        base.write_text(json.dumps(frame) + "\n", encoding="utf-8")
        perturbed.write_text(json.dumps({**frame, "time": 1}) + "\n", encoding="utf-8")
        with self.assertRaisesRegex(ValueError, "frames differ"):
            analyzer.trajectory_separation(base, perturbed)


if __name__ == "__main__":
    unittest.main()
