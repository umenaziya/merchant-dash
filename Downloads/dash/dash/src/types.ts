export type PlanTier = 'starter' | 'growth' | 'enterprise'

export interface Merchant {
  id: string
  name: string
  planTier: PlanTier
  mrr: number
  tenureDays: number
  daysSinceLastTransaction: number
  txnVolumeTrend30d: number // percent, negative = declining
  paymentFailureRate30d: number // 0-1
  openSupportTickets: number
  csatScore: number | null // 1-5
  lastContactDaysAgo: number
}

export type RiskLevel = 'low' | 'medium' | 'high'

export type SignalKey =
  | 'inactivity'
  | 'volumeDecline'
  | 'paymentFailures'
  | 'supportTickets'
  | 'lowCsat'

export interface RiskAssessment {
  score: number // 0-100
  level: RiskLevel
  dominantSignal: SignalKey | null
  signalScores: Record<SignalKey, number>
  nextStep: string
}
