import React, { useState } from 'react';

interface InquiryItem {
  id: string;
  subject: string;
  raisedBy: string;
  role: 'Customer' | 'Provider';
  relatedJob: string;
  priority: 'High' | 'Normal' | 'Low';
  status: 'Open' | 'In Progress' | 'Waiting Response' | 'Resolved';
  lastUpdated: string;
}

const mockInquiries: InquiryItem[] = [
  { id: 'INQ-1042', subject: 'Dispute over extra electrical materials cost', raisedBy: 'Sahan Wickrama', role: 'Customer', relatedJob: 'BK-495', priority: 'High', status: 'Open', lastUpdated: '12 mins ago' },
  { id: 'INQ-1041', subject: 'Customer rescheduled last minute without notice', raisedBy: 'Nimal Perera', role: 'Provider', relatedJob: 'BK-489', priority: 'Normal', status: 'In Progress', lastUpdated: '1 hour ago' },
  { id: 'INQ-1040', subject: 'Question regarding platform payout settlement cycle', raisedBy: 'Sunil Crafts', role: 'Provider', relatedJob: 'N/A', priority: 'Low', status: 'Waiting Response', lastUpdated: '3 hours ago' },
  { id: 'INQ-1039', subject: 'Plumbing job completed but invoice discrepancy', raisedBy: 'Anuki Fernando', role: 'Customer', relatedJob: 'BK-470', priority: 'Normal', status: 'Resolved', lastUpdated: 'Yesterday' },
];

export const InquiriesView: React.FC = () => {
  const [search, setSearch] = useState('');
  const [priorityFilter, setPriorityFilter] = useState('All');
  const [statusFilter, setStatusFilter] = useState('All');

  const filtered = mockInquiries.filter(i => {
    const matchSearch = i.id.toLowerCase().includes(search.toLowerCase()) ||
      i.subject.toLowerCase().includes(search.toLowerCase()) ||
      i.raisedBy.toLowerCase().includes(search.toLowerCase()) ||
      i.relatedJob.toLowerCase().includes(search.toLowerCase());
    const matchPri = priorityFilter === 'All' || i.priority === priorityFilter;
    const matchStat = statusFilter === 'All' || i.status === statusFilter;
    return matchSearch && matchPri && matchStat;
  });

  return (
    <div className="admin-content">
      <div className="admin-page-header">
        <div>
          <h1 className="admin-page-title">Dispute & Support Inquiries</h1>
          <p className="admin-page-subtitle">
            Escalations, billing clarifications, and dispute resolution records requiring administrative action.
          </p>
        </div>
        <button
          type="button"
          className="admin-export-btn"
          onClick={() => alert('Exporting inquiries report...')}
        >
          <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.2">
            <path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4" />
            <polyline points="7 10 12 15 17 10" />
            <line x1="12" y1="15" x2="12" y2="3" />
          </svg>
          Export Inquiries
        </button>
      </div>

      <div className="admin-metrics-grid">
        <div className="admin-metric-card">
          <p className="admin-metric-label">Open Inquiries</p>
          <div className="admin-metric-value">3</div>
          <p className="admin-metric-note">2 require supervisor triage</p>
        </div>
        <div className="admin-metric-card">
          <p className="admin-metric-label">High Priority Escalations</p>
          <div className="admin-metric-value" style={{ color: '#c81e1e' }}>1</div>
          <p className="admin-metric-note">Under 15m SLA target</p>
        </div>
        <div className="admin-metric-card">
          <p className="admin-metric-label">Avg First Response</p>
          <div className="admin-metric-value">18m</div>
          <p className="admin-metric-note positive">Target: under 30m</p>
        </div>
        <div className="admin-metric-card">
          <p className="admin-metric-label">Resolution Rate (30d)</p>
          <div className="admin-metric-value">94.8%</div>
          <p className="admin-metric-note positive">+2.1% improvement</p>
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
              placeholder="Search inquiry #, subject, user, booking..."
              value={search}
              onChange={(e) => setSearch(e.target.value)}
            />
          </div>

          <div style={{ display: 'flex', gap: '10px' }}>
            <select
              className="admin-filter-select"
              value={priorityFilter}
              onChange={(e) => setPriorityFilter(e.target.value)}
            >
              <option value="All">All Priorities</option>
              <option value="High">High</option>
              <option value="Normal">Normal</option>
              <option value="Low">Low</option>
            </select>

            <select
              className="admin-filter-select"
              value={statusFilter}
              onChange={(e) => setStatusFilter(e.target.value)}
            >
              <option value="All">All Statuses</option>
              <option value="Open">Open</option>
              <option value="In Progress">In Progress</option>
              <option value="Waiting Response">Waiting Response</option>
              <option value="Resolved">Resolved</option>
            </select>
          </div>
        </div>

        <div className="admin-table-container">
          <table className="admin-table">
            <thead>
              <tr>
                <th>Ticket ID</th>
                <th>Inquiry Subject</th>
                <th>Raised By</th>
                <th>User Type</th>
                <th>Related Job</th>
                <th>Priority</th>
                <th>Status</th>
                <th>Updated</th>
                <th className="actions-col">Actions</th>
              </tr>
            </thead>
            <tbody>
              {filtered.map(item => (
                <tr key={item.id}>
                  <td>
                    <span className="admin-inquiry-code">{item.id}</span>
                  </td>
                  <td><strong>{item.subject}</strong></td>
                  <td>{item.raisedBy}</td>
                  <td>
                    <span className="admin-badge priority-normal">{item.role}</span>
                  </td>
                  <td>
                    <span style={{ fontFamily: 'monospace', fontWeight: 600 }}>{item.relatedJob}</span>
                  </td>
                  <td>
                    <span className={`admin-badge ${
                      item.priority === 'High' ? 'priority-high' :
                      item.priority === 'Normal' ? 'priority-normal' : 'priority-low'
                    }`}>
                      {item.priority}
                    </span>
                  </td>
                  <td>
                    <span className={`admin-badge ${
                      item.status === 'Resolved' ? 'status-resolved' :
                      item.status === 'In Progress' ? 'status-in-progress' :
                      item.status === 'Open' ? 'status-open' : 'status-waiting'
                    }`}>
                      {item.status}
                    </span>
                  </td>
                  <td>{item.lastUpdated}</td>
                  <td className="actions-col">
                    <button
                      type="button"
                      className="admin-btn admin-btn-secondary"
                      style={{ padding: '4px 10px', fontSize: '12px' }}
                      onClick={() => alert(`Reviewing Inquiry ${item.id}`)}
                    >
                      Resolve
                    </button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>

        <div className="admin-table-footer">
          <div>Showing {filtered.length} of {mockInquiries.length} tickets</div>
        </div>
      </div>
    </div>
  );
};
