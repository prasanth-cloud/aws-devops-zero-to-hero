-- Swing Trading App core PostgreSQL schema (MVP-oriented)

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

CREATE TABLE users (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  email TEXT UNIQUE NOT NULL,
  password_hash TEXT NOT NULL,
  display_name TEXT NOT NULL,
  plan_tier TEXT NOT NULL DEFAULT 'free',
  timezone TEXT NOT NULL DEFAULT 'America/New_York',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE portfolios (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  base_currency TEXT NOT NULL DEFAULT 'USD',
  starting_equity NUMERIC(14,2) NOT NULL,
  current_equity NUMERIC(14,2) NOT NULL,
  risk_per_trade_pct NUMERIC(6,3) NOT NULL DEFAULT 1.000,
  max_portfolio_heat_pct NUMERIC(6,3) NOT NULL DEFAULT 6.000,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE symbols (
  id BIGSERIAL PRIMARY KEY,
  ticker TEXT UNIQUE NOT NULL,
  name TEXT,
  exchange TEXT,
  sector TEXT,
  industry TEXT,
  market_cap BIGINT,
  float_shares BIGINT,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE daily_bars (
  symbol_id BIGINT NOT NULL REFERENCES symbols(id) ON DELETE CASCADE,
  ts DATE NOT NULL,
  open NUMERIC(12,4) NOT NULL,
  high NUMERIC(12,4) NOT NULL,
  low NUMERIC(12,4) NOT NULL,
  close NUMERIC(12,4) NOT NULL,
  volume BIGINT NOT NULL,
  vwap NUMERIC(12,4),
  PRIMARY KEY (symbol_id, ts)
);

CREATE TABLE scans (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  description TEXT,
  filter_json JSONB NOT NULL,
  is_realtime BOOLEAN NOT NULL DEFAULT FALSE,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE scan_runs (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  scan_id UUID NOT NULL REFERENCES scans(id) ON DELETE CASCADE,
  mode TEXT NOT NULL CHECK (mode IN ('manual', 'scheduled')),
  triggered_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  completed_at TIMESTAMPTZ,
  status TEXT NOT NULL CHECK (status IN ('queued', 'running', 'completed', 'failed')),
  total_matches INT NOT NULL DEFAULT 0,
  metadata JSONB
);

CREATE TABLE scan_matches (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  scan_run_id UUID NOT NULL REFERENCES scan_runs(id) ON DELETE CASCADE,
  symbol_id BIGINT NOT NULL REFERENCES symbols(id) ON DELETE CASCADE,
  score NUMERIC(8,4),
  match_payload JSONB NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE watchlists (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  is_dynamic BOOLEAN NOT NULL DEFAULT FALSE,
  dynamic_source_scan_id UUID REFERENCES scans(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE watchlist_items (
  watchlist_id UUID NOT NULL REFERENCES watchlists(id) ON DELETE CASCADE,
  symbol_id BIGINT NOT NULL REFERENCES symbols(id) ON DELETE CASCADE,
  note TEXT,
  stage TEXT CHECK (stage IN ('watch', 'ready', 'triggered', 'active', 'closed')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (watchlist_id, symbol_id)
);

CREATE TABLE trade_plans (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  portfolio_id UUID NOT NULL REFERENCES portfolios(id) ON DELETE CASCADE,
  symbol_id BIGINT NOT NULL REFERENCES symbols(id),
  setup_tag TEXT NOT NULL,
  thesis TEXT,
  trigger_price NUMERIC(12,4),
  stop_price NUMERIC(12,4),
  target_price NUMERIC(12,4),
  status TEXT NOT NULL CHECK (status IN ('draft', 'ready', 'invalidated', 'executed')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE checklist_templates (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  checklist_json JSONB NOT NULL,
  is_default BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE trades (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  portfolio_id UUID NOT NULL REFERENCES portfolios(id) ON DELETE CASCADE,
  trade_plan_id UUID REFERENCES trade_plans(id) ON DELETE SET NULL,
  symbol_id BIGINT NOT NULL REFERENCES symbols(id),
  side TEXT NOT NULL CHECK (side IN ('long', 'short')),
  entry_at TIMESTAMPTZ,
  exit_at TIMESTAMPTZ,
  entry_price NUMERIC(12,4),
  exit_price NUMERIC(12,4),
  qty NUMERIC(14,4),
  fees NUMERIC(12,4) NOT NULL DEFAULT 0,
  slippage NUMERIC(12,4) NOT NULL DEFAULT 0,
  initial_stop NUMERIC(12,4),
  planned_risk_amount NUMERIC(12,4),
  realized_pnl NUMERIC(14,4),
  realized_r_multiple NUMERIC(10,4),
  mae_pct NUMERIC(8,4),
  mfe_pct NUMERIC(8,4),
  hold_minutes INT,
  setup_tag TEXT,
  emotion_tag TEXT,
  checklist_result_json JSONB,
  notes TEXT,
  status TEXT NOT NULL CHECK (status IN ('planned', 'open', 'partial', 'closed', 'canceled')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE trade_media (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  trade_id UUID NOT NULL REFERENCES trades(id) ON DELETE CASCADE,
  media_type TEXT NOT NULL CHECK (media_type IN ('image', 'document')),
  s3_key TEXT NOT NULL,
  caption TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE alerts (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  symbol_id BIGINT REFERENCES symbols(id),
  source_type TEXT NOT NULL CHECK (source_type IN ('scan', 'price', 'indicator', 'system')),
  condition_json JSONB NOT NULL,
  channel_json JSONB NOT NULL,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE alert_events (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  alert_id UUID NOT NULL REFERENCES alerts(id) ON DELETE CASCADE,
  triggered_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  payload JSONB NOT NULL,
  delivery_status TEXT NOT NULL CHECK (delivery_status IN ('queued', 'sent', 'failed'))
);

CREATE TABLE kpi_daily_snapshots (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  portfolio_id UUID REFERENCES portfolios(id) ON DELETE CASCADE,
  snapshot_date DATE NOT NULL,
  equity NUMERIC(14,2),
  drawdown_pct NUMERIC(8,4),
  win_rate_pct NUMERIC(8,4),
  expectancy_r NUMERIC(10,4),
  avg_r NUMERIC(10,4),
  max_drawdown_pct NUMERIC(8,4),
  metadata JSONB,
  UNIQUE (user_id, portfolio_id, snapshot_date)
);

CREATE INDEX idx_daily_bars_ts ON daily_bars(ts);
CREATE INDEX idx_scans_user ON scans(user_id);
CREATE INDEX idx_scan_runs_scan ON scan_runs(scan_id, triggered_at DESC);
CREATE INDEX idx_scan_matches_run ON scan_matches(scan_run_id);
CREATE INDEX idx_trades_user_status ON trades(user_id, status);
CREATE INDEX idx_trades_symbol ON trades(symbol_id, created_at DESC);
CREATE INDEX idx_alerts_user_active ON alerts(user_id, is_active);
