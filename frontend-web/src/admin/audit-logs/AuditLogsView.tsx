import React, { useState } from 'react';

interface AuditLogEntry {
  id: string;
  actor: string;
  role: string;
  action: string;
  resource: string;
  ipAddress: string;
  status: 'Allowed' | 'Denied' | 'Flagged';
  timestamp: string;
}

const mockLogs: AuditLogEntry[] = [
  { id: 'LOG-4901', actor: 'Kavindu (Super Admin)', role: 'SuperAdmin', action: 'CREATE_ADMIN_ACCOUNT', resource: 'AdminUser/d9a8-2b', ipAddress: '192.168.1.42', status: 'Allowed', timestamp: '10 mins ago' },
  { id: 'LOG-4900', actor: 'Nimal Perera', role: 'Admin', action: 'VIEW_DISPUTE_TRANSCRIPT', resource: 'Inquiry/INQ-1042', ipAddress: '112.134.18.90', status: 'Allowed', timestamp: '25 mins ago' },
  { id: 'LOG-4899', actor: 'System Worker', role: 'SystemDaemon', action: 'ESCROW_RELEASE_EXECUTE', resource: 'Booking/BK-499', ipAddress: '10.0.4.12', status: 'Allowed', timestamp: '1 hour ago' },
  { id: 'LOG-4898', actor: 'Unknown Client', role: 'Anonymous', action: 'UNAUTHORIZED_ADMIN_LOGIN', resource: '/api/v1/auth/admin', ipAddress: '45.132.88.14', status: 'Denied', timestamp: '3 hours ago' },
  { id: 'LOG-4897', actor: 'Sahan (Admin)', role: 'Admin', action: 'TOGGLE_PROVIDER_STATUS', resource: 'Provider/PRV-105', ipAddress: '124.43.12.8', status: 'Allowed', timestamp: 'Yesterday' },
];

export const AuditLogsView: React.FC = () => {
  const [search, setSearch] = useState('');
  const [statusFilter, setStatusFilter] = useState('All');

  const filtered = mockLogs.filter(l => {
    const matchSearch = l.actor.toLowerCase().includes(search.toLowerCase()) ||
      l.action.toLowerCase().includes(search.toLowerCase()) ||
      l.resource.toLowerCase().includes(search.toLowerCase()) ||
      l.ipAddress.includes(search);
    const matchStat = statusFilter === 'All' || l.status === statusFilter;
    return matchSearch && matchStat;
  });

  return (
    <div className="admin-content">
      <div className="admin-page-header">
        <div>
          <h1 className="admin-page-title">Security & System Audit Logs</h1>
          <p className="admin-page-subtitle">
            Immutable, tamper-evident record of all administrative actions, permission mutations, and access telemetry.
          </p>
        </div>
        <button
          type="button"
          className="admin-export-btn"
          onClick={() => alert('Exporting cryptographic audit log (JSON/CSV)...')}
        >
          <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.2">
            <path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4" />
            <polyline points="7 10 12 15 17 10" />
            <line x1="12" y1="15" x2="12" y2="3" />
          </svg>
          Export Cryptographic Log
        </button>
      </div>

      <div className="admin-metrics-grid">
        <div className="admin-metric-card">
          <p className="admin-metric-label">Logged Events (24h)</p>
          <div className="admin-metric-value">4,120</div>
          <p className="admin-metric-note positive">100% captured</p>
        </div>
        <div className="admin-metric-card">
          <p className="admin-metric-label">Access Denials / Probes</p>
          <div className="admin-metric-value" style={{ color: '#c81e1e' }}>1</div>
          <p className="admin-metric-note">IP automatically blocked</p>
        </div>
        <div className="admin-metric-card">
          <p className="admin-metric-label">Administrative Mutations</p>
          <div className="admin-metric-value">14</div>
          <p className="admin-metric-note">Staff access alterations</p>
        </div>
        <div className="admin-metric-card">
          <p className="admin-metric-label">Integrity Verification</p>
          <div className="admin-metric-value">SHA-256</div>
          <p className="admin-metric-note positive">Hash chaining active</p>
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
              placeholder="Search action, actor, resource, IP address..."
              value={search}
              onChange={(e) => setSearch(e.target.value)}
            />
          </div>

          <select
            className="admin-filter-select"
            value={statusFilter}
            onChange={(e) => setStatusFilter(e.target.value)}
          >
            <option value="All">All Statuses</option>
            <option value="Allowed">Allowed</option>
            <option value="Denied">Denied</option>
            <option value="Flagged">Flagged</option>
          </select>
        </div>

        <div className="admin-table-container">
          <table className="admin-table">
            <thead>
              <tr>
                <th>Log ID</th>
                <th>Actor Name</th>
                <th>Role</th>
                <th>Security Action</th>
                <th>Target Resource</th>
                <th>Source IP</th>
                <th>Outcome</th>
                <th>Timestamp</th>
              </tr>
            </thead>
            <tbody>
              {filtered.map(l => (
                <tr key={l.id}>
                  <td><span className="admin-inquiry-code">{l.id}</span></td>
                  <td><strong>{l.actor}</strong></td>
                  <td><span className="admin-badge priority-normal">{l.role}</span></td>
                  <td><code>{l.action}</code></td>
                  <td><span style={{ fontFamily: 'monospace', color: '#113c2b' }}>{l.resource}</span></td>
                  <td><span style={{ fontFamily: 'monospace' }}>{l.ipAddress}</span></td>
                  <td>
                    <span className={`admin-badge ${
                      l.status === 'Allowed' ? 'status-resolved' :
                      l.status === 'Denied' ? 'priority-high' : 'status-waiting'
                    }`}>
                      {l.status}
                    </span>
                  </td>
                  <td>{l.timestamp}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>

        <div className="admin-table-footer">
          <div>Showing {filtered.length} of {mockLogs.length} audit entries</div>
        </div>
      </div>
    </div>
  );
};
