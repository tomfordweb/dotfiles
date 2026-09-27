"""Exercise restore safety without changing physical monitors."""

import importlib.machinery
import importlib.util
from pathlib import Path
import tempfile
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


if __name__ == "__main__":
    unittest.main()
