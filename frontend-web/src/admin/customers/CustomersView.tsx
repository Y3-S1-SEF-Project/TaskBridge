import React, { useState } from 'react';

interface CustomerRecord {
  id: string;
  name: string;
  email: string;
  phone: string;
  district: string;
  bookingsCount: number;
  totalSpent: string;
  status: 'Active' | 'Inactive' | 'Flagged';
  joinedDate: string;
}

const mockCustomers: CustomerRecord[] = [
  { id: 'CUST-301', name: 'Dilshan Silva', email: 'dilshan.silva@gmail.com', phone: '+94 77 234 5678', district: 'Colombo', bookingsCount: 8, totalSpent: 'LKR 46,200', status: 'Active', joinedDate: 'Aug 2026' },
  { id: 'CUST-302', name: 'Anuki Fernando', email: 'anuki.f@outlook.com', phone: '+94 71 888 9900', district: 'Gampaha', bookingsCount: 5, totalSpent: 'LKR 28,500', status: 'Active', joinedDate: 'Jul 2026' },
  { id: 'CUST-303', name: 'Sahan Wickrama', email: 'sahan.wick@yahoo.com', phone: '+94 76 112 3344', district: 'Kalutara', bookingsCount: 12, totalSpent: 'LKR 84,000', status: 'Active', joinedDate: 'May 2026' },
  { id: 'CUST-304', name: 'Nadeesha Peiris', email: 'nadeesha.peiris@gmail.com', phone: '+94 72 445 6677', district: 'Colombo', bookingsCount: 2, totalSpent: 'LKR 9,500', status: 'Active', joinedDate: 'Sep 2026' },
  { id: 'CUST-305', name: 'Kasun Bandara', email: 'kasun.b@hotmail.com', phone: '+94 70 778 9911', district: 'Kandy', bookingsCount: 1, totalSpent: 'LKR 12,000', status: 'Inactive', joinedDate: 'Sep 2026' },
];

export const CustomersView: React.FC = () => {
  const [search, setSearch] = useState('');
  const [statusFilter, setStatusFilter] = useState('All');

  const filtered = mockCustomers.filter(c => {
    const matchSearch = c.name.toLowerCase().includes(search.toLowerCase()) ||
      c.email.toLowerCase().includes(search.toLowerCase()) ||
      c.phone.includes(search) ||
      c.district.toLowerCase().includes(search.toLowerCase());
    const matchStat = statusFilter === 'All' || c.status === statusFilter;
    return matchSearch && matchStat;
  });

  return (
    <div className="admin-content">
      <div className="admin-page-header">
        <div>
          <h1 className="admin-page-title">Marketplace Customers</h1>
          <p className="admin-page-subtitle">
            Registered customer accounts, booking engagement history, lifetime value, and support preferences.
          </p>
        </div>
        <button
          type="button"
          className="admin-export-btn"
          onClick={() => alert('Exporting customer data...')}
        >
          <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.2">
            <path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4" />
            <polyline points="7 10 12 15 17 10" />
            <line x1="12" y1="15" x2="12" y2="3" />
          </svg>
          Export Customers
        </button>
      </div>

      <div className="admin-metrics-grid">
        <div className="admin-metric-card">
          <p className="admin-metric-label">Total Customers</p>
          <div className="admin-metric-value">1,482</div>
          <p className="admin-metric-note positive">+118 this month</p>
        </div>
        <div className="admin-metric-card">
          <p className="admin-metric-label">Active Repeat Bookers</p>
          <div className="admin-metric-value">64%</div>
          <p className="admin-metric-note positive">&gt; 2 bookings</p>
        </div>
        <div className="admin-metric-card">
          <p className="admin-metric-label">Avg Lifetime Value</p>
          <div className="admin-metric-value">LKR 28.4k</div>
          <p className="admin-metric-note">+8.4% vs last quarter</p>
        </div>
        <div className="admin-metric-card">
          <p className="admin-metric-label">Account Health</p>
          <div className="admin-metric-value">99.2%</div>
          <p className="admin-metric-note positive">Zero fraudulent chargebacks</p>
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
              placeholder="Search customer name, email, phone, district..."
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
            <option value="Active">Active</option>
            <option value="Inactive">Inactive</option>
            <option value="Flagged">Flagged</option>
          </select>
        </div>

        <div className="admin-table-container">
          <table className="admin-table">
            <thead>
              <tr>
                <th>Customer</th>
                <th>Email Address</th>
                <th>Phone</th>
                <th>District</th>
                <th>Total Jobs</th>
                <th>Total Spend</th>
                <th>Status</th>
                <th>Joined</th>
                <th className="actions-col">Actions</th>
              </tr>
            </thead>
            <tbody>
              {filtered.map(c => (
                <tr key={c.id}>
                  <td>
                    <strong>{c.name}</strong>
                    <div style={{ fontSize: '11.5px', color: '#8a9990' }}>{c.id}</div>
                  </td>
                  <td>{c.email}</td>
                  <td>{c.phone}</td>
                  <td>{c.district}</td>
                  <td><strong>{c.bookingsCount}</strong></td>
                  <td><strong>{c.totalSpent}</strong></td>
                  <td>
                    <span className={`admin-badge ${c.status === 'Active' ? 'status-resolved' : 'priority-normal'}`}>
                      {c.status}
                    </span>
                  </td>
                  <td>{c.joinedDate}</td>
                  <td className="actions-col">
                    <button
                      type="button"
                      className="admin-btn admin-btn-secondary"
                      style={{ padding: '4px 10px', fontSize: '12px' }}
                      onClick={() => alert(`Reviewing Customer ${c.name}`)}
                    >
                      History
                    </button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>

        <div className="admin-table-footer">
          <div>Showing {filtered.length} of {mockCustomers.length} registered customers</div>
        </div>
      </div>
    </div>
  );
};
