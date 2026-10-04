import React from 'react';

export const AiMonitoringView: React.FC = () => {
  return (
    <div className="admin-content">
      <div className="admin-page-header">
        <div>
          <h1 className="admin-page-title">AI Monitoring & Telemetry</h1>
          <p className="admin-page-subtitle">
            Real-time inference telemetry, token consumption, safety guardrails, and model latency benchmarks.
          </p>
        </div>
        <button
          type="button"
          className="admin-export-btn"
          onClick={() => alert('Refreshing telemetry stream...')}
        >
          <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.2">
            <polyline points="23 4 23 10 17 10" />
            <polyline points="1 20 1 14 7 14" />
            <path d="M3.51 9a9 9 0 0 1 14.85-3.36L23 10M1 14l4.64 4.36A9 9 0 0 0 20.49 15" />
          </svg>
          Live Telemetry: Active
        </button>
      </div>

      <div className="admin-metrics-grid">
        <div className="admin-metric-card">
          <p className="admin-metric-label">Model Inference Success</p>
          <div className="admin-metric-value">99.8%</div>
          <p className="admin-metric-note positive">0.02% error rate</p>
        </div>
        <div className="admin-metric-card">
          <p className="admin-metric-label">Tokens Consumed (Today)</p>
          <div className="admin-metric-value">482,190</div>
          <p className="admin-metric-note">Est. Cost: $1.42 USD</p>
        </div>
        <div className="admin-metric-card">
          <p className="admin-metric-label">P95 Response Latency</p>
          <div className="admin-metric-value">2,140ms</div>
          <p className="admin-metric-note positive">Well below 3500ms ceiling</p>
        </div>
        <div className="admin-metric-card">
          <p className="admin-metric-label">Guardrail Interceptions</p>
          <div className="admin-metric-value">0</div>
          <p className="admin-metric-note positive">Zero safety violations</p>
        </div>
      </div>

      {/* Agents Status Cards */}
      <div className="admin-charts-grid">
        <div className="admin-chart-card">
          <h3 className="admin-chart-title">Agent Telemetry Status</h3>
          <p className="admin-chart-range">Real-time health of autonomous agent cluster</p>

          <div style={{ display: 'flex', flexDirection: 'column', gap: '14px', marginTop: '16px' }}>
            {[
              { name: 'Planning Agent (Request parsing & scope formulation)', model: 'gemini-1.5-pro', status: 'Healthy', load: '18% capacity' },
              { name: 'Matching Agent (Semantic skills & geo proximity)', model: 'gemini-1.5-flash', status: 'Healthy', load: '32% capacity' },
              { name: 'Coordination Agent (Job notifications & dispatch)', model: 'gemini-1.5-flash', status: 'Healthy', load: '12% capacity' },
              { name: 'Review Agent (Completion photo validation)', model: 'gemini-1.5-pro-vision', status: 'Healthy', load: '24% capacity' },
            ].map(agent => (
              <div key={agent.name} style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', padding: '12px 14px', borderRadius: '10px', background: '#f5f8f6', border: '1px solid #e3ebe6' }}>
                <div>
                  <div style={{ fontWeight: 600, fontSize: '13.5px', color: '#141f19' }}>{agent.name}</div>
                  <div style={{ fontSize: '11.5px', color: '#64736a' }}>Model: <code>{agent.model}</code></div>
                </div>
                <div style={{ textAlign: 'right' }}>
                  <span className="admin-badge status-resolved">{agent.status}</span>
                  <div style={{ fontSize: '11px', color: '#8a9990', marginTop: '4px' }}>{agent.load}</div>
                </div>
              </div>
            ))}
          </div>
        </div>

        <div className="admin-chart-card">
          <h3 className="admin-chart-title">Token Consumption Distribution</h3>
          <p className="admin-chart-range">Proportion of tokens by agent functional role</p>

          <div style={{ display: 'flex', flexDirection: 'column', gap: '16px', marginTop: '20px' }}>
            {[
              { label: 'Semantic Provider Matching', pct: 45, color: '#113c2b' },
              { label: 'Work Scope & Cost Planning', pct: 30, color: '#256b4a' },
              { label: 'Photo Evidence Verification', pct: 18, color: '#68b28d' },
              { label: 'Customer Coordination & Alerts', pct: 7, color: '#b8e5ca' },
            ].map(item => (
              <div key={item.label}>
                <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: '13px', marginBottom: '6px' }}>
                  <span style={{ fontWeight: 500, color: '#141f19' }}>{item.label}</span>
                  <span style={{ fontWeight: 700, color: '#256b4a' }}>{item.pct}%</span>
                </div>
                <div style={{ width: '100%', height: '8px', background: '#e3ebe6', borderRadius: '4px', overflow: 'hidden' }}>
                  <div style={{ width: `${item.pct}%`, height: '100%', background: item.color, borderRadius: '4px' }} />
                </div>
              </div>
            ))}
          </div>
        </div>
      </div>
    </div>
  );
};
