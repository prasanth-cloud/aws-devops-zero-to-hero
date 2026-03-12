# User and system flows

## 1. End-to-end user lifecycle

```mermaid
flowchart TD
  A[Sign up / Login] --> B[Connect preferences and portfolio rules]
  B --> C[Run scanner or load saved scans]
  C --> D[Review candidates and push to watchlist]
  D --> E[Create trade plan and validate checklist]
  E --> F[Use risk engine for position size]
  F --> G[Log trade execution]
  G --> H[Manage and close trade]
  H --> I[Journal review + screenshot + emotion]
  I --> J[Analytics dashboard updates]
  J --> K[Habit/discipline feedback]
  K --> C
```

## 2. Scanner execution flow

```mermaid
sequenceDiagram
  participant U as User
  participant FE as Frontend
  participant API as API Gateway
  participant SC as Scanner Service
  participant MD as Market Data Service
  participant DB as PostgreSQL
  participant N as Notification Service

  U->>FE: Trigger saved scan
  FE->>API: POST /scans/{id}/run
  API->>SC: enqueue run
  SC->>MD: fetch latest bars/indicators
  MD-->>SC: normalized dataset
  SC->>SC: evaluate rules + rank
  SC->>DB: persist scan_run + matches
  SC->>N: publish alert events for triggers
  N-->>U: push/email/in-app alert
  FE->>API: GET /scan-runs/{runId}/matches
  API->>DB: fetch results
  DB-->>FE: candidate list
```

## 3. Trade journaling + analytics flow

```mermaid
sequenceDiagram
  participant U as User
  participant FE as Frontend
  participant JS as Journal Service
  participant RS as Risk Service
  participant AN as Analytics Service
  participant S3 as S3 Media
  participant DB as PostgreSQL

  U->>FE: Create trade plan
  FE->>RS: POST /risk/position-size
  RS-->>FE: recommended qty, risk metrics
  U->>FE: Confirm and log trade
  FE->>JS: POST /trades
  JS->>DB: write trade(open)
  U->>FE: Upload chart screenshot + notes
  FE->>S3: upload media
  FE->>JS: attach media metadata
  U->>FE: Close trade
  FE->>JS: POST /trades/{id}/close
  JS->>DB: update pnl, r-multiple
  JS->>AN: emit trade_closed event
  AN->>DB: update KPI snapshots
  FE->>AN: GET /analytics/summary
  AN-->>FE: updated win rate/expectancy/drawdown
```

## 4. Information architecture
- Workspace
  - Scanner
  - Watchlists
  - Chart + Planner
  - Journal
  - Analytics
  - Learning Lab
- Global entities
  - Symbol
  - Trade Plan
  - Trade
  - Alert
  - Strategy Template
