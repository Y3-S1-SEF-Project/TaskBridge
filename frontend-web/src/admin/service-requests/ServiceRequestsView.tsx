import React, { useState } from 'react';

interface ServiceRequestItem {
  id: string;
  customerName: string;
  category: string;
  urgency: 'Immediate' | 'Scheduled' | 'Flexible';
  budget: string;
  provider: string;
  status: 'Open' | 'Matching' | 'Quoted' | 'In Progress' | 'Completed';
  createdAt: string;
}

const mockRequests: ServiceRequestItem[] = [
  { id: 'SR-8092', customerName: 'Dilshan Silva', category: 'Plumbing', urgency: 'Immediate', budget: 'LKR 4,500', provider: 'Auto-matching...', status: 'Matching', createdAt: '10 mins ago' },
  { id: 'SR-8091', customerName: 'Anuki Fernando', category: 'Electrical', urgency: 'Scheduled', budget: 'LKR 8,000', provider: 'Kamal Perera', status: 'Quoted', createdAt: '25 mins ago' },
  { id: 'SR-8090', customerName: 'Sahan Wickrama', category: 'AC Repair', urgency: 'Immediate', budget: 'LKR 6,500', provider: 'Ruwan Air-con', status: 'In Progress', createdAt: '1 hour ago' },
  { id: 'SR-8089', customerName: 'Nadeesha Peiris', category: 'Cleaning', urgency: 'Flexible', budget: 'LKR 3,500', provider: 'Unassigned', status: 'Open', createdAt: '2 hours ago' },
  { id: 'SR-8088', customerName: 'Kasun Bandara', category: 'Carpentry', urgency: 'Scheduled', budget: 'LKR 12,000', provider: 'Sunil Crafts', status: 'Completed', createdAt: 'Yesterday' },
];

export const ServiceRequestsView: React.FC = () => {
  const [search, setSearch] = useState('');
  const [filterCategory, setFilterCategory] = useState('All');
  const [filterStatus, setFilterStatus] = useState('All');

  const filtered = mockRequests.filter(req => {
    const matchSearch = req.id.toLowerCase().includes(search.toLowerCase()) ||
      req.customerName.toLowerCase().includes(search.toLowerCase()) ||
      req.provider.toLowerCase().includes(search.toLowerCase());
    const matchCat = filterCategory === 'All' || req.category === filterCategory;
    const matchStat = filterStatus === 'All' || req.status === filterStatus;
    return matchSearch && matchCat && matchStat;
  });

  return (
    <div className="admin-content">
      <div className="admin-page-header">
        <div>
          <h1 className="admin-page-title">Service Requests</h1>
          <p className="admin-page-subtitle">
            Customer work requests, quotes, and active provider bids across the island.
          </p>
        </div>
        <button
          type="button"
          className="admin-export-btn"
          onClick={() => alert('Exporting Service Requests report (CSV)...')}
        >
          <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.2">
            <path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4" />
            <polyline points="7 10 12 15 17 10" />
            <line x1="12" y1="15" x2="12" y2="3" />
          </svg>
          Export Requests
        </button>
      </div>

      {/* Metrics Grid */}
      <div className="admin-metrics-grid">
        <div className="admin-metric-card">
          <p className="admin-metric-label">Total Requests (Today)</p>
          <div className="admin-metric-value">26</div>
          <p className="admin-metric-note positive">+14% vs yesterday</p>
        </div>
        <div className="admin-metric-card">
          <p className="admin-metric-label">Matching in Progress</p>
          <div className="admin-metric-value">7</div>
          <p className="admin-metric-note">Avg match time: 4.2m</p>
        </div>
        <div className="admin-metric-card">
          <p className="admin-metric-label">Active Provider Bids</p>
          <div className="admin-metric-value">19</div>
          <p className="admin-metric-note">3.1 bids / request</p>
        </div>
        <div className="admin-metric-card">
          <p className="admin-metric-label">Unfulfilled / Expired</p>
          <div className="admin-metric-value">0</div>
          <p className="admin-metric-note positive">100% fulfillment rate</p>
        </div>
      </div>

      {/* Table Card */}
      <div className="admin-table-card">
        <div className="admin-toolbar" style={{ padding: '20px 24px 16px' }}>
          <div className="admin-search-box">
            <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
              <circle cx="11" cy="11" r="8" />
              <line x1="21" y1="21" x2="16.65" y2="16.65" />
            </svg>
            <input
              type="text"
              placeholder="Search request ID, customer, provider..."
              value={search}
              onChange={(e) => setSearch(e.target.value)}
            />
          </div>

          <div style={{ display: 'flex', gap: '10px' }}>
            <select
              className="admin-filter-select"
              value={filterCategory}
              onChange={(e) => setFilterCategory(e.target.value)}
            >
              <option value="All">All Categories</option>
              <option value="Plumbing">Plumbing</option>
              <option value="Electrical">Electrical</option>
              <option value="AC Repair">AC Repair</option>
              <option value="Cleaning">Cleaning</option>
              <option value="Carpentry">Carpentry</option>
            </select>

            <select
              className="admin-filter-select"
              value={filterStatus}
              onChange={(e) => setFilterStatus(e.target.value)}
            >
              <option value="All">All Statuses</option>
              <option value="Open">Open</option>
              <option value="Matching">Matching</option>
              <option value="Quoted">Quoted</option>
              <option value="In Progress">In Progress</option>
              <option value="Completed">Completed</option>
            </select>
          </div>
        </div>

        <div className="admin-table-container">
          <table className="admin-table">
            <thead>
              <tr>
                <th>Request ID</th>
                <th>Customer</th>
                <th>Category</th>
                <th>Urgency</th>
                <th>Budget</th>
                <th>Assigned Provider</th>
                <th>Status</th>
                <th>Created</th>
                <th className="actions-col">Actions</th>
              </tr>
            </thead>
            <tbody>
              {filtered.map(req => (
                <tr key={req.id}>
                  <td>
                    <span className="admin-inquiry-code">{req.id}</span>
                  </td>
                  <td><strong>{req.customerName}</strong></td>
                  <td>{req.category}</td>
                  <td>
                    <span className={`admin-badge ${req.urgency === 'Immediate' ? 'priority-high' : 'priority-normal'}`}>
                      {req.urgency}
                    </span>
                  </td>
                  <td><strong>{req.budget}</strong></td>
                  <td>{req.provider}</td>
                  <td>
                    <span className={`admin-badge ${
                      req.status === 'Completed' ? 'status-resolved' :
                      req.status === 'In Progress' ? 'status-in-progress' :
                      req.status === 'Matching' ? 'status-open' : 'priority-normal'
                    }`}>
                      {req.status}
                    </span>
                  </td>
                  <td>{req.createdAt}</td>
                  <td className="actions-col">
                    <button
                      type="button"
                      className="admin-btn admin-btn-secondary"
                      style={{ padding: '4px 10px', fontSize: '12px' }}
                      onClick={() => alert(`Inspecting request ${req.id}`)}
                    >
                      Details
                    </button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>

        <div className="admin-table-footer">
          <div>Showing {filtered.length} of {mockRequests.length} requests</div>
        </div>
      </div>
    </div>
  );
};
