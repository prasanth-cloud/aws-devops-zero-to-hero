# Swing Trading App (Functional MVP)

This deliverable is now a **runnable application** with:
- Smart stock scanner
- Risk/position sizing engine
- Watchlist management
- Trade journal (open/close trades)
- Performance analytics summary
- Lightweight web UI (dark mode) + JSON APIs

## Tech
- Python standard library server (`http.server`) + SQLite (no external dependencies)
- HTML/JS frontend served from the backend
- Docker deployment support

## Run locally

```bash
cd projects/swing-trading-app
python -m src.main
```

Open: `http://localhost:8000`

## Deploy with Docker

```bash
cd projects/swing-trading-app
docker compose up --build -d
```

Open: `http://localhost:8000`

## API Endpoints
- `POST /api/scanner`
- `POST /api/risk/position-size`
- `GET /api/watchlist`
- `POST /api/watchlist`
- `GET /api/trades`
- `POST /api/trades`
- `POST /api/trades/{trade_id}/close`
- `GET /api/analytics/summary`

## Functional validation
A runnable integration test exists and starts the app, calls scanner/risk/trade/analytics endpoints, and validates responses.

```bash
cd projects/swing-trading-app
python -m unittest tests/test_app.py -v
```

## Notes
- Seeded symbol snapshots are included for deterministic scanner behavior.
- Previous architecture references are preserved in:
  - `api-spec.yaml`
  - `schema.sql`
  - `user-flows.md`
