import json
import os
import sqlite3
from datetime import datetime
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import parse_qs, urlparse

DB_PATH = Path(__file__).resolve().parent.parent / "swing_trading.db"
TEMPLATE_PATH = Path(__file__).resolve().parent / "templates" / "index.html"


def db_conn():
    return sqlite3.connect(DB_PATH)


def init_db():
    conn = db_conn()
    cur = conn.cursor()
    cur.execute(
        """
        CREATE TABLE IF NOT EXISTS symbols (
            symbol TEXT PRIMARY KEY,
            sector TEXT,
            price REAL,
            high_52w REAL,
            resistance REAL,
            rel_volume REAL,
            ma20 REAL,
            ma50 REAL,
            ma200 REAL,
            perf_5d REAL,
            perf_20d REAL,
            volatility_contraction INTEGER,
            rel_strength REAL,
            market_cap_b REAL
        )
        """
    )
    cur.execute(
        """
        CREATE TABLE IF NOT EXISTS watchlist (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            symbol TEXT,
            stage TEXT,
            note TEXT,
            created_at TEXT
        )
        """
    )
    cur.execute(
        """
        CREATE TABLE IF NOT EXISTS trades (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            symbol TEXT,
            setup_tag TEXT,
            entry_price REAL,
            stop_price REAL,
            target_price REAL,
            quantity REAL,
            status TEXT,
            emotion TEXT,
            notes TEXT,
            exit_price REAL,
            pnl REAL,
            r_multiple REAL,
            created_at TEXT
        )
        """
    )
    conn.commit()

    if cur.execute("SELECT COUNT(*) FROM symbols").fetchone()[0] == 0:
        rows = [
            ("NVDA", "Technology", 125.4, 126.0, 124.8, 2.4, 121.2, 114.3, 95.7, 6.2, 14.8, 1, 92, 3000),
            ("SMCI", "Technology", 92.3, 96.1, 91.8, 1.9, 88.0, 84.2, 71.9, 8.1, 17.3, 0, 87, 55),
            ("AAPL", "Technology", 201.1, 204.2, 199.4, 1.1, 198.2, 194.4, 183.0, 2.8, 5.9, 1, 70, 2900),
            ("LLY", "Healthcare", 890.0, 905.0, 875.0, 1.7, 870.0, 845.0, 760.0, 3.6, 10.2, 1, 84, 840),
            ("XOM", "Energy", 109.0, 123.7, 112.0, 0.9, 108.5, 110.1, 106.2, -1.2, -3.1, 0, 40, 450),
        ]
        cur.executemany("INSERT INTO symbols VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?)", rows)
        conn.commit()
    conn.close()


def json_response(handler, status, payload):
    data = json.dumps(payload).encode()
    handler.send_response(status)
    handler.send_header("Content-Type", "application/json")
    handler.send_header("Content-Length", str(len(data)))
    handler.end_headers()
    handler.wfile.write(data)


def read_json(handler):
    length = int(handler.headers.get("Content-Length", "0"))
    raw = handler.rfile.read(length) if length else b"{}"
    return json.loads(raw.decode() or "{}")


class AppHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        path = urlparse(self.path).path
        if path == "/":
            html = TEMPLATE_PATH.read_bytes()
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.send_header("Content-Length", str(len(html)))
            self.end_headers()
            self.wfile.write(html)
            return
        if path == "/api/watchlist":
            conn = db_conn()
            rows = conn.execute("SELECT id,symbol,stage,note FROM watchlist ORDER BY id DESC").fetchall()
            conn.close()
            return json_response(self, 200, [{"id": r[0], "symbol": r[1], "stage": r[2], "note": r[3]} for r in rows])
        if path == "/api/trades":
            conn = db_conn()
            rows = conn.execute(
                "SELECT id,symbol,setup_tag,status,entry_price,stop_price,target_price,quantity,exit_price,pnl,r_multiple FROM trades ORDER BY id DESC"
            ).fetchall()
            conn.close()
            return json_response(
                self,
                200,
                [
                    {
                        "id": r[0],
                        "symbol": r[1],
                        "setup_tag": r[2],
                        "status": r[3],
                        "entry_price": r[4],
                        "stop_price": r[5],
                        "target_price": r[6],
                        "quantity": r[7],
                        "exit_price": r[8],
                        "pnl": r[9],
                        "r_multiple": r[10],
                    }
                    for r in rows
                ],
            )
        if path == "/api/analytics/summary":
            conn = db_conn()
            rows = conn.execute("SELECT pnl, r_multiple FROM trades WHERE status='closed' ORDER BY id").fetchall()
            conn.close()
            if not rows:
                return json_response(self, 200, {"total_closed": 0, "win_rate": 0, "expectancy_r": 0, "avg_pnl": 0, "max_drawdown": 0})
            pnls = [r[0] or 0 for r in rows]
            rs = [r[1] or 0 for r in rows]
            win_rate = 100 * len([p for p in pnls if p > 0]) / len(pnls)
            avg_pnl = sum(pnls) / len(pnls)
            expectancy_r = sum(rs) / len(rs)
            eq = peak = max_dd = 0
            for p in pnls:
                eq += p
                peak = max(peak, eq)
                max_dd = max(max_dd, peak - eq)
            return json_response(
                self,
                200,
                {
                    "total_closed": len(rows),
                    "win_rate": round(win_rate, 2),
                    "expectancy_r": round(expectancy_r, 3),
                    "avg_pnl": round(avg_pnl, 2),
                    "max_drawdown": round(max_dd, 2),
                },
            )
        return json_response(self, 404, {"error": "Not found"})

    def do_POST(self):
        path = urlparse(self.path).path
        body = read_json(self)
        if path == "/api/scanner":
            conn = db_conn()
            rows = conn.execute("SELECT * FROM symbols").fetchall()
            conn.close()
            cols = ["symbol", "sector", "price", "high_52w", "resistance", "rel_volume", "ma20", "ma50", "ma200", "perf_5d", "perf_20d", "volatility_contraction", "rel_strength", "market_cap_b"]
            min_rvol = float(body.get("min_rel_volume", 1.0))
            min_perf20 = float(body.get("min_perf_20d", 0.0))
            min_rs = float(body.get("min_rel_strength", 0.0))
            ma_stack = bool(body.get("require_bullish_ma_stack", False))
            matched = []
            for r in rows:
                s = dict(zip(cols, r))
                if s["rel_volume"] < min_rvol or s["perf_20d"] < min_perf20 or s["rel_strength"] < min_rs:
                    continue
                if ma_stack and not (s["ma20"] > s["ma50"] > s["ma200"]):
                    continue
                score = round((s["rel_strength"] * 0.6) + (s["perf_20d"] * 2) + (s["rel_volume"] * 5), 2)
                matched.append({"symbol": s["symbol"], "sector": s["sector"], "price": s["price"], "score": score})
            matched.sort(key=lambda x: x["score"], reverse=True)
            return json_response(self, 200, {"count": len(matched), "matches": matched})

        if path == "/api/risk/position-size":
            equity = float(body.get("equity", 0))
            risk_pct = float(body.get("risk_pct", 0))
            entry = float(body.get("entry_price", 0))
            stop = float(body.get("stop_price", 0))
            dist = abs(entry - stop)
            if dist == 0:
                return json_response(self, 400, {"error": "Entry and stop must differ"})
            risk_amount = equity * (risk_pct / 100)
            qty = risk_amount / dist
            return json_response(self, 200, {"risk_amount": round(risk_amount, 2), "stop_distance": round(dist, 4), "quantity": round(qty, 2), "position_value": round(qty * entry, 2)})

        if path == "/api/watchlist":
            conn = db_conn()
            cur = conn.cursor()
            cur.execute(
                "INSERT INTO watchlist(symbol,stage,note,created_at) VALUES(?,?,?,?)",
                (str(body.get("symbol", "")).upper(), body.get("stage", "watch"), body.get("note", ""), datetime.utcnow().isoformat()),
            )
            conn.commit()
            item_id = cur.lastrowid
            conn.close()
            return json_response(self, 200, {"id": item_id})

        if path == "/api/trades":
            conn = db_conn()
            cur = conn.cursor()
            cur.execute(
                "INSERT INTO trades(symbol,setup_tag,entry_price,stop_price,target_price,quantity,status,emotion,notes,created_at) VALUES(?,?,?,?,?,?,?,?,?,?)",
                (
                    body.get("symbol", "").upper(),
                    body.get("setup_tag", "breakout"),
                    float(body.get("entry_price", 0)),
                    float(body.get("stop_price", 0)),
                    float(body.get("target_price", 0)),
                    float(body.get("quantity", 0)),
                    "open",
                    body.get("emotion", "calm"),
                    body.get("notes", ""),
                    datetime.utcnow().isoformat(),
                ),
            )
            conn.commit()
            trade_id = cur.lastrowid
            conn.close()
            return json_response(self, 200, {"id": trade_id, "status": "open"})

        if path.startswith("/api/trades/") and path.endswith("/close"):
            try:
                trade_id = int(path.split("/")[3])
            except Exception:
                return json_response(self, 400, {"error": "Invalid trade id"})
            exit_price = float(body.get("exit_price", 0))
            conn = db_conn()
            cur = conn.cursor()
            row = cur.execute("SELECT entry_price,stop_price,quantity,status FROM trades WHERE id=?", (trade_id,)).fetchone()
            if not row:
                conn.close()
                return json_response(self, 404, {"error": "Trade not found"})
            if row[3] != "open":
                conn.close()
                return json_response(self, 400, {"error": "Trade is not open"})
            entry, stop, qty, _ = row
            pnl = (exit_price - entry) * qty
            denom = (entry - stop) * qty
            r_mult = pnl / denom if denom != 0 else 0
            cur.execute("UPDATE trades SET status='closed', exit_price=?, pnl=?, r_multiple=? WHERE id=?", (exit_price, pnl, r_mult, trade_id))
            conn.commit()
            conn.close()
            return json_response(self, 200, {"id": trade_id, "pnl": round(pnl, 2), "r_multiple": round(r_mult, 2)})

        return json_response(self, 404, {"error": "Not found"})


def run(host="0.0.0.0", port=8000):
    init_db()
    server = ThreadingHTTPServer((host, port), AppHandler)
    print(f"Swing Trading App running on http://{host}:{port}")
    server.serve_forever()


if __name__ == "__main__":
    run(port=int(os.getenv("PORT", "8000")))
