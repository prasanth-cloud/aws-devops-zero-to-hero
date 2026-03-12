# Swing Trading App (Functional MVP)

This deliverable is a **runnable application** with:
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

## Can deployment be automatic?
Yes — for local/server deployment I added a one-command script:

```bash
cd projects/swing-trading-app
./deploy.sh docker   # preferred (Docker)
# or
./deploy.sh local    # runs with local python in background
```

Stop everything:

```bash
./deploy.sh stop
```

After deploy, open `http://localhost:8000`.

## Do you need to do anything?
- **For local deployment**: just run `./deploy.sh docker` (or `local`).
- **For cloud deployment (AWS/GCP/etc.)**: you still need to provide cloud credentials/account access. I can prepare/apply IaC if credentials are available.

## Manual run (without script)

```bash
cd projects/swing-trading-app
python -m src.main
```

Open: `http://localhost:8000`

## Deploy with Docker (manual)

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
