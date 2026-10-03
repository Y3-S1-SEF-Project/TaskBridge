import React, { useState } from 'react';

interface BookingRecord {
  id: string;
  service: string;
  customer: string;
  provider: string;
  scheduledTime: string;
  escrowAmount: string;
  escrowStatus: 'Held in Escrow' | 'Released' | 'Refunded';
  bookingStatus: 'Confirmed' | 'In Progress' | 'Completed' | 'Pending Verification';
}

const mockBookings: BookingRecord[] = [
  { id: 'BK-501', service: 'Deep Home Cleaning', customer: 'Sithara Fernando', provider: 'Nuwan Cleaners', scheduledTime: 'Today, 2:00 PM', escrowAmount: 'LKR 6,000', escrowStatus: 'Held in Escrow', bookingStatus: 'In Progress' },
  { id: 'BK-500', service: 'Main Distribution Box Rewiring', customer: 'Rohan Jayasinghe', provider: 'Sanjaya Electricals', scheduledTime: 'Today, 4:30 PM', escrowAmount: 'LKR 14,500', escrowStatus: 'Held in Escrow', bookingStatus: 'Confirmed' },
  { id: 'BK-499', service: 'Bathroom Leakage Repair', customer: 'Malik De Silva', provider: 'Sunil Plumbing Service', scheduledTime: 'Yesterday, 10:00 AM', escrowAmount: 'LKR 5,200', escrowStatus: 'Released', bookingStatus: 'Completed' },
  { id: 'BK-498', service: 'Inverter AC Gas Refill', customer: 'Chathura Alwis', provider: 'CoolTech Air Conditioning', scheduledTime: 'Oct 01, 11:30 AM', escrowAmount: 'LKR 7,800', escrowStatus: 'Released', bookingStatus: 'Completed' },
];

export const BookingsView: React.FC = () => {
  const [search, setSearch] = useState('');
  const [statusFilter, setStatusFilter] = useState('All');

  const filtered = mockBookings.filter(b => {
    const matchSearch = b.id.toLowerCase().includes(search.toLowerCase()) ||
      b.service.toLowerCase().includes(search.toLowerCase()) ||
      b.customer.toLowerCase().includes(search.toLowerCase()) ||
      b.provider.toLowerCase().includes(search.toLowerCase());
    const matchStatus = statusFilter === 'All' || b.bookingStatus === statusFilter;
    return matchSearch && matchStatus;
  });

  return (
    <div className="admin-content">
      <div className="admin-page-header">
        <div>
          <h1 className="admin-page-title">Bookings & Jobs</h1>
          <p className="admin-page-subtitle">
            Scheduled, active, and completed marketplace jobs with real-time milestone telemetry.
          </p>
        </div>
        <button
          type="button"
          className="admin-export-btn"
          onClick={() => alert('Exporting bookings history (CSV/PDF)...')}
        >
          <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.2">
            <path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4" />
            <polyline points="7 10 12 15 17 10" />
            <line x1="12" y1="15" x2="12" y2="3" />
          </svg>
          Export Jobs
        </button>
      </div>

      <div className="admin-metrics-grid">
        <div className="admin-metric-card">
          <p className="admin-metric-label">Active Jobs On-Site</p>
          <div className="admin-metric-value">12</div>
          <p className="admin-metric-note positive">All GPS track verified</p>
        </div>
        <div className="admin-metric-card">
          <p className="admin-metric-label">Scheduled Today</p>
          <div className="admin-metric-value">8</div>
          <p className="admin-metric-note">Next starts at 2:00 PM</p>
        </div>
        <div className="admin-metric-card">
          <p className="admin-metric-label">Escrow Funds Protected</p>
          <div className="admin-metric-value">LKR 182k</div>
          <p className="admin-metric-note">Locked pending sign-off</p>
        </div>
        <div className="admin-metric-card">
          <p className="admin-metric-label">Completed This Month</p>
          <div className="admin-metric-value">4</div>
          <p className="admin-metric-note positive">98.5% satisfaction rating</p>
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
              placeholder="Search booking ID, service, customer, provider..."
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
            <option value="Confirmed">Confirmed</option>
            <option value="In Progress">In Progress</option>
            <option value="Completed">Completed</option>
            <option value="Pending Verification">Pending Verification</option>
          </select>
        </div>

        <div className="admin-table-container">
          <table className="admin-table">
            <thead>
              <tr>
                <th>Booking ID</th>
                <th>Service Name</th>
                <th>Customer</th>
                <th>Assigned Provider</th>
                <th>Scheduled Window</th>
                <th>Escrow Amount</th>
                <th>Escrow Status</th>
                <th>Status</th>
                <th className="actions-col">Actions</th>
              </tr>
            </thead>
            <tbody>
              {filtered.map(b => (
                <tr key={b.id}>
                  <td>
                    <span className="admin-inquiry-code">{b.id}</span>
                  </td>
                  <td><strong>{b.service}</strong></td>
                  <td>{b.customer}</td>
                  <td>{b.provider}</td>
                  <td>{b.scheduledTime}</td>
                  <td><strong>{b.escrowAmount}</strong></td>
                  <td>
                    <span className={`admin-badge ${b.escrowStatus === 'Released' ? 'status-resolved' : 'status-waiting'}`}>
                      {b.escrowStatus}
                    </span>
                  </td>
                  <td>
                    <span className={`admin-badge ${
                      b.bookingStatus === 'Completed' ? 'status-resolved' :
                      b.bookingStatus === 'In Progress' ? 'status-in-progress' : 'priority-normal'
                    }`}>
                      {b.bookingStatus}
                    </span>
                  </td>
                  <td className="actions-col">
                    <button
                      type="button"
                      className="admin-btn admin-btn-secondary"
                      style={{ padding: '4px 10px', fontSize: '12px' }}
                      onClick={() => alert(`Reviewing Booking #${b.id}`)}
                    >
                      Audit Job
                    </button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>

        <div className="admin-table-footer">
          <div>Showing {filtered.length} of {mockBookings.length} records</div>
        </div>
      </div>
    </div>
  );
};
