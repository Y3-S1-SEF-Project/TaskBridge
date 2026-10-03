import React from 'react';

export const ReportsView: React.FC = () => {
  return (
    <div className="admin-content">
      <div className="admin-page-header">
        <div>
          <h1 className="admin-page-title">Financial & Operational Reports</h1>
          <p className="admin-page-subtitle">
            Gross marketplace volume (GMV), platform commission yields, provider settlements, and revenue forecasts.
          </p>
        </div>
        <button
          type="button"
          className="admin-export-btn"
          onClick={() => alert('Downloading full fiscal report (Excel/CSV)...')}
        >
          <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.2">
            <path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4" />
            <polyline points="7 10 12 15 17 10" />
            <line x1="12" y1="15" x2="12" y2="3" />
          </svg>
          Export Full Financial Ledger
        </button>
      </div>

      <div className="admin-metrics-grid">
        <div className="admin-metric-card">
          <p className="admin-metric-label">Gross Merchandise Value (GMV)</p>
          <div className="admin-metric-value">LKR 4.82M</div>
          <p className="admin-metric-note positive">+18.5% MoM growth</p>
        </div>
        <div className="admin-metric-card">
          <p className="admin-metric-label">Platform Commission (12%)</p>
          <div className="admin-metric-value">LKR 578.4k</div>
          <p className="admin-metric-note positive">Net marketplace revenue</p>
        </div>
        <div className="admin-metric-card">
          <p className="admin-metric-label">Provider Payouts Disbursed</p>
          <div className="admin-metric-value">LKR 4.24M</div>
          <p className="admin-metric-note">100% on-time bank transfers</p>
        </div>
        <div className="admin-metric-card">
          <p className="admin-metric-label">Average Order Value (AOV)</p>
          <div className="admin-metric-value">LKR 8,450</div>
          <p className="admin-metric-note positive">+6.2% vs last month</p>
        </div>
      </div>

      <div className="admin-charts-grid">
        <div className="admin-chart-card">
          <h3 className="admin-chart-title">Revenue by Service Category</h3>
          <p className="admin-chart-range">Proportional GMV contribution (Current Quarter)</p>

          <div style={{ display: 'flex', flexDirection: 'column', gap: '16px', marginTop: '18px' }}>
            {[
              { category: 'Electrical & Power Systems', revenue: 'LKR 1.84M', pct: 38, color: '#113c2b' },
              { category: 'Air Conditioning & Cooling', revenue: 'LKR 1.42M', pct: 29, color: '#256b4a' },
              { category: 'Plumbing & Sanitary', revenue: 'LKR 880k', pct: 18, color: '#68b28d' },
              { category: 'Carpentry & Furniture', revenue: 'LKR 420k', pct: 9, color: '#9cd1b5' },
              { category: 'Deep Cleaning & Sanitization', revenue: 'LKR 260k', pct: 6, color: '#cde9db' },
            ].map(row => (
              <div key={row.category}>
                <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: '13px', marginBottom: '6px' }}>
                  <span style={{ fontWeight: 600, color: '#141f19' }}>{row.category}</span>
                  <span style={{ fontWeight: 700, color: '#256b4a' }}>{row.revenue} ({row.pct}%)</span>
                </div>
                <div style={{ width: '100%', height: '8px', background: '#e3ebe6', borderRadius: '4px', overflow: 'hidden' }}>
                  <div style={{ width: `${row.pct}%`, height: '100%', background: row.color, borderRadius: '4px' }} />
                </div>
              </div>
            ))}
          </div>
        </div>

        <div className="admin-chart-card">
          <h3 className="admin-chart-title">Weekly Settlement Telemetry</h3>
          <p className="admin-chart-range">Provider automated direct bank deposits</p>

          <div style={{ display: 'flex', flexDirection: 'column', gap: '12px', marginTop: '16px' }}>
            {[
              { date: 'Friday, Oct 02 (Pending)', amount: 'LKR 340,200', count: '28 providers', status: 'Processing' },
              { date: 'Friday, Sep 25 (Settled)', amount: 'LKR 892,400', count: '74 providers', status: 'Completed' },
              { date: 'Friday, Sep 18 (Settled)', amount: 'LKR 914,600', count: '82 providers', status: 'Completed' },
              { date: 'Friday, Sep 11 (Settled)', amount: 'LKR 842,100', count: '69 providers', status: 'Completed' },
            ].map(p => (
              <div key={p.date} style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', padding: '12px 14px', borderRadius: '10px', background: '#f5f8f6', border: '1px solid #e3ebe6' }}>
                <div>
                  <div style={{ fontWeight: 600, fontSize: '13.5px', color: '#141f19' }}>{p.date}</div>
                  <div style={{ fontSize: '12px', color: '#64736a' }}>{p.count}</div>
                </div>
                <div style={{ textAlign: 'right' }}>
                  <div style={{ fontWeight: 700, fontSize: '14px', color: '#113c2b' }}>{p.amount}</div>
                  <span className={`admin-badge ${p.status === 'Completed' ? 'status-resolved' : 'status-waiting'}`} style={{ marginTop: '4px' }}>
                    {p.status}
                  </span>
                </div>
              </div>
            ))}
          </div>
        </div>
      </div>
    </div>
  );
};
