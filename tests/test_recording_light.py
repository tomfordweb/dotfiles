"""Exercise restore safety without changing physical monitors."""

import importlib.machinery
import importlib.util
import contextlib
import fcntl
import io
from pathlib import Path
import tempfile
import threading
import unittest
from unittest.mock import patch


loader = importlib.machinery.SourceFileLoader("recording_light", str(Path(__file__).parents[1] / "bin/recording-light"))
spec = importlib.util.spec_from_loader(loader.name, loader)
light = importlib.util.module_from_spec(spec)
loader.exec_module(light)


class RecordingLightTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.state_patch = patch.object(light, "STATE_FILE", Path(self.temp.name) / "state.json")
        self.state_patch.start()
        self.addCleanup(self.state_patch.stop)
        self.dir_patch = patch.object(light, "STATE_DIR", Path(self.temp.name))
        self.dir_patch.start()
        self.addCleanup(self.dir_patch.stop)

    def test_dry_run_never_writes_or_saves(self):
        state = light.load_state()
        with patch.object(light, "displays", return_value={"A": 1}), patch.object(light, "brightness", return_value=(70, 100)), patch.object(light, "ddc") as ddc:
            light.apply(state, "on", 20, dry_run=True)
        ddc.assert_not_called()
        self.assertFalse(light.STATE_FILE.exists())

    def test_snapshot_precedes_write_and_dim_never_brightens(self):
        state = light.load_state()
        def write(*args):
            self.assertEqual(light.load_state()["originals"], {"A": 70, "B": 10})
        with patch.object(light, "displays", return_value={"A": 1, "B": 2}), patch.object(light, "brightness", side_effect=[(70, 100), (10, 100)]), patch.object(light, "ddc", side_effect=write) as ddc:
            light.apply(state, "on", 20)
        self.assertEqual([call.args[-1] for call in ddc.call_args_list], [20, 10])

    def test_read_failure_changes_nothing(self):
        with patch.object(light, "displays", return_value={"A": 1, "B": 2}), patch.object(light, "brightness", side_effect=[(70, 100), RuntimeError("unavailable")]), patch.object(light, "ddc") as ddc:
            with self.assertRaises(RuntimeError):
                light.apply(light.load_state(), "on", 20)
        ddc.assert_not_called()
        self.assertFalse(light.STATE_FILE.exists())

    def test_failed_dim_keeps_all_restore_values(self):
        with patch.object(light, "displays", return_value={"A": 1, "B": 2}), patch.object(light, "brightness", side_effect=[(70, 100), (68, 100)]), patch.object(light, "ddc", side_effect=["", RuntimeError("timeout")]):
            with self.assertRaises(RuntimeError):
                light.apply(light.load_state(), "on", 20)
        self.assertEqual(light.load_state()["originals"], {"A": 70, "B": 68})

    def test_restore_tracks_identity_after_bus_change_and_retains_missing(self):
        state = {"originals": {"A": 70, "B": 68}, "error": ""}
        light.save_state(state)
        with patch.object(light, "displays", return_value={"A": 9}), patch.object(light, "ddc") as ddc:
            with self.assertRaisesRegex(RuntimeError, "Restore pending"):
                light.apply(state, "off", 20)
        ddc.assert_called_once_with("--bus", 9, "setvcp", "10", 70)
        self.assertEqual(light.load_state()["originals"], {"B": 68})
        with patch.object(light, "displays", return_value={"B": 12}), patch.object(light, "ddc") as ddc:
            light.apply(state, "off", 20)
        ddc.assert_called_once_with("--bus", 12, "setvcp", "10", 68)
        self.assertEqual(light.load_state()["originals"], {})

    def test_repeated_on_preserves_originals(self):
        state = {"originals": {"A": 70}, "error": ""}
        with patch.object(light, "displays") as detect:
            light.apply(state, "on", 20)
        detect.assert_not_called()
        self.assertEqual(state["originals"], {"A": 70})

    def test_invalid_display_is_excluded_and_duplicate_identity_rejected(self):
        text = "Invalid display\n   I2C bus: /dev/i2c-8\n   Monitor: Broken\nDisplay 1\n   I2C bus: /dev/i2c-9\n   Monitor: Good\n"
        with patch.object(light, "ddc", return_value=text):
            self.assertEqual(light.displays(), {"Good": 9})
        with patch.object(light, "ddc", return_value=text + "Display 2\n   I2C bus: /dev/i2c-10\n   Monitor: Good\n"):
            with self.assertRaisesRegex(RuntimeError, "duplicate"):
                light.displays()

    def test_other_display_blocks_do_not_reuse_valid_display(self):
        for header in ("Phantom display", "Removed display", "DDC disabled", "Unknown display"):
            with self.subTest(header=header):
                text = ("Display 1\n   I2C bus: /dev/i2c-9\n   Monitor: Good\n"
                        + header + "\n   I2C bus: /dev/i2c-10\n   Monitor: Good\n"
                        + "Display 2\n   I2C bus: /dev/i2c-11\n   Monitor: Second\n")
                with patch.object(light, "ddc", return_value=text):
                    self.assertEqual(light.displays(), {"Good": 9, "Second": 11})

    def test_status_can_share_another_readers_lock(self):
        with (light.STATE_DIR / "lock").open("a") as lock:
            fcntl.flock(lock, fcntl.LOCK_SH)
            with patch("sys.argv", ["recording-light", "status"]), contextlib.redirect_stdout(io.StringIO()) as output:
                self.assertEqual(light.main(), 0)
            self.assertIn('"busy": false', output.getvalue())

    def test_toggle_waits_for_poll_to_release_lock(self):
        with (light.STATE_DIR / "lock").open("a") as lock:
            fcntl.flock(lock, fcntl.LOCK_SH)
            release = threading.Timer(0.1, fcntl.flock, args=(lock, fcntl.LOCK_UN))
            release.start()
            try:
                with patch("sys.argv", ["recording-light", "toggle", "--dry-run"]), patch.object(light, "apply") as apply:
                    self.assertEqual(light.main(), 0)
                apply.assert_called_once()
            finally:
                release.join()

    def test_busy_writer_reports_status_and_notifies_toggle(self):
        with (light.STATE_DIR / "lock").open("a") as lock:
            fcntl.flock(lock, fcntl.LOCK_EX)
            with patch("sys.argv", ["recording-light", "waybar"]), contextlib.redirect_stdout(io.StringIO()) as output:
                self.assertEqual(light.main(), 0)
            self.assertIn('"class": "busy"', output.getvalue())
            with patch("sys.argv", ["recording-light", "toggle"]), patch.object(light, "notify") as notify, patch.object(light.time, "monotonic", side_effect=[0, 3]), patch.object(light, "apply") as apply, contextlib.redirect_stderr(io.StringIO()):
                self.assertEqual(light.main(), 1)
            notify.assert_called_once()
            apply.assert_not_called()


if __name__ == "__main__":
    unittest.main()
