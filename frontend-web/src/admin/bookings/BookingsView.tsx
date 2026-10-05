import React, { useState, useEffect, useCallback } from 'react';
import type { BookingItem, BookingsSummary } from '../types';
import { fetchBookings } from '../api';
import { AdminSelect } from '../components/AdminSelect';

export const BookingsView: React.FC = () => {
  const [loading, setLoading] = useState(true);
  const [errorMsg, setErrorMsg] = useState('');
  const [summary, setSummary] = useState<BookingsSummary>({
    activeJobsCount: 0,
    scheduledTodayCount: 0,
    totalWorkFunds: 0,
    formattedWorkFunds: 'LKR 0',
    completedJobsCount: 0,
    items: [],
  });

  const [search, setSearch] = useState('');
  const [statusFilter, setStatusFilter] = useState('All');
  const [selectedBooking, setSelectedBooking] = useState<BookingItem | null>(null);

  const loadBookings = useCallback(async () => {
    setLoading(true);
    setErrorMsg('');
    try {
      const data = await fetchBookings({
        search: search.trim() || undefined,
        status: statusFilter !== 'All' ? statusFilter : undefined,
      });
      setSummary(data);
    } catch (err: any) {
      setErrorMsg(err.message || 'Failed to load bookings from database.');
    } finally {
      setLoading(false);
    }
  }, [search, statusFilter]);

  useEffect(() => {
    const timer = setTimeout(() => {
      loadBookings();
    }, 200);
    return () => clearTimeout(timer);
  }, [loadBookings]);

  const handleExport = () => {
    if (summary.items.length === 0) return;
    const headers = [
      'Booking ID',
      'Service Name',
      'Category',
      'Customer',
      'Assigned Provider',
      'Scheduled Window',
      'Location',
      'Total Amount (LKR)',
      'Rate Type',
      'Status',
      'Created At',
    ];

    const rows = summary.items.map(b => [
      b.bookingReference,
      `"${b.serviceTitle.replace(/"/g, '""')}"`,
      `"${b.category.replace(/"/g, '""')}"`,
      `"${b.customerName.replace(/"/g, '""')}"`,
      `"${b.providerName.replace(/"/g, '""')}"`,
      `"${b.scheduledWindow.replace(/"/g, '""')}"`,
      `"${b.location.replace(/"/g, '""')}"`,
      b.finalPrice ?? b.price,
      b.rateType,
      b.status,
      `"${new Date(b.createdAt).toLocaleDateString()}"`,
    ]);

    const csvContent = [headers.join(','), ...rows.map(r => r.join(','))].join('\n');
    const blob = new Blob([csvContent], { type: 'text/csv;charset=utf-8;' });
    const url = URL.createObjectURL(blob);
    const link = document.createElement('a');
    link.setAttribute('href', url);
    link.setAttribute('download', `TaskBridge_Bookings_${new Date().toISOString().slice(0, 10)}.csv`);
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
  };

  const getStatusBadgeClass = (status: string) => {
    switch (status.toLowerCase()) {
      case 'completed':
        return 'status-resolved';
      case 'in progress':
      case 'started':
        return 'status-in-progress';
      case 'confirmed':
      case 'upcoming':
        return 'status-waiting';
      case 'cancelled':
        return 'priority-critical';
      default:
        return 'priority-normal';
    }
  };

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
          onClick={handleExport}
          disabled={loading || summary.items.length === 0}
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
          <div className="admin-metric-value">{loading ? '...' : summary.activeJobsCount}</div>
          <p className="admin-metric-note positive">Real-time active operations</p>
        </div>
        <div className="admin-metric-card">
          <p className="admin-metric-label">Scheduled Today</p>
          <div className="admin-metric-value">{loading ? '...' : summary.scheduledTodayCount}</div>
          <p className="admin-metric-note">Marketplace scheduled appointments</p>
        </div>
        <div className="admin-metric-card">
          <p className="admin-metric-label">Total Work Funds</p>
          <div className="admin-metric-value">{loading ? '...' : summary.formattedWorkFunds}</div>
          <p className="admin-metric-note positive">Settled for completed jobs</p>
        </div>
        <div className="admin-metric-card">
          <p className="admin-metric-label">Completed Jobs</p>
          <div className="admin-metric-value">{loading ? '...' : summary.completedJobsCount}</div>
          <p className="admin-metric-note positive">Successfully delivered jobs</p>
        </div>
      </div>

      {errorMsg && (
        <div style={{
          background: '#fef2f2',
          border: '1px solid #fee2e2',
          color: '#b91c1c',
          padding: '12px 16px',
          borderRadius: '8px',
          marginBottom: '20px',
          fontSize: '13.5px'
        }}>
          {errorMsg}
        </div>
      )}

      <div className="admin-table-card">
        <div className="admin-toolbar">
          <div className="admin-search-box">
            <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
              <circle cx="11" cy="11" r="8" />
              <line x1="21" y1="21" x2="16.65" y2="16.65" />
            </svg>
            <input
              type="text"
              placeholder="Search booking ID, service, customer, provider, location..."
              value={search}
              onChange={(e) => setSearch(e.target.value)}
            />
          </div>

          <AdminSelect
            value={statusFilter}
            onChange={setStatusFilter}
            title="Filter by Status"
            style={{ minWidth: '150px' }}
            options={[
              { value: 'All', label: 'All Statuses' },
              { value: 'In Progress', label: 'In Progress' },
              { value: 'Confirmed', label: 'Confirmed' },
              { value: 'Completed', label: 'Completed' },
              { value: 'Cancelled', label: 'Cancelled' },
            ]}
          />
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
                <th>Total Amount</th>
                <th>Status</th>
                <th className="actions-col">Actions</th>
              </tr>
            </thead>
            <tbody>
              {loading && summary.items.length === 0 ? (
                <tr>
                  <td colSpan={8} style={{ textAlign: 'center', padding: '40px', color: '#64736a' }}>
                    Loading bookings & jobs from database...
                  </td>
                </tr>
              ) : summary.items.length === 0 ? (
                <tr>
                  <td colSpan={8} style={{ textAlign: 'center', padding: '40px', color: '#64736a' }}>
                    No bookings found matching current filters.
                  </td>
                </tr>
              ) : (
                summary.items.map(b => {
                  const effectivePrice = b.finalPrice ?? b.price;
                  return (
                    <tr key={b.id}>
                      <td data-label="Booking ID">
                        <span className="admin-inquiry-code">{b.bookingReference}</span>
                      </td>
                      <td data-label="Service">
                        <strong>{b.serviceTitle}</strong>
                        {b.category && (
                          <div style={{ fontSize: '11.5px', color: '#64736a', marginTop: '2px' }}>
                            {b.category}
                          </div>
                        )}
                      </td>
                      <td data-label="Customer">{b.customerName}</td>
                      <td data-label="Provider">{b.providerName}</td>
                      <td data-label="Schedule" style={{ fontSize: '12.5px' }}>{b.scheduledWindow}</td>
                      <td data-label="Total Amount">
                        <strong>LKR {effectivePrice.toLocaleString()}</strong>
                        <div style={{ fontSize: '11px', color: '#64736a' }}>
                          {b.rateType || 'Hourly'}
                        </div>
                      </td>
                      <td data-label="Status">
                        <span className={`admin-badge ${getStatusBadgeClass(b.status)}`}>
                          {b.status}
                        </span>
                      </td>
                      <td data-label="Actions" className="actions-col">
                        <button
                          type="button"
                          className="admin-btn admin-btn-secondary"
                          style={{ padding: '4px 10px', fontSize: '12px' }}
                          onClick={() => setSelectedBooking(b)}
                        >
                          Audit Job
                        </button>
                      </td>
                    </tr>
                  );
                })
              )}
            </tbody>
          </table>
        </div>

        <div className="admin-table-footer">
          <div>Showing {summary.items.length} records</div>
        </div>
      </div>

      {/* JOB AUDIT & DETAILS MODAL */}
      {selectedBooking && (
        <div className="admin-modal-backdrop" onClick={() => setSelectedBooking(null)}>
          <div
            className="admin-modal"
            style={{ maxWidth: '580px', width: '92%' }}
            onClick={(e) => e.stopPropagation()}
          >
            <div className="admin-modal-header">
              <div>
                <h2 className="admin-modal-title">Job Audit & Telemetry</h2>
                <span className="admin-inquiry-code" style={{ fontSize: '13px' }}>
                  {selectedBooking.bookingReference} • {selectedBooking.serviceTitle}
                </span>
              </div>
              <button
                type="button"
                className="admin-icon-btn"
                onClick={() => setSelectedBooking(null)}
                aria-label="Close modal"
              >
                ✕
              </button>
            </div>

            <div className="admin-modal-body" style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '16px' }}>
                <div>
                  <div style={{ fontSize: '11.5px', color: '#64736a', textTransform: 'uppercase', fontWeight: 600 }}>Customer</div>
                  <div style={{ fontSize: '14px', fontWeight: 600, marginTop: '2px' }}>{selectedBooking.customerName}</div>
                </div>
                <div>
                  <div style={{ fontSize: '11.5px', color: '#64736a', textTransform: 'uppercase', fontWeight: 600 }}>Assigned Provider</div>
                  <div style={{ fontSize: '14px', fontWeight: 600, marginTop: '2px' }}>{selectedBooking.providerName}</div>
                </div>
                <div>
                  <div style={{ fontSize: '11.5px', color: '#64736a', textTransform: 'uppercase', fontWeight: 600 }}>Category</div>
                  <div style={{ fontSize: '13.5px', marginTop: '2px' }}>{selectedBooking.category || 'General Service'}</div>
                </div>
                <div>
                  <div style={{ fontSize: '11.5px', color: '#64736a', textTransform: 'uppercase', fontWeight: 600 }}>Job Status</div>
                  <div style={{ marginTop: '4px' }}>
                    <span className={`admin-badge ${getStatusBadgeClass(selectedBooking.status)}`}>
                      {selectedBooking.status}
                    </span>
                  </div>
                </div>
                <div>
                  <div style={{ fontSize: '11.5px', color: '#64736a', textTransform: 'uppercase', fontWeight: 600 }}>Total Work Amount</div>
                  <div style={{ fontSize: '16px', fontWeight: 700, color: '#256b4a', marginTop: '2px' }}>
                    LKR {(selectedBooking.finalPrice ?? selectedBooking.price).toLocaleString()}
                    <span style={{ fontSize: '12px', fontWeight: 500, color: '#64736a', marginLeft: '6px' }}>
                      ({selectedBooking.rateType || 'Hourly'})
                    </span>
                  </div>
                </div>
                <div>
                  <div style={{ fontSize: '11.5px', color: '#64736a', textTransform: 'uppercase', fontWeight: 600 }}>Duration Logged</div>
                  <div style={{ fontSize: '14px', fontWeight: 600, marginTop: '2px' }}>
                    {selectedBooking.durationMinutes ? `${selectedBooking.durationMinutes} mins` : 'In progress / Not logged'}
                  </div>
                </div>
              </div>

              <div>
                <div style={{ fontSize: '11.5px', color: '#64736a', textTransform: 'uppercase', fontWeight: 600 }}>Scheduled Window & Location</div>
                <div style={{ fontSize: '13.5px', marginTop: '4px', background: '#f5f7f5', padding: '10px 12px', borderRadius: '8px', color: '#2d3748' }}>
                  <div style={{ fontWeight: 500 }}>{selectedBooking.scheduledWindow}</div>
                  {selectedBooking.location && (
                    <div style={{ fontSize: '12px', color: '#64736a', marginTop: '4px' }}>
                      📍 {selectedBooking.location}
                    </div>
                  )}
                </div>
              </div>

              {selectedBooking.notes && (
                <div>
                  <div style={{ fontSize: '11.5px', color: '#64736a', textTransform: 'uppercase', fontWeight: 600 }}>Special Notes</div>
                  <div style={{ fontSize: '13px', marginTop: '4px', background: '#f8fafc', padding: '10px 12px', borderRadius: '8px', color: '#334155' }}>
                    {selectedBooking.notes}
                  </div>
                </div>
              )}

              <div style={{ fontSize: '12px', color: '#64736a', borderTop: '1px solid #eef1ef', paddingTop: '10px' }}>
                Job initiated on {new Date(selectedBooking.createdAt).toLocaleString(undefined, { dateStyle: 'medium', timeStyle: 'short' })}
              </div>
            </div>

            <div className="admin-modal-footer">
              <button
                type="button"
                className="admin-btn admin-btn-secondary"
                onClick={() => setSelectedBooking(null)}
              >
                Close
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};
