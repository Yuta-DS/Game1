#!/usr/bin/env python3
"""Protect the player-facing Web loader finish contract."""

from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[1]
SHELL = ROOT / "web_export_shell.html"


class WebExportShellTests(unittest.TestCase):
	def test_success_removes_diagnostic_immediately(self) -> None:
		html = SHELL.read_text(encoding="utf-8")
		start = html.index("}).then(() => {")
		failure = html.index("}, (err) => {", start)
		success = html[start:failure]
		self.assertIn("say('engine started');", success)
		self.assertIn("diag.remove();", success)
		self.assertNotIn("setTimeout(() => diag.remove()", html)

	def test_loading_progress_and_failures_remain_visible(self) -> None:
		html = SHELL.read_text(encoding="utf-8")
		self.assertIn("say('loading ' + pct + '%  ('", html)
		self.assertIn("say('START FAILED: ' + err);", html)
		self.assertIn("displayFailureNotice(err);", html)


if __name__ == "__main__":
	unittest.main()
