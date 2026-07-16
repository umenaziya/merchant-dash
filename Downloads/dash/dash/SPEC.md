# v1 Spec — Merchant Churn-Risk Dashboard

## Problem framing
No historical dataset is provided, so this is a rules-based/heuristic risk
model over a merchant record I define, seeded with generated mock data, not
a trained model. The dashboard's job: surface which merchants look like
they're drifting toward churn, and turn that into a concrete next action
someone on the CX/account team can take today.

## Merchant record shape (v1)
```
{
  id: string
  name: string
  planTier: "starter" | "growth" | "enterprise"
  mrr: number                 // monthly recurring revenue, for prioritization
  tenureDays: number           // days since signup
  daysSinceLastTransaction: number
  txnVolumeTrend30d: number    // % change, last 30d vs prior 30d (negative = declining)
  paymentFailureRate30d: number // 0-1, share of failed payment attempts
  openSupportTickets: number
  csatScore: number | null     // 1-5, most recent survey response, null if none collected
  lastContactDaysAgo: number   // days since last CS/CSM touchpoint
}
```

### Why these fields
- **daysSinceLastTransaction** — direct behavioral disengagement signal;
  merchants who stop transacting are the clearest churn precursor.
- **txnVolumeTrend30d** — catches *slowing* merchants before they go fully
  dark, not just already-dead ones.
- **paymentFailureRate30d** — friction/technical signal; failed payments
  are a known churn driver independent of intent to leave.
- **openSupportTickets** — unresolved friction; a proxy for unaddressed
  pain.
- **csatScore** — direct sentiment signal, when we have it (won't always).
- **mrr** — not a risk signal itself, but determines *priority*: a
  small-MRR merchant going quiet matters less than an enterprise account
  with the same signal.
- **tenureDays** — context for other signals (a 10-day-old merchant with
  zero transactions is normal; a 2-year merchant with zero is alarming).
- **lastContactDaysAgo** — informs the recommended next step (don't
  recommend "reach out" if CS reached out yesterday).

## Churn risk signals & scoring (v1)
Weighted heuristic score, 0-100, each signal capped/normalized then
combined. Rough initial weights (these are the first pass I expect to
tune once I see the mock data render):
- Inactivity (daysSinceLastTransaction, tenure-adjusted): 30%
- Volume trend decline: 25%
- Payment failure rate: 20%
- Open support tickets: 15%
- CSAT (only if present): 10%

Buckets: Low (<40), Medium (40-70), High (>70).

## Recommended next step (v1)
Rule-based, driven by the *dominant* contributing signal per merchant, not
just the aggregate score — a merchant flagged for payment failures needs a
different action than one flagged for silence:
- Payment failures dominant → "Billing outreach: fix payment method"
- Inactivity dominant → "Reengagement call"
- Declining volume + high MRR → "Escalate to CSM for QBR"
- Open tickets dominant → "Escalate to support lead"
- Low CSAT dominant → "Send check-in / satisfaction follow-up"
- Low risk → "No action — monitor"
Suppress "reach out" style actions if lastContactDaysAgo is very recent
(e.g., <3 days) — recommend "awaiting response" instead, to avoid telling
CS to re-contact someone they just contacted.

## Persistence (v1)
No backend. Seed data generated in-app on first load, persisted to
localStorage from then on so edits/added merchants survive a refresh.
This is a client-only static site (deployable to GitHub Pages) — no
server, no real backend, no auth.

## Known open questions going in
- Is "dominant signal" the right way to pick next-step, or should multiple
  simultaneous actions be shown? (v1: pick top one only, revisit if it
  looks wrong on mock data.)
- Weights are a guess, not derived from anything — flagging this as the
  weakest part of the model.
