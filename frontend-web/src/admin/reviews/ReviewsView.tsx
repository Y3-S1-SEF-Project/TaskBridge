import React, { useState } from 'react';

interface ReviewRecord {
  id: string;
  customerName: string;
  providerName: string;
  service: string;
  rating: number;
  comment: string;
  sentiment: 'Positive' | 'Neutral' | 'Negative';
  status: 'Approved' | 'Flagged' | 'Pending Review';
  date: string;
}

const mockReviews: ReviewRecord[] = [
  { id: 'REV-901', customerName: 'Dilshan Silva', providerName: 'Kamal Perera', service: 'Electrical', rating: 5, comment: 'Arrived promptly and diagnosed the short circuit in 15 minutes. Very professional!', sentiment: 'Positive', status: 'Approved', date: 'Oct 01, 2026' },
  { id: 'REV-900', customerName: 'Anuki Fernando', providerName: 'Sunil Crafts', service: 'Carpentry', rating: 5, comment: 'Superb table repair work, completely seamless polish.', sentiment: 'Positive', status: 'Approved', date: 'Sep 30, 2026' },
  { id: 'REV-899', customerName: 'Sahan Wickrama', providerName: 'Ruwan Air-con', service: 'AC Repair', rating: 4, comment: 'Good cooling performance, though provider was 20 minutes behind schedule.', sentiment: 'Neutral', status: 'Approved', date: 'Sep 29, 2026' },
  { id: 'REV-898', customerName: 'Anonymous Customer', providerName: 'Quick Plumbers', service: 'Plumbing', rating: 1, comment: 'Inappropriate language used when discussing labor charges. Please inspect.', sentiment: 'Negative', status: 'Flagged', date: 'Sep 28, 2026' },
];

export const ReviewsView: React.FC = () => {
  const [search, setSearch] = useState('');
  const [statusFilter, setStatusFilter] = useState('All');

  const filtered = mockReviews.filter(r => {
    const matchSearch = r.customerName.toLowerCase().includes(search.toLowerCase()) ||
      r.providerName.toLowerCase().includes(search.toLowerCase()) ||
      r.comment.toLowerCase().includes(search.toLowerCase()) ||
      r.service.toLowerCase().includes(search.toLowerCase());
    const matchStat = statusFilter === 'All' || r.status === statusFilter;
    return matchSearch && matchStat;
  });

  return (
    <div className="admin-content">
      <div className="admin-page-header">
        <div>
          <h1 className="admin-page-title">Feedback & Reviews</h1>
          <p className="admin-page-subtitle">
            Customer reviews, ratings moderation, sentiment analysis, and authenticity vetting.
          </p>
        </div>
        <button
          type="button"
          className="admin-export-btn"
          onClick={() => alert('Exporting feedback logs...')}
        >
          <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.2">
            <path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4" />
            <polyline points="7 10 12 15 17 10" />
            <line x1="12" y1="15" x2="12" y2="3" />
          </svg>
          Export Reviews
        </button>
      </div>

      <div className="admin-metrics-grid">
        <div className="admin-metric-card">
          <p className="admin-metric-label">Total Verified Reviews</p>
          <div className="admin-metric-value">428</div>
          <p className="admin-metric-note positive">98% booking verified</p>
        </div>
        <div className="admin-metric-card">
          <p className="admin-metric-label">Overall Platform Rating</p>
          <div className="admin-metric-value">4.86 ★</div>
          <p className="admin-metric-note positive">88% 5-star ratio</p>
        </div>
        <div className="admin-metric-card">
          <p className="admin-metric-label">Flagged for Moderation</p>
          <div className="admin-metric-value" style={{ color: '#c81e1e' }}>1</div>
          <p className="admin-metric-note">Profanity / conduct alert</p>
        </div>
        <div className="admin-metric-card">
          <p className="admin-metric-label">Positive Sentiment Rate</p>
          <div className="admin-metric-value">92.4%</div>
          <p className="admin-metric-note positive">Natural language analyzed</p>
        </div>
      </div>

      <div className="admin-table-card">
        <div className="admin-toolbar" style={{ padding: '20px 24px 16px' }}>
          <div className="admin-search-box">
            <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
              <circle cx="11" cy="11" r="8" />
              <line x1="21" y1="21" x2="16.65" y2="16.65" />
            </svg>
            <input
              type="text"
              placeholder="Search reviewer, provider, service, feedback keywords..."
              value={search}
              onChange={(e) => setSearch(e.target.value)}
            />
          </div>

          <select
            className="admin-filter-select"
            value={statusFilter}
            onChange={(e) => setStatusFilter(e.target.value)}
          >
            <option value="All">All Reviews</option>
            <option value="Approved">Approved</option>
            <option value="Flagged">Flagged</option>
            <option value="Pending Review">Pending Review</option>
          </select>
        </div>

        <div className="admin-table-container">
          <table className="admin-table">
            <thead>
              <tr>
                <th>Review ID</th>
                <th>Reviewer</th>
                <th>Provider</th>
                <th>Trade</th>
                <th>Rating</th>
                <th>Customer Feedback</th>
                <th>Sentiment</th>
                <th>Status</th>
                <th className="actions-col">Moderation</th>
              </tr>
            </thead>
            <tbody>
              {filtered.map(r => (
                <tr key={r.id}>
                  <td><span className="admin-inquiry-code">{r.id}</span></td>
                  <td><strong>{r.customerName}</strong></td>
                  <td>{r.providerName}</td>
                  <td>{r.service}</td>
                  <td>
                    <span style={{ fontWeight: 700, color: r.rating >= 4 ? '#256b4a' : '#c81e1e' }}>
                      {'★'.repeat(r.rating)}
                    </span>
                  </td>
                  <td style={{ maxWidth: '320px', whiteSpace: 'normal' }}>
                    <p style={{ margin: 0, fontSize: '13px', color: '#141f19' }}>"{r.comment}"</p>
                    <span style={{ fontSize: '11px', color: '#8a9990' }}>{r.date}</span>
                  </td>
                  <td>
                    <span className={`admin-badge ${
                      r.sentiment === 'Positive' ? 'status-resolved' :
                      r.sentiment === 'Neutral' ? 'priority-normal' : 'priority-high'
                    }`}>
                      {r.sentiment}
                    </span>
                  </td>
                  <td>
                    <span className={`admin-badge ${
                      r.status === 'Approved' ? 'status-resolved' :
                      r.status === 'Flagged' ? 'priority-high' : 'status-waiting'
                    }`}>
                      {r.status}
                    </span>
                  </td>
                  <td className="actions-col">
                    <div style={{ display: 'inline-flex', gap: '6px' }}>
                      {r.status === 'Flagged' && (
                        <button
                          type="button"
                          className="admin-btn admin-btn-secondary"
                          style={{ padding: '4px 8px', fontSize: '11px', color: '#c81e1e', borderColor: '#fecaca' }}
                          onClick={() => alert(`Review ${r.id} hidden from public directory`)}
                        >
                          Hide
                        </button>
                      )}
                      <button
                        type="button"
                        className="admin-btn admin-btn-secondary"
                        style={{ padding: '4px 8px', fontSize: '11px' }}
                        onClick={() => alert(`Review ${r.id} approved`)}
                      >
                        Approve
                      </button>
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>

        <div className="admin-table-footer">
          <div>Showing {filtered.length} of {mockReviews.length} moderation records</div>
        </div>
      </div>
    </div>
  );
};
