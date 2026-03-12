import json
import subprocess
import time
import unittest
from urllib.request import Request, urlopen


BASE = "http://127.0.0.1:8010"


def post(path, payload):
    req = Request(
        f"{BASE}{path}",
        data=json.dumps(payload).encode(),
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    with urlopen(req, timeout=5) as res:
        return json.loads(res.read().decode())


def get(path):
    with urlopen(f"{BASE}{path}", timeout=5) as res:
        return json.loads(res.read().decode())


class TestApp(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.proc = subprocess.Popen(["python", "-m", "src.main"], cwd=".", env={**__import__("os").environ, "PORT": "8010"})
        time.sleep(1.5)

    @classmethod
    def tearDownClass(cls):
        cls.proc.terminate()
        cls.proc.wait(timeout=5)

    def test_scanner(self):
        out = post("/api/scanner", {"min_rel_volume": 1.5, "min_perf_20d": 8, "min_rel_strength": 80, "require_bullish_ma_stack": True})
        self.assertGreaterEqual(out["count"], 1)

    def test_risk(self):
        out = post("/api/risk/position-size", {"equity": 50000, "risk_pct": 1, "entry_price": 100, "stop_price": 95})
        self.assertEqual(out["quantity"], 100.0)

    def test_trade_and_analytics(self):
        created = post("/api/trades", {"symbol": "NVDA", "setup_tag": "breakout", "entry_price": 100, "stop_price": 95, "target_price": 110, "quantity": 10})
        trade_id = created["id"]
        close = post(f"/api/trades/{trade_id}/close", {"exit_price": 108})
        self.assertIn("pnl", close)
        a = get("/api/analytics/summary")
        self.assertGreaterEqual(a["total_closed"], 1)


if __name__ == "__main__":
    unittest.main()
