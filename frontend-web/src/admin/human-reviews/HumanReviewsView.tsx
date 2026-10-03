import React, { useState } from 'react';

interface HumanReviewCase {
  id: string;
  bookingRef: string;
  agent: string;
  confidenceScore: number;
  flagReason: string;
  provider: string;
  customer: string;
  status: 'Pending Review' | 'Approved' | 'Rejected' | 'More Info Requested';
  timestamp: string;
}

const mockCases: HumanReviewCase[] = [
  { id: 'HREV-104', bookingRef: 'BK-499', agent: 'Review Agent (Vision)', confidenceScore: 68, flagReason: 'Bathroom repair photo blurry; unable to verify valve replacement autonomously', provider: 'Sunil Plumbing', customer: 'Malik De Silva', status: 'Pending Review', timestamp: '35 mins ago' },
  { id: 'HREV-103', bookingRef: 'BK-492', agent: 'Matching Agent (NLP)', confidenceScore: 72, flagReason: 'Ambiguous description: customer mentioned both electrical wiring and masonry work', provider: 'Pending Triage', customer: 'Hirantha Perera', status: 'Pending Review', timestamp: '1 hour ago' },
  { id: 'HREV-102', bookingRef: 'BK-481', agent: 'Planning Agent (Estimator)', confidenceScore: 61, flagReason: 'Estimated materials cost 300% higher than historical regional baseline', provider: 'Sanjaya Electricals', customer: 'Roshan Dias', status: 'Approved', timestamp: 'Yesterday' },
];

export const HumanReviewsView: React.FC = () => {
  const [cases, setCases] = useState(mockCases);

  const handleAction = (id: string, newStatus: 'Approved' | 'Rejected') => {
    setCases(prev => prev.map(c => c.id === id ? { ...c, status: newStatus } : c));
  };

  return (
    <div className="admin-content">
      <div className="admin-page-header">
        <div>
          <h1 className="admin-page-title">Human-in-the-Loop Reviews</h1>
          <p className="admin-page-subtitle">
            Supervisory review queue for AI confidence exceptions, low-certainty matches, and disputed completion evidence.
          </p>
        </div>
        <button
          type="button"
          className="admin-export-btn"
          onClick={() => alert('Exporting human review audit trail...')}
        >
          <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.2">
            <path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4" />
            <polyline points="7 10 12 15 17 10" />
            <line x1="12" y1="15" x2="12" y2="3" />
          </svg>
          Export Review Audit
        </button>
      </div>

      <div className="admin-metrics-grid">
        <div className="admin-metric-card">
          <p className="admin-metric-label">Queue Backlog</p>
          <div className="admin-metric-value">{cases.filter(c => c.status === 'Pending Review').length}</div>
          <p className="admin-metric-note">Under 15m review SLA</p>
        </div>
        <div className="admin-metric-card">
          <p className="admin-metric-label">AI Threshold Baseline</p>
          <div className="admin-metric-value">85%</div>
          <p className="admin-metric-note positive">Confidence below 85% routes here</p>
        </div>
        <div className="admin-metric-card">
          <p className="admin-metric-label">Human Approval Rate</p>
          <div className="admin-metric-value">88.4%</div>
          <p className="admin-metric-note positive">Staff validates AI assessment</p>
        </div>
        <div className="admin-metric-card">
          <p className="admin-metric-label">Escrow Release Safety</p>
          <div className="admin-metric-value">100%</div>
          <p className="admin-metric-note positive">Funds locked until sign-off</p>
        </div>
      </div>

      <div className="admin-table-card">
        <h3 className="admin-table-title">Exceptions Requiring Human Adjudication</h3>
        <div className="admin-table-container">
          <table className="admin-table">
            <thead>
              <tr>
                <th>Review ID</th>
                <th>Booking Ref</th>
                <th>Originating Agent</th>
                <th>Confidence</th>
                <th>Flag Reason</th>
                <th>Customer / Provider</th>
                <th>Status</th>
                <th>Time</th>
                <th className="actions-col">Adjudicate</th>
              </tr>
            </thead>
            <tbody>
              {cases.map(c => (
                <tr key={c.id}>
                  <td><span className="admin-inquiry-code">{c.id}</span></td>
                  <td><strong>{c.bookingRef}</strong></td>
                  <td><span className="admin-badge priority-normal">{c.agent}</span></td>
                  <td>
                    <span style={{
                      fontWeight: 700,
                      color: c.confidenceScore < 70 ? '#c81e1e' : '#92400e'
                    }}>
                      {c.confidenceScore}%
                    </span>
                  </td>
                  <td style={{ maxWidth: '320px', whiteSpace: 'normal', fontSize: '13px' }}>
                    {c.flagReason}
                  </td>
                  <td>
                    <div style={{ fontSize: '12.5px' }}><strong>Cust:</strong> {c.customer}</div>
                    <div style={{ fontSize: '12px', color: '#64736a' }}><strong>Prov:</strong> {c.provider}</div>
                  </td>
                  <td>
                    <span className={`admin-badge ${
                      c.status === 'Approved' ? 'status-resolved' :
                      c.status === 'Rejected' ? 'priority-high' : 'status-waiting'
                    }`}>
                      {c.status}
                    </span>
                  </td>
                  <td>{c.timestamp}</td>
                  <td className="actions-col">
                    {c.status === 'Pending Review' ? (
                      <div style={{ display: 'inline-flex', gap: '6px' }}>
                        <button
                          type="button"
                          className="admin-btn admin-btn-primary"
                          style={{ padding: '4px 10px', fontSize: '12px' }}
                          onClick={() => handleAction(c.id, 'Approved')}
                        >
                          Approve
                        </button>
                        <button
                          type="button"
                          className="admin-btn admin-btn-secondary"
                          style={{ padding: '4px 10px', fontSize: '12px', color: '#c81e1e', borderColor: '#fecaca' }}
                          onClick={() => handleAction(c.id, 'Rejected')}
                        >
                          Reject
                        </button>
                      </div>
                    ) : (
                      <span style={{ fontSize: '12px', color: '#256b4a', fontWeight: 600 }}>Completed</span>
                    )}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>

        <div className="admin-table-footer">
          <div>Showing {cases.length} exception review records</div>
        </div>
      </div>
    </div>
  );
};
