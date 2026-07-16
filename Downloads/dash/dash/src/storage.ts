import type { Merchant } from './types'
import { seedMerchants } from './mockData'

const STORAGE_KEY = 'churn-dashboard.merchants.v1'

export function loadMerchants(): Merchant[] {
  const raw = localStorage.getItem(STORAGE_KEY)
  if (!raw) return seedMerchants
  try {
    const parsed = JSON.parse(raw)
    if (Array.isArray(parsed)) return parsed as Merchant[]
    return seedMerchants
  } catch {
    return seedMerchants
  }
}

export function saveMerchants(merchants: Merchant[]): void {
  localStorage.setItem(STORAGE_KEY, JSON.stringify(merchants))
}

export function resetMerchants(): Merchant[] {
  localStorage.removeItem(STORAGE_KEY)
  return seedMerchants
}
