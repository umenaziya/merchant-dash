import type { Merchant, RiskAssessment, RiskLevel, SignalKey } from './types'

const WEIGHTS: Record<SignalKey, number> = {
  inactivity: 0.3,
  volumeDecline: 0.25,
  paymentFailures: 0.2,
  supportTickets: 0.15,
  lowCsat: 0.1,
}

function clamp(n: number, min: number, max: number) {
  return Math.max(min, Math.min(max, n))
}

function inactivityScore(m: Merchant): number {
  const raw = clamp((m.daysSinceLastTransaction / 60) * 100, 0, 100)
  // A brand-new merchant with no transactions yet isn't a red flag the
  // same way a 2-year merchant going quiet is — dampen for short tenure.
  const tenureFactor = m.tenureDays < 14 ? m.tenureDays / 14 : 1
  return raw * tenureFactor
}

function volumeDeclineScore(m: Merchant): number {
  if (m.txnVolumeTrend30d >= 0) return 0
  return clamp(Math.abs(m.txnVolumeTrend30d) * 2, 0, 100)
}

function paymentFailureScore(m: Merchant): number {
  return clamp(m.paymentFailureRate30d * 100, 0, 100)
}

function supportTicketsScore(m: Merchant): number {
  return clamp(m.openSupportTickets * 20, 0, 100)
}

function lowCsatScore(m: Merchant): number | null {
  if (m.csatScore === null) return null
  return clamp(((5 - m.csatScore) / 4) * 100, 0, 100)
}

function levelFromScore(score: number): RiskLevel {
  if (score >= 70) return 'high'
  if (score >= 40) return 'medium'
  return 'low'
}

function isHighValue(m: Merchant): boolean {
  return m.planTier === 'enterprise' || m.mrr >= 1000
}

function recentlyContacted(m: Merchant): boolean {
  return m.lastContactDaysAgo < 3
}

function actionDriver(
  dominant: SignalKey | null,
  signalScores: Record<SignalKey, number>,
): SignalKey | null {
  // Payment failures and open tickets are usually root causes (they can
  // directly *produce* inactivity or volume decline downstream), and
  // they're the levers CX can actually pull. When either is severe, act
  // on it even if it isn't the mathematically largest weighted
  // contributor to the aggregate score.
  if (signalScores.paymentFailures >= 50) return 'paymentFailures'
  if (signalScores.supportTickets >= 60) return 'supportTickets'
  return dominant
}

function nextStepFor(m: Merchant, level: RiskLevel, dominant: SignalKey | null): string {
  if (level === 'low' || dominant === null) return 'No action — monitor'

  switch (dominant) {
    case 'paymentFailures':
      return 'Billing outreach: help fix payment method'
    case 'inactivity':
      return recentlyContacted(m)
        ? 'Recently contacted — awaiting response'
        : 'Reengagement call'
    case 'volumeDecline':
      return isHighValue(m)
        ? 'Escalate to CSM for QBR'
        : 'Check in on recent volume drop'
    case 'supportTickets':
      return 'Escalate to support lead'
    case 'lowCsat':
      return recentlyContacted(m)
        ? 'Recently contacted — awaiting response'
        : 'Send check-in / satisfaction follow-up'
    default:
      return 'No action — monitor'
  }
}

export function assessMerchant(m: Merchant): RiskAssessment {
  const rawScores: Partial<Record<SignalKey, number>> = {
    inactivity: inactivityScore(m),
    volumeDecline: volumeDeclineScore(m),
    paymentFailures: paymentFailureScore(m),
    supportTickets: supportTicketsScore(m),
  }
  const csat = lowCsatScore(m)
  if (csat !== null) rawScores.lowCsat = csat

  const presentKeys = Object.keys(rawScores) as SignalKey[]
  const weightTotal = presentKeys.reduce((sum, k) => sum + WEIGHTS[k], 0)

  let weightedSum = 0
  let dominant: SignalKey | null = null
  let dominantContribution = -Infinity
  const signalScores: Record<SignalKey, number> = {
    inactivity: 0,
    volumeDecline: 0,
    paymentFailures: 0,
    supportTickets: 0,
    lowCsat: 0,
  }

  for (const key of presentKeys) {
    const raw = rawScores[key] as number
    signalScores[key] = raw
    const normalizedWeight = WEIGHTS[key] / weightTotal
    const contribution = raw * normalizedWeight
    weightedSum += contribution
    if (contribution > dominantContribution) {
      dominantContribution = contribution
      dominant = key
    }
  }

  const score = Math.round(clamp(weightedSum, 0, 100))
  // A weighted average can smooth away a single extreme signal (e.g. 55+
  // days of total inactivity) if every other signal looks healthy, since
  // no individual weight exceeds 30%. That understates real risk — a
  // merchant that's gone almost completely dark, or is failing most of
  // its payments, deserves at least a "medium" flag regardless of what
  // the composite average says. Found this by testing a synthetic
  // "healthy except very inactive" merchant, which stayed 'low' at score
  // 38 despite 55 days of silence.
  const worstSingleSignal = Math.max(...Object.values(signalScores))
  let level = levelFromScore(score)
  if (worstSingleSignal >= 80 && level === 'low') level = 'medium'
  // Below the "medium" floor, don't attribute a dominant driver — noise,
  // not a signal worth acting on.
  const effectiveDominant = level === 'low' ? null : dominant
  const driver = level === 'low' ? null : actionDriver(dominant, signalScores)
  const nextStep = nextStepFor(m, level, driver)

  return { score, level, dominantSignal: effectiveDominant, signalScores, nextStep }
}
