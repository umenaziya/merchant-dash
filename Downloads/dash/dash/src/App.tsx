import { useMemo, useState } from 'react'
import type { Merchant, RiskLevel } from './types'
import { assessMerchant } from './riskEngine'
import { loadMerchants, saveMerchants, resetMerchants } from './storage'
import './App.css'

type SortKey = 'score' | 'mrr' | 'name'
type LevelFilter = 'all' | RiskLevel
type View = 'dashboard' | 'analysis'

const SIGNAL_LABELS: Record<string, string> = {
  inactivity: 'Inactivity',
  volumeDecline: 'Volume decline',
  paymentFailures: 'Payment failures',
  supportTickets: 'Open tickets',
  lowCsat: 'Low CSAT',
}

const emptyDraft = (): Omit<Merchant, 'id'> => ({
  name: '',
  planTier: 'starter',
  mrr: 0,
  tenureDays: 0,
  daysSinceLastTransaction: 0,
  txnVolumeTrend30d: 0,
  paymentFailureRate30d: 0,
  openSupportTickets: 0,
  csatScore: null,
  lastContactDaysAgo: 0,
})

function App() {
  const [view, setView] = useState<View>('dashboard')
  const [merchants, setMerchants] = useState<Merchant[]>(() => loadMerchants())
  const [levelFilter, setLevelFilter] = useState<LevelFilter>('all')
  const [sortKey, setSortKey] = useState<SortKey>('score')
  const [search, setSearch] = useState('')
  const [expandedId, setExpandedId] = useState<string | null>(null)
  const [showAddForm, setShowAddForm] = useState(false)
  const [draft, setDraft] = useState<Omit<Merchant, 'id'>>(emptyDraft())

  const assessed = useMemo(
    () => merchants.map((m) => ({ merchant: m, assessment: assessMerchant(m) })),
    [merchants],
  )

  const summary = useMemo(() => {
    const counts = { low: 0, medium: 0, high: 0 }
    for (const { assessment } of assessed) counts[assessment.level]++
    return counts
  }, [assessed])

  const analysis = useMemo(() => {
    const totalMrr = assessed.reduce((sum, r) => sum + r.merchant.mrr, 0)
    const mrrAtRisk = assessed
      .filter((r) => r.assessment.level !== 'low')
      .reduce((sum, r) => sum + r.merchant.mrr, 0)
    const avgScore = assessed.length
      ? Math.round(assessed.reduce((sum, r) => sum + r.assessment.score, 0) / assessed.length)
      : 0
    const actionCounts = new Map<string, number>()
    for (const r of assessed) {
      if (r.assessment.nextStep === 'No action — monitor') continue
      actionCounts.set(r.assessment.nextStep, (actionCounts.get(r.assessment.nextStep) ?? 0) + 1)
    }
    const actions = [...actionCounts.entries()]
      .map(([label, count]) => ({ label, count }))
      .sort((a, b) => b.count - a.count)
    return { totalMrr, mrrAtRisk, avgScore, actions }
  }, [assessed])

  const visible = useMemo(() => {
    let rows = assessed
    if (levelFilter !== 'all') {
      rows = rows.filter((r) => r.assessment.level === levelFilter)
    }
    if (search.trim()) {
      const q = search.trim().toLowerCase()
      rows = rows.filter((r) => r.merchant.name.toLowerCase().includes(q))
    }
    rows = [...rows].sort((a, b) => {
      if (sortKey === 'score') return b.assessment.score - a.assessment.score
      if (sortKey === 'mrr') return b.merchant.mrr - a.merchant.mrr
      return a.merchant.name.localeCompare(b.merchant.name)
    })
    return rows
  }, [assessed, levelFilter, sortKey, search])

  function persist(next: Merchant[]) {
    setMerchants(next)
    saveMerchants(next)
  }

  function handleReset() {
    if (!confirm('Reset all merchants back to the original seed data? This discards any merchants you added or edited.')) return
    persist(resetMerchants())
  }

  function handleRemove(id: string) {
    persist(merchants.filter((m) => m.id !== id))
  }

  function handleAddSubmit(e: React.FormEvent) {
    e.preventDefault()
    if (!draft.name.trim()) return
    const newMerchant: Merchant = { ...draft, id: `m-${Date.now()}` }
    persist([...merchants, newMerchant])
    setDraft(emptyDraft())
    setShowAddForm(false)
  }

  return (
    <div className="app-shell">
      <nav className="navbar">
        <div className="navbar-brand">
          <span className="navbar-mark" aria-hidden="true">◆</span>
          <span>Churn Radar</span>
        </div>
        <div className="navbar-tabs" role="tablist" aria-label="View">
          <button
            type="button"
            role="tab"
            aria-selected={view === 'dashboard'}
            className={view === 'dashboard' ? 'navbar-tab active' : 'navbar-tab'}
            onClick={() => setView('dashboard')}
          >
            Dashboard
          </button>
          <button
            type="button"
            role="tab"
            aria-selected={view === 'analysis'}
            className={view === 'analysis' ? 'navbar-tab active' : 'navbar-tab'}
            onClick={() => setView('analysis')}
          >
            Analysis
          </button>
        </div>
        <div className="navbar-search">
          <svg className="search-icon" viewBox="0 0 20 20" aria-hidden="true">
            <circle cx="9" cy="9" r="6.5" fill="none" stroke="currentColor" strokeWidth="1.6" />
            <line x1="14" y1="14" x2="18.5" y2="18.5" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" />
          </svg>
          <input
            type="search"
            placeholder="Search merchants…"
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            aria-label="Search merchants by name"
          />
        </div>
      </nav>

      <div className="dashboard">
        {view === 'dashboard' && (
          <>
            <header className="dashboard-header">
              <div>
                <h1>Merchant Churn Risk</h1>
                <p className="subtitle">
                  Heuristic risk scoring over transaction, billing, support, and
                  sentiment signals. Data persists locally in your browser.
                </p>
              </div>
              <div className="header-actions">
                <button type="button" onClick={() => setShowAddForm((v) => !v)}>
                  {showAddForm ? 'Cancel' : '+ Add merchant'}
                </button>
                <button type="button" className="ghost" onClick={handleReset}>
                  Reset to seed data
                </button>
              </div>
            </header>

            <section className="summary-row">
              <SummaryCard label="High risk" count={summary.high} level="high" />
              <SummaryCard label="Medium risk" count={summary.medium} level="medium" />
              <SummaryCard label="Low risk" count={summary.low} level="low" />
              <SummaryCard label="Total merchants" count={merchants.length} level="all" />
            </section>

            {showAddForm && (
              <form className="add-form" onSubmit={handleAddSubmit}>
                <h2>Add merchant</h2>
                <div className="form-grid">
                  <label>
                    Name
                    <input
                      required
                      value={draft.name}
                      onChange={(e) => setDraft({ ...draft, name: e.target.value })}
                    />
                  </label>
                  <label>
                    Plan tier
                    <select
                      value={draft.planTier}
                      onChange={(e) =>
                        setDraft({ ...draft, planTier: e.target.value as Merchant['planTier'] })
                      }
                    >
                      <option value="starter">Starter</option>
                      <option value="growth">Growth</option>
                      <option value="enterprise">Enterprise</option>
                    </select>
                  </label>
                  <label>
                    MRR ($)
                    <input
                      type="number"
                      min={0}
                      value={draft.mrr}
                      onChange={(e) => setDraft({ ...draft, mrr: Number(e.target.value) })}
                    />
                  </label>
                  <label>
                    Tenure (days)
                    <input
                      type="number"
                      min={0}
                      value={draft.tenureDays}
                      onChange={(e) => setDraft({ ...draft, tenureDays: Number(e.target.value) })}
                    />
                  </label>
                  <label>
                    Days since last transaction
                    <input
                      type="number"
                      min={0}
                      value={draft.daysSinceLastTransaction}
                      onChange={(e) =>
                        setDraft({ ...draft, daysSinceLastTransaction: Number(e.target.value) })
                      }
                    />
                  </label>
                  <label>
                    30d volume trend (%)
                    <input
                      type="number"
                      value={draft.txnVolumeTrend30d}
                      onChange={(e) =>
                        setDraft({ ...draft, txnVolumeTrend30d: Number(e.target.value) })
                      }
                    />
                  </label>
                  <label>
                    Payment failure rate (0-1)
                    <input
                      type="number"
                      min={0}
                      max={1}
                      step={0.01}
                      value={draft.paymentFailureRate30d}
                      onChange={(e) =>
                        setDraft({ ...draft, paymentFailureRate30d: Number(e.target.value) })
                      }
                    />
                  </label>
                  <label>
                    Open support tickets
                    <input
                      type="number"
                      min={0}
                      value={draft.openSupportTickets}
                      onChange={(e) =>
                        setDraft({ ...draft, openSupportTickets: Number(e.target.value) })
                      }
                    />
                  </label>
                  <label>
                    CSAT score (1-5, blank if none)
                    <input
                      type="number"
                      min={1}
                      max={5}
                      value={draft.csatScore ?? ''}
                      onChange={(e) =>
                        setDraft({
                          ...draft,
                          csatScore: e.target.value === '' ? null : Number(e.target.value),
                        })
                      }
                    />
                  </label>
                  <label>
                    Days since last CS contact
                    <input
                      type="number"
                      min={0}
                      value={draft.lastContactDaysAgo}
                      onChange={(e) =>
                        setDraft({ ...draft, lastContactDaysAgo: Number(e.target.value) })
                      }
                    />
                  </label>
                </div>
                <button type="submit">Save merchant</button>
              </form>
            )}

            <section className="controls">
              <div className="filter-group">
                <span>Filter:</span>
                {(['all', 'high', 'medium', 'low'] as LevelFilter[]).map((lvl) => (
                  <button
                    key={lvl}
                    type="button"
                    className={levelFilter === lvl ? 'chip active' : 'chip'}
                    onClick={() => setLevelFilter(lvl)}
                  >
                    {lvl === 'all' ? 'All' : lvl[0].toUpperCase() + lvl.slice(1)}
                  </button>
                ))}
              </div>
              <div className="sort-group">
                <label>
                  Sort by
                  <select value={sortKey} onChange={(e) => setSortKey(e.target.value as SortKey)}>
                    <option value="score">Risk score</option>
                    <option value="mrr">MRR</option>
                    <option value="name">Name</option>
                  </select>
                </label>
              </div>
            </section>

            <section className="merchant-list">
              {visible.length === 0 && (
                <p className="empty-state">No merchants match your filters/search.</p>
              )}
              {visible.map(({ merchant, assessment }) => (
                <article key={merchant.id} className={`merchant-card level-${assessment.level}`}>
                  <div className="merchant-row">
                    <div className="merchant-identity">
                      <span className={`risk-badge level-${assessment.level}`}>
                        {assessment.level.toUpperCase()} · {assessment.score}
                      </span>
                      <div>
                        <h3>{merchant.name}</h3>
                        <span className="meta">
                          {merchant.planTier} · ${merchant.mrr}/mo · {merchant.tenureDays}d tenure
                        </span>
                      </div>
                    </div>
                    <div className="next-step">
                      <span className="next-step-label">Next step</span>
                      <span className="next-step-value">{assessment.nextStep}</span>
                    </div>
                    <div className="row-actions">
                      <button
                        type="button"
                        className="ghost small"
                        onClick={() => setExpandedId(expandedId === merchant.id ? null : merchant.id)}
                      >
                        {expandedId === merchant.id ? 'Hide detail' : 'Detail'}
                      </button>
                      <button type="button" className="ghost small danger" onClick={() => handleRemove(merchant.id)}>
                        Remove
                      </button>
                    </div>
                  </div>

                  {expandedId === merchant.id && (
                    <div className="merchant-detail">
                      <table>
                        <thead>
                          <tr>
                            <th>Signal</th>
                            <th>Sub-score (0-100)</th>
                          </tr>
                        </thead>
                        <tbody>
                          {Object.entries(assessment.signalScores).map(([key, value]) => (
                            <tr key={key} className={assessment.dominantSignal === key ? 'dominant' : ''}>
                              <td>
                                {SIGNAL_LABELS[key]}
                                {assessment.dominantSignal === key && <span className="tag"> dominant</span>}
                              </td>
                              <td>{Math.round(value)}</td>
                            </tr>
                          ))}
                        </tbody>
                      </table>
                      <dl className="raw-fields">
                        <div><dt>Days since last txn</dt><dd>{merchant.daysSinceLastTransaction}</dd></div>
                        <div><dt>30d volume trend</dt><dd>{merchant.txnVolumeTrend30d}%</dd></div>
                        <div><dt>Payment failure rate</dt><dd>{Math.round(merchant.paymentFailureRate30d * 100)}%</dd></div>
                        <div><dt>Open tickets</dt><dd>{merchant.openSupportTickets}</dd></div>
                        <div><dt>CSAT</dt><dd>{merchant.csatScore ?? 'no data'}</dd></div>
                        <div><dt>Last CS contact</dt><dd>{merchant.lastContactDaysAgo}d ago</dd></div>
                      </dl>
                    </div>
                  )}
                </article>
              ))}
            </section>
          </>
        )}

        {view === 'analysis' && (
          <AnalysisView
            summary={summary}
            totalMerchants={merchants.length}
            totalMrr={analysis.totalMrr}
            mrrAtRisk={analysis.mrrAtRisk}
            avgScore={analysis.avgScore}
            actions={analysis.actions}
          />
        )}
      </div>
    </div>
  )
}

function SummaryCard({
  label,
  count,
  level,
}: {
  label: string
  count: number
  level: RiskLevel | 'all'
}) {
  return (
    <div className={`summary-card level-${level}`}>
      <span className="summary-count">{count}</span>
      <span className="summary-label">{label}</span>
    </div>
  )
}

function AnalysisView({
  summary,
  totalMerchants,
  totalMrr,
  mrrAtRisk,
  avgScore,
  actions,
}: {
  summary: { low: number; medium: number; high: number }
  totalMerchants: number
  totalMrr: number
  mrrAtRisk: number
  avgScore: number
  actions: { label: string; count: number }[]
}) {
  const pctAtRisk = totalMerchants ? Math.round(((summary.medium + summary.high) / totalMerchants) * 100) : 0
  const pctMrrAtRisk = totalMrr ? Math.round((mrrAtRisk / totalMrr) * 100) : 0
  const maxActionCount = Math.max(1, ...actions.map((a) => a.count))
  const distTotal = Math.max(1, summary.low + summary.medium + summary.high)

  return (
    <section className="analysis" aria-label="Portfolio analysis">
      <div className="stat-tiles">
        <div className="stat-tile">
          <span className="stat-value">${mrrAtRisk.toLocaleString()}</span>
          <span className="stat-label">MRR at risk ({pctMrrAtRisk}% of ${totalMrr.toLocaleString()})</span>
        </div>
        <div className="stat-tile">
          <span className="stat-value">{pctAtRisk}%</span>
          <span className="stat-label">of merchants flagged medium/high</span>
        </div>
        <div className="stat-tile">
          <span className="stat-value">{avgScore}</span>
          <span className="stat-label">average risk score (0-100)</span>
        </div>
      </div>

      <div className="analysis-card">
        <h2>Risk distribution</h2>
        <div className="stacked-bar" role="img" aria-label={`${summary.low} low, ${summary.medium} medium, ${summary.high} high risk merchants`}>
          {summary.low > 0 && (
            <div
              className="stacked-seg seg-good"
              style={{ width: `${(summary.low / distTotal) * 100}%` }}
            />
          )}
          {summary.medium > 0 && (
            <div
              className="stacked-seg seg-warning"
              style={{ width: `${(summary.medium / distTotal) * 100}%` }}
            />
          )}
          {summary.high > 0 && (
            <div
              className="stacked-seg seg-critical"
              style={{ width: `${(summary.high / distTotal) * 100}%` }}
            />
          )}
        </div>
        <ul className="legend">
          <li><span className="dot seg-good" /> Low — {summary.low}</li>
          <li><span className="dot seg-warning" /> Medium — {summary.medium}</li>
          <li><span className="dot seg-critical" /> High — {summary.high}</li>
        </ul>
      </div>

      <div className="analysis-card">
        <h2>Recommended actions, by type</h2>
        {actions.length === 0 && <p className="empty-state">No merchants currently need action.</p>}
        {actions.length > 0 && (
          <ul className="bar-list">
            {actions.map((a) => (
              <li key={a.label}>
                <span className="bar-list-label">{a.label}</span>
                <div className="bar-list-track">
                  <div className="bar-list-fill" style={{ width: `${(a.count / maxActionCount) * 100}%` }} />
                </div>
                <span className="bar-list-count">{a.count}</span>
              </li>
            ))}
          </ul>
        )}
      </div>
    </section>
  )
}

export default App
