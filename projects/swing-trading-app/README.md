# Swing Trading App — Product + Technical Blueprint

## 1) Product vision
A professional, data-driven swing trading platform for intermediate to advanced retail traders who hold positions from days to weeks.

Core jobs-to-be-done:
- Find high-probability setups.
- Plan trades with strict risk controls.
- Execute and journal consistently.
- Review outcomes with actionable analytics.
- Improve discipline via habit and strategy feedback.

---

## 2) Target users and personas

### Persona A: Systematic Swing Trader
- Uses technical setups (breakouts, pullbacks).
- Cares about expectancy, R-multiples, drawdowns.
- Needs reproducible scan + journal + analytics loop.

### Persona B: Discretionary Momentum Trader
- Screens sectors and relative strength daily.
- Needs fast watchlist planning and alerting.
- Wants replay and historical winner studies.

### Persona C: Ambitious Learner
- Has basic trading knowledge but inconsistent process.
- Needs checklist enforcement and habit tracking.
- Benefits from template strategies + AI coaching hints.

---

## 3) Feature architecture (mapped to requirements)

### A. Smart Stock Scanner
- Universe scope: US equities (NYSE/Nasdaq/AMEX).
- Data modes:
  - Delayed mode (free/basic plans).
  - Real-time mode (premium exchange entitlement).
- Filter groups:
  - Breakout: 52-week high or user-defined resistance breakout.
  - Relative volume (e.g., RVOL > 1.8).
  - Trend alignment (20 EMA > 50 SMA > 200 SMA).
  - Momentum (5D, 20D performance percentile).
  - Volatility contraction (ATR compression + narrowing ranges).
  - Relative strength vs benchmark (SPY/QQQ/IWM).
  - Fundamentals: market cap, sector, float.
  - Custom indicator formula builder (safe-expression DSL).
- Outputs:
  - Ranked candidates with scorecard.
  - Save scan presets.
  - Trigger alerts via email/push/websocket.

### B. Past Winners Research Engine
- Historical top winners by year/month/quarter.
- Pattern windows: pre-breakout base, earnings gap-and-go, high tight flag.
- Annotated chart overlays:
  - Volume expansion percentile.
  - Base depth and duration.
  - Earnings and catalyst timeline.
  - Sector-relative rank at breakout.
- AI commentary module:
  - Summarizes pre-move characteristics from engineered features.
- Replay mode:
  - Time-sliced chart + indicators + “known at time” fundamentals.

### C. Professional Trading Journal
- Trade log lifecycle: idea -> planned -> entered -> managed -> exited -> reviewed.
- Trade payload:
  - Symbol, setup, thesis, trigger, invalidation, target(s).
  - Entry/exit prices, size, fees/slippage.
  - R-multiple, MAE/MFE, hold time.
- Media and context:
  - Pre-entry chart screenshot.
  - Post-exit chart screenshot.
  - Notes and lessons learned.
- Process controls:
  - Pre-trade checklist (hard/soft rules).
  - Emotion tags (calm/FOMO/anxious/overconfident).

### D. Risk Management & Position Sizing
- Position size = (equity * risk%) / stop distance.
- Support fixed-dollar, fixed-percent, and volatility-adjusted sizing.
- Portfolio heat monitor: sum of open risk (% equity at risk).
- Correlation alert:
  - Symbol-to-symbol and symbol-to-index correlation thresholds.
- Risk-reward visualizer:
  - Entry, stop, target zones + expected R distribution.

### E. Performance Analytics Dashboard
- Equity curve (realized and mark-to-market variants).
- Monthly/quarterly returns and rolling expectancy.
- Setup-level profitability heatmap.
- Hold-time and day-of-week analysis.
- R vs hit-rate decomposition.
- Risk diagnostics:
  - Max drawdown, ulcer index, exposure %, turnover.

### F. Watchlist & Trade Planner
- Dynamic watchlists (scanner-driven + manual).
- Price/indicator/relative-strength alerts.
- Trade pipeline board:
  - Watch -> Ready -> Triggered -> Active -> Closed.

### G. Learning & Strategy Builder
- Strategy templates:
  - Minervini trend template.
  - Breakout continuation.
  - Pullback to 21 EMA in uptrend.
- Guided backtesting (event-driven EOD first; intraday later).
- Habit tracker:
  - Daily plan done?
  - Checklist adherence?
  - Rule violations?
- AI discipline coach:
  - Highlights recurring mistakes and corrective actions.

---

## 4) UX/UI principles
- Dark-first theme, low visual clutter.
- TradingView-like charting interactions and keyboard shortcuts.
- Context-preserving layouts:
  - Left: universe/watchlist.
  - Center: chart + setup context.
  - Right: order plan + risk box + notes.
- Responsive patterns:
  - Desktop: multi-panel workspace.
  - Mobile: stacked task-first flow (alerts, watchlist, quick journal).

---

## 5) Proposed technical architecture

### Stack
- Frontend: Next.js (React + TypeScript + TanStack Query + Zustand).
- Backend APIs: FastAPI (Python) for quant/data endpoints and business logic.
- Async/streaming: WebSocket gateway + Redis pub/sub.
- Batch/ETL: Celery workers + scheduler (APS/Celery beat).
- Database: PostgreSQL 16 + Timescale extension for time-series candles.
- Cache: Redis.
- Blob storage: S3 (chart screenshots, exports).
- Data providers: Polygon (primary), Alpaca market data (optional), Yahoo (fallback/EOD only with legal caveats).
- Charts: TradingView widget or Lightweight Charts.

### Microservice boundaries
1. **auth-service**
   - User auth, sessions, MFA, RBAC, billing entitlements.
2. **market-data-service**
   - Ingestion of bars/quotes/news/earnings; normalization layer.
3. **scanner-service**
   - Scan DSL parser, rule evaluation, ranking, scheduled scans.
4. **research-service**
   - Historical winner datasets, pattern labels, replay snapshots.
5. **journal-service**
   - Trades, notes, checklist, screenshot links.
6. **risk-service**
   - Position sizing, portfolio heat, correlation matrices.
7. **analytics-service**
   - KPI calculations, cohort/setup analytics, report generation.
8. **notification-service**
   - Email, push, in-app/websocket alerts.

### High-level data flow
1. Market data ingested -> normalized -> stored in time-series tables.
2. Scanner jobs run on schedule or on-demand.
3. Triggered results sent to watchlists and alert queues.
4. Users create plans and trades in journal.
5. Risk service validates position and portfolio constraints.
6. Analytics service computes rolling KPIs and renders dashboard tiles.

---

## 6) Security, compliance, and reliability
- Auth: OAuth2/OIDC + JWT access token + rotating refresh tokens.
- Passwordless optional; mandatory MFA for funded accounts.
- RBAC roles: free, pro, coach, admin.
- Data security:
  - TLS in transit.
  - KMS-encrypted secrets and S3 objects.
  - Row-level ownership checks in API layer.
- Audit trails:
  - Journal edits and strategy changes are versioned.
- Reliability:
  - Idempotent ingestion jobs.
  - DLQ for failed events.
  - Retry with exponential backoff.

---

## 7) AWS deployment blueprint
- **Frontend**: Next.js on AWS Amplify or ECS Fargate.
- **APIs**: FastAPI containers on ECS Fargate behind ALB.
- **Workers**: ECS services for Celery workers.
- **DB**: Amazon RDS PostgreSQL Multi-AZ.
- **Cache**: ElastiCache Redis.
- **Storage**: S3 + CloudFront.
- **Async messaging**: SQS + EventBridge.
- **Observability**: CloudWatch logs/metrics, X-Ray tracing, OpenSearch optional.
- **Security**: Cognito (optional), IAM least privilege, WAF, Secrets Manager.

Environment tiers:
- dev (shared)
- staging (production-like)
- prod (isolated VPC, strict IAM, backups + PITR)

---

## 8) MVP scope (10–12 weeks)

### MVP In
- Auth, profile, onboarding.
- Core scanner with saved scans and alerts.
- Watchlist + planner.
- Journal with screenshots and setup tags.
- Risk calculator and position sizing.
- Basic analytics (win rate, expectancy, drawdown, R stats).

### MVP Out (Phase 2)
- Deep replay engine.
- Full backtesting framework.
- AI discipline coach advanced personalization.
- Broker execution.

---

## 9) Phase-2 roadmap

### Phase 2A
- Broker integration (Alpaca/IBKR abstraction layer).
- Strategy versioning and experiment tracking.
- Advanced factor analytics and market regime detection.

### Phase 2B
- Community strategy sharing and leaderboards.
- Institutional-style attribution (sector, factor, timing).
- AI copilot for trade review and pre-trade challenge prompts.

---

## 10) Non-functional targets
- Scanner response: < 2.5s for common filters on 8k symbols (cached path).
- Alert latency: < 5s for intraday trigger propagation.
- Dashboard P95 API latency: < 400ms for cached aggregates.
- Availability target: 99.9% monthly.
- RPO: 15 min, RTO: 1 hour for production.

---

## 11) API, schema, and flow references
- Database schema: `projects/swing-trading-app/schema.sql`
- API contract: `projects/swing-trading-app/api-spec.yaml`
- User/system flows: `projects/swing-trading-app/user-flows.md`
