import React, { useState } from 'react';

interface ProviderRecord {
  id: string;
  name: string;
  category: string;
  phone: string;
  location: string;
  rating: number;
  completedJobs: number;
  kycStatus: 'Verified' | 'Pending Review' | 'Rejected';
  accountStatus: 'Active' | 'Under Review' | 'Suspended';
}

const mockProviders: ProviderRecord[] = [
  { id: 'PRV-101', name: 'Kamal Perera', category: 'Electrical', phone: '+94 77 123 4567', location: 'Colombo 03', rating: 4.9, completedJobs: 48, kycStatus: 'Verified', accountStatus: 'Active' },
  { id: 'PRV-102', name: 'Sunil Crafts & Woodwork', category: 'Carpentry', phone: '+94 71 987 6543', location: 'Nugegoda', rating: 4.8, completedJobs: 32, kycStatus: 'Verified', accountStatus: 'Active' },
  { id: 'PRV-103', name: 'Ruwan Air-con Specialists', category: 'AC Repair', phone: '+94 76 555 1234', location: 'Dehiwala', rating: 4.7, completedJobs: 65, kycStatus: 'Verified', accountStatus: 'Active' },
  { id: 'PRV-104', name: 'Saman Kumara', category: 'Plumbing', phone: '+94 72 333 8899', location: 'Kaduwela', rating: 4.5, completedJobs: 14, kycStatus: 'Pending Review', accountStatus: 'Under Review' },
  { id: 'PRV-105', name: 'City Spark Solutions', category: 'Electrical', phone: '+94 77 900 1122', location: 'Moratuwa', rating: 3.8, completedJobs: 9, kycStatus: 'Rejected', accountStatus: 'Suspended' },
];

export const ProvidersView: React.FC = () => {
  const [search, setSearch] = useState('');
  const [categoryFilter, setCategoryFilter] = useState('All');
  const [statusFilter, setStatusFilter] = useState('All');

  const filtered = mockProviders.filter(p => {
    const matchSearch = p.name.toLowerCase().includes(search.toLowerCase()) ||
      p.category.toLowerCase().includes(search.toLowerCase()) ||
      p.phone.includes(search) ||
      p.location.toLowerCase().includes(search.toLowerCase());
    const matchCat = categoryFilter === 'All' || p.category === categoryFilter;
    const matchStat = statusFilter === 'All' || p.accountStatus === statusFilter;
    return matchSearch && matchCat && matchStat;
  });

  return (
    <div className="admin-content">
      <div className="admin-page-header">
        <div>
          <h1 className="admin-page-title">Service Providers</h1>
          <p className="admin-page-subtitle">
            Verified trade specialists, background checks, credentials vetting, and active performance telemetry.
          </p>
        </div>
        <button
          type="button"
          className="admin-btn admin-btn-primary"
          onClick={() => alert('Open Provider Onboarding Modal...')}
        >
          + Add New Provider
        </button>
      </div>

      <div className="admin-metrics-grid">
        <div className="admin-metric-card">
          <p className="admin-metric-label">Total Providers</p>
          <div className="admin-metric-value">124</div>
          <p className="admin-metric-note positive">+8 joined this month</p>
        </div>
        <div className="admin-metric-card">
          <p className="admin-metric-label">Verified & Active</p>
          <div className="admin-metric-value">116</div>
          <p className="admin-metric-note positive">93.5% verified rate</p>
        </div>
        <div className="admin-metric-card">
          <p className="admin-metric-label">Pending KYC Verification</p>
          <div className="admin-metric-value">6</div>
          <p className="admin-metric-note">NIC & police clearance review</p>
        </div>
        <div className="admin-metric-card">
          <p className="admin-metric-label">Platform Average Rating</p>
          <div className="admin-metric-value">4.82 ★</div>
          <p className="admin-metric-note positive">Top-tier service standard</p>
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
              placeholder="Search provider name, trade, location, phone..."
              value={search}
              onChange={(e) => setSearch(e.target.value)}
            />
          </div>

          <div style={{ display: 'flex', gap: '10px' }}>
            <select
              className="admin-filter-select"
              value={categoryFilter}
              onChange={(e) => setCategoryFilter(e.target.value)}
            >
              <option value="All">All Trades</option>
              <option value="Electrical">Electrical</option>
              <option value="Carpentry">Carpentry</option>
              <option value="AC Repair">AC Repair</option>
              <option value="Plumbing">Plumbing</option>
            </select>

            <select
              className="admin-filter-select"
              value={statusFilter}
              onChange={(e) => setStatusFilter(e.target.value)}
            >
              <option value="All">All Statuses</option>
              <option value="Active">Active</option>
              <option value="Under Review">Under Review</option>
              <option value="Suspended">Suspended</option>
            </select>
          </div>
        </div>

        <div className="admin-table-container">
          <table className="admin-table">
            <thead>
              <tr>
                <th>Provider</th>
                <th>Trade Category</th>
                <th>Contact</th>
                <th>Area</th>
                <th>Rating</th>
                <th>Jobs Done</th>
                <th>KYC Verification</th>
                <th>Account</th>
                <th className="actions-col">Actions</th>
              </tr>
            </thead>
            <tbody>
              {filtered.map(p => (
                <tr key={p.id}>
                  <td>
                    <strong>{p.name}</strong>
                    <div style={{ fontSize: '11.5px', color: '#8a9990' }}>{p.id}</div>
                  </td>
                  <td>{p.category}</td>
                  <td>{p.phone}</td>
                  <td>{p.location}</td>
                  <td>
                    <span style={{ fontWeight: 600, color: '#256b4a' }}>★ {p.rating}</span>
                  </td>
                  <td><strong>{p.completedJobs}</strong></td>
                  <td>
                    <span className={`admin-badge ${
                      p.kycStatus === 'Verified' ? 'status-resolved' :
                      p.kycStatus === 'Pending Review' ? 'status-waiting' : 'priority-high'
                    }`}>
                      {p.kycStatus}
                    </span>
                  </td>
                  <td>
                    <span className={`admin-badge ${
                      p.accountStatus === 'Active' ? 'status-resolved' :
                      p.accountStatus === 'Under Review' ? 'status-open' : 'priority-high'
                    }`}>
                      {p.accountStatus}
                    </span>
                  </td>
                  <td className="actions-col">
                    <button
                      type="button"
                      className="admin-btn admin-btn-secondary"
                      style={{ padding: '4px 10px', fontSize: '12px' }}
                      onClick={() => alert(`Reviewing Provider ${p.name}`)}
                    >
                      Profile
                    </button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>

        <div className="admin-table-footer">
          <div>Showing {filtered.length} of {mockProviders.length} providers</div>
        </div>
      </div>
    </div>
  );
};
