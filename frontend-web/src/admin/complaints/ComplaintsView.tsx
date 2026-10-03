import React, { useState } from 'react';

interface ComplaintRecord {
  id: string;
  customer: string;
  provider: string;
  bookingRef: string;
  category: 'Service Quality' | 'Late Arrival' | 'Professional Conduct' | 'Billing Dispute';
  severity: 'Critical' | 'Moderate' | 'Low';
  status: 'Investigating' | 'Mediation' | 'Refund Pending' | 'Closed';
  dateFiled: string;
}

const mockComplaints: ComplaintRecord[] = [
  { id: 'CMP-204', customer: 'Kavindi Senaratne', provider: 'Ruwan AC Repair', bookingRef: 'BK-462', category: 'Service Quality', severity: 'Critical', status: 'Investigating', dateFiled: 'Oct 01, 2026' },
  { id: 'CMP-203', customer: 'Janaka Dias', provider: 'Kamal Electricals', bookingRef: 'BK-455', category: 'Late Arrival', severity: 'Moderate', status: 'Mediation', dateFiled: 'Sep 29, 2026' },
  { id: 'CMP-202', customer: 'Maheshika Perera', provider: 'Express Cleaners', bookingRef: 'BK-440', category: 'Billing Dispute', severity: 'Moderate', status: 'Refund Pending', dateFiled: 'Sep 25, 2026' },
];

export const ComplaintsView: React.FC = () => {
  const [search, setSearch] = useState('');
  const [categoryFilter, setCategoryFilter] = useState('All');

  const filtered = mockComplaints.filter(c => {
    const matchSearch = c.id.toLowerCase().includes(search.toLowerCase()) ||
      c.customer.toLowerCase().includes(search.toLowerCase()) ||
      c.provider.toLowerCase().includes(search.toLowerCase()) ||
      c.bookingRef.toLowerCase().includes(search.toLowerCase());
    const matchCat = categoryFilter === 'All' || c.category === categoryFilter;
    return matchSearch && matchCat;
  });

  return (
    <div className="admin-content">
      <div className="admin-page-header">
        <div>
          <h1 className="admin-page-title">Customer Complaints</h1>
          <p className="admin-page-subtitle">
            Formal complaints, customer dissatisfaction escalation, and regulatory mediation workflows.
          </p>
        </div>
        <button
          type="button"
          className="admin-export-btn"
          onClick={() => alert('Exporting complaints logs...')}
        >
          <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.2">
            <path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4" />
            <polyline points="7 10 12 15 17 10" />
            <line x1="12" y1="15" x2="12" y2="3" />
          </svg>
          Export Complaints
        </button>
      </div>

      <div className="admin-metrics-grid">
        <div className="admin-metric-card">
          <p className="admin-metric-label">Active Investigations</p>
          <div className="admin-metric-value">3</div>
          <p className="admin-metric-note">Assigned to compliance officer</p>
        </div>
        <div className="admin-metric-card">
          <p className="admin-metric-label">Critical Tier</p>
          <div className="admin-metric-value" style={{ color: '#c81e1e' }}>1</div>
          <p className="admin-metric-note">Action required &lt; 2h</p>
        </div>
        <div className="admin-metric-card">
          <p className="admin-metric-label">Refunds Issued (Month)</p>
          <div className="admin-metric-value">LKR 12,500</div>
          <p className="admin-metric-note">0.4% of total marketplace GMV</p>
        </div>
        <div className="admin-metric-card">
          <p className="admin-metric-label">Provider Warning Strikes</p>
          <div className="admin-metric-value">2</div>
          <p className="admin-metric-note positive">Zero account suspensions</p>
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
              placeholder="Search complaint ID, customer, provider, booking..."
              value={search}
              onChange={(e) => setSearch(e.target.value)}
            />
          </div>

          <select
            className="admin-filter-select"
            value={categoryFilter}
            onChange={(e) => setCategoryFilter(e.target.value)}
          >
            <option value="All">All Categories</option>
            <option value="Service Quality">Service Quality</option>
            <option value="Late Arrival">Late Arrival</option>
            <option value="Billing Dispute">Billing Dispute</option>
          </select>
        </div>

        <div className="admin-table-container">
          <table className="admin-table">
            <thead>
              <tr>
                <th>Complaint #</th>
                <th>Complainant</th>
                <th>Provider Involved</th>
                <th>Booking Ref</th>
                <th>Category</th>
                <th>Severity</th>
                <th>Status</th>
                <th>Date Filed</th>
                <th className="actions-col">Actions</th>
              </tr>
            </thead>
            <tbody>
              {filtered.map(c => (
                <tr key={c.id}>
                  <td><span className="admin-inquiry-code">{c.id}</span></td>
                  <td><strong>{c.customer}</strong></td>
                  <td>{c.provider}</td>
                  <td><span style={{ fontFamily: 'monospace' }}>{c.bookingRef}</span></td>
                  <td>{c.category}</td>
                  <td>
                    <span className={`admin-badge ${c.severity === 'Critical' ? 'priority-high' : 'priority-normal'}`}>
                      {c.severity}
                    </span>
                  </td>
                  <td>
                    <span className={`admin-badge ${c.status === 'Closed' ? 'status-resolved' : 'status-open'}`}>
                      {c.status}
                    </span>
                  </td>
                  <td>{c.dateFiled}</td>
                  <td className="actions-col">
                    <button
                      type="button"
                      className="admin-btn admin-btn-secondary"
                      style={{ padding: '4px 10px', fontSize: '12px' }}
                      onClick={() => alert(`Reviewing complaint ${c.id}`)}
                    >
                      Mediate
                    </button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>

        <div className="admin-table-footer">
          <div>Showing {filtered.length} of {mockComplaints.length} complaint cases</div>
        </div>
      </div>
    </div>
  );
};
