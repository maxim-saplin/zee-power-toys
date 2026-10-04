#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.10"
# dependencies = ["websockets>=12.0"]
# ///
"""Regression tests for tier-specific VM-service discovery."""

from __future__ import annotations

import unittest
from unittest.mock import AsyncMock, patch

import zee_drive


class ResolveWsUriTest(unittest.TestCase):
    def test_t1_missing_session_does_not_fall_back_to_other_tiers_or_adb(self) -> None:
        run_log = "/tmp/test-zee-run-t1.log"
        with (
            patch.object(zee_drive, "_read_session_file_uri", return_value=None) as read_session,
            patch.object(zee_drive, "_latest_tier_uri_file") as latest_session,
            patch.object(zee_drive, "_scan_flutter_run_log_for_vm_uri", return_value=None) as scan_log,
            patch.object(zee_drive, "_scan_logcat_for_vm_uri") as scan_logcat,
        ):
            with self.assertRaisesRegex(RuntimeError, "T1 desktop"):
                zee_drive.resolve_ws_uri(tier="t1", run_log=run_log)

        read_session.assert_called_once_with(zee_drive.vm_uri_file("t1"))
        latest_session.assert_not_called()
        scan_log.assert_called_once_with(run_log)
        scan_logcat.assert_not_called()

    def test_t2_keeps_logcat_and_port_forward_fallback(self) -> None:
        run_log = "/tmp/test-zee-run-t2.log"
        with (
            patch.object(zee_drive, "_read_session_file_uri", return_value=None) as read_session,
            patch.object(zee_drive, "_latest_tier_uri_file") as latest_session,
            patch.object(zee_drive, "_scan_flutter_run_log_for_vm_uri", return_value=None) as scan_log,
            patch.object(
                zee_drive,
                "_scan_logcat_for_vm_uri",
                return_value="http://10.0.2.2:43123/token=/",
            ) as scan_logcat,
            patch.object(zee_drive, "_forward_port", return_value=8181) as forward_port,
        ):
            uri = zee_drive.resolve_ws_uri(tier="t2", run_log=run_log)

        self.assertEqual(uri, "ws://127.0.0.1:8181/token=/ws")
        read_session.assert_called_once_with(zee_drive.vm_uri_file("t2"))
        latest_session.assert_not_called()
        scan_log.assert_called_once_with(run_log)
        scan_logcat.assert_called_once_with(zee_drive.DEFAULT_SERIAL)
        forward_port.assert_called_once_with(43123, serial=zee_drive.DEFAULT_SERIAL)

    def test_t1_ignores_stale_vm_uri_in_run_log(self) -> None:
        run_log = "/tmp/test-zee-run-t1.log"
        with (
            patch.object(zee_drive, "_read_session_file_uri", return_value=None),
            patch.object(zee_drive, "_latest_tier_uri_file") as latest_session,
            patch.object(
                zee_drive,
                "_scan_flutter_run_log_for_vm_uri",
                return_value="http://127.0.0.1:56401/token=/",
            ) as scan_log,
            patch.object(
                zee_drive,
                "_probe_uri_alive",
                new_callable=AsyncMock,
                return_value=False,
            ) as probe_uri,
            patch.object(zee_drive, "_scan_logcat_for_vm_uri") as scan_logcat,
        ):
            with self.assertRaisesRegex(RuntimeError, "T1 desktop"):
                zee_drive.resolve_ws_uri(tier="t1", run_log=run_log)

        latest_session.assert_not_called()
        scan_log.assert_called_once_with(run_log)
        probe_uri.assert_awaited_once_with("ws://127.0.0.1:56401/token=/ws")
        scan_logcat.assert_not_called()


if __name__ == "__main__":
    unittest.main()