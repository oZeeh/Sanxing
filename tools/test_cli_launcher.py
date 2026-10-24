#!/usr/bin/env python3
"""Integration tests for the repository-level Sanxing launcher."""

from __future__ import annotations

import os
import stat
import subprocess
import tempfile
import unittest
from pathlib import Path


REPOSITORY = Path(__file__).resolve().parents[1]
LAUNCHER = REPOSITORY / "sanxing"


class LauncherTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory()
        self.root = Path(self.temporary.name)
        self.bin = self.root / "bin"
        self.bin.mkdir()
        self.log = self.root / "odin.log"
        fake_odin = self.bin / "odin"
        fake_odin.write_text(
            "#!/usr/bin/env sh\n"
            "printf '%s\\n' \"$*\" >> \"$SANXING_TEST_LOG\"\n"
            "case \"$*\" in\n"
            "  *'/engine/src'*simulate*)\n"
            "    if [ \"${SANXING_FAKE_ENGINE_FAIL:-0}\" = 1 ]; then exit 7; fi\n"
            "    previous=\n"
            "    for argument in \"$@\"; do\n"
            "      if [ \"$previous\" = --output ]; then printf '{}\\n' > \"$argument\"; break; fi\n"
            "      previous=$argument\n"
            "    done\n"
            "    ;;\n"
            "esac\n",
            encoding="utf-8",
        )
        fake_odin.chmod(fake_odin.stat().st_mode | stat.S_IXUSR)
        self.environment = {
            **os.environ,
            "PATH": f"{self.bin}{os.pathsep}{os.environ['PATH']}",
            "SANXING_TEST_LOG": str(self.log),
        }

    def tearDown(self) -> None:
        self.temporary.cleanup()

    def run_launcher(self, *arguments: str, **environment: str) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            [str(LAUNCHER), *arguments],
            cwd=self.root,
            env={**self.environment, **environment},
            text=True,
            capture_output=True,
            check=False,
        )

    def invocations(self) -> list[str]:
        if not self.log.exists():
            return []
        return self.log.read_text(encoding="utf-8").splitlines()

    def test_help_does_not_invoke_odin(self) -> None:
        result = self.run_launcher("--help")
        self.assertEqual(result.returncode, 0)
        self.assertIn("./sanxing run", result.stdout)
        self.assertEqual(self.invocations(), [])

    def test_engine_commands_are_dispatched_from_another_directory(self) -> None:
        result = self.run_launcher("simulate", "input.json", "output.jsonl")
        self.assertEqual(result.returncode, 0)
        invocation = self.invocations()[0]
        self.assertIn(str(REPOSITORY / "engine/src"), invocation)
        self.assertIn("simulate input.json output.jsonl", invocation)

    def test_run_creates_replay_and_then_opens_viewer(self) -> None:
        result = self.run_launcher("run", "input.json")
        self.assertEqual(result.returncode, 0)
        invocations = self.invocations()
        self.assertEqual(len(invocations), 2)
        self.assertIn(str(REPOSITORY / "engine/src"), invocations[0])
        self.assertIn("simulate --input input.json --output /tmp/sanxing-replay.", invocations[0])
        self.assertIn(str(REPOSITORY / "viewers/local/src"), invocations[1])
        replay = Path(result.stdout.split("Replay output: ", 1)[1].splitlines()[0])
        self.assertTrue(replay.is_file())
        replay.unlink()

    def test_run_preserves_explicit_output_and_diagnostics(self) -> None:
        replay = self.root / "chosen.jsonl"
        diagnostics = self.root / "diagnostics.jsonl"
        result = self.run_launcher(
            "run", "--input", "input.json", "--output", str(replay),
            "--diagnostics", str(diagnostics),
        )
        self.assertEqual(result.returncode, 0)
        invocations = self.invocations()
        self.assertEqual(len(invocations), 2)
        self.assertIn(f"--output {replay}", invocations[0])
        self.assertIn(f"--diagnostics {diagnostics}", invocations[0])
        self.assertIn(str(replay), invocations[1])

    def test_run_does_not_open_viewer_after_simulation_failure(self) -> None:
        result = self.run_launcher("run", "input.json", SANXING_FAKE_ENGINE_FAIL="1")
        self.assertEqual(result.returncode, 7)
        self.assertEqual(len(self.invocations()), 1)


if __name__ == "__main__":
    unittest.main()
