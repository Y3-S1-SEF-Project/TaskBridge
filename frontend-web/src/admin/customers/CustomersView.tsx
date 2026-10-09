import React, { useState, useEffect, useCallback } from 'react';
import type { CustomerItem, CustomersSummary } from '../types';
import { fetchCustomers, toggleCustomerStatus } from '../api';
import { AdminSelect } from '../components/AdminSelect';

export const CustomersView: React.FC = () => {
  const [loading, setLoading] = useState(true);
  const [errorMsg, setErrorMsg] = useState('');
  const [summary, setSummary] = useState<CustomersSummary>({
    totalCustomers: 0,
    activeRepeatRate: '0%',
    avgLifetimeValue: 'LKR 0',
    accountHealth: '100%',
    items: [],
  });

  const [search, setSearch] = useState('');
  const [statusFilter, setStatusFilter] = useState('All');
  const [selectedCustomer, setSelectedCustomer] = useState<CustomerItem | null>(null);
  const [togglingId, setTogglingId] = useState<string | null>(null);

  const loadCustomers = useCallback(async () => {
    setLoading(true);
    setErrorMsg('');
    try {
      const data = await fetchCustomers({
        search: search.trim() || undefined,
        status: statusFilter !== 'All' ? statusFilter : undefined,
      });
      setSummary(data);
    } catch (err: any) {
      setErrorMsg(err.message || 'Failed to load customers from database.');
    } finally {
      setLoading(false);
    }
  }, [search, statusFilter]);

  useEffect(() => {
    const timer = setTimeout(() => {
      loadCustomers();
    }, 200);
    return () => clearTimeout(timer);
  }, [loadCustomers]);

  const handleToggleCustomerStatus = async (customer: CustomerItem) => {
    setTogglingId(customer.userId);
    try {
      const res = await toggleCustomerStatus(customer.userId);
      setSummary(prev => ({
        ...prev,
        items: prev.items.map(item =>
          item.userId === customer.userId
            ? { ...item, status: res.isSuspended ? 'Suspended' : 'Active' }
            : item
        ),
      }));
    } catch (err: any) {
      alert(err.message || 'Failed to update customer status.');
    } finally {
      setTogglingId(null);
    }
  };

  const handleExport = () => {
    if (summary.items.length === 0) return;
    const headers = ['ID', 'Name', 'Email', 'Phone', 'District', 'BookingsCount', 'TotalSpent', 'Status', 'JoinedDate'];
    const rows = summary.items.map(c => [
      c.id,
      `"${c.name.replace(/"/g, '""')}"`,
      `"${c.email}"`,
      `"${c.phone}"`,
      `"${c.district}"`,
      c.bookingsCount,
      c.totalSpent,
      c.status,
      `"${new Date(c.joinedDate).toLocaleDateString()}"`,
    ]);
    const csvContent = [headers.join(','), ...rows.map(r => r.join(','))].join('\n');
    const blob = new Blob([csvContent], { type: 'text/csv;charset=utf-8;' });
    const url = URL.createObjectURL(blob);
    const link = document.createElement('a');
    link.href = url;
    link.setAttribute('download', `TaskBridge_Customers_${new Date().toISOString().split('T')[0]}.csv`);
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
  };

  const filtered = summary.items.filter(c => {
    if (!search.trim()) return true;
    const q = search.trim().toLowerCase();
    return (
      c.name.toLowerCase().includes(q) ||
      c.email.toLowerCase().includes(q) ||
      c.phone.includes(q) ||
      c.district.toLowerCase().includes(q) ||
      c.id.toLowerCase().includes(q)
    );
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
        <div style={{ display: 'flex', gap: '10px' }}>
          <button
            type="button"
            className="admin-btn admin-btn-secondary"
            onClick={loadCustomers}
            title="Refresh customers from database"
          >
            <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.2" style={{ marginRight: '6px' }}>
              <polyline points="23 4 23 10 17 10" />
              <polyline points="1 20 1 14 7 14" />
              <path d="M3.51 9a9 9 0 0 1 14.85-3.36L23 10M1 14l4.64 4.36A9 9 0 0 0 20.49 15" />
            </svg>
            Refresh
          </button>
          <button
            type="button"
            className="admin-export-btn"
            onClick={handleExport}
          >
            <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.2">
              <path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4" />
              <polyline points="7 10 12 15 17 10" />
              <line x1="12" y1="15" x2="12" y2="3" />
            </svg>
            Export Customers
          </button>
        </div>
      </div>

      {/* Dynamic Metrics Cards */}
      <div className="admin-metrics-grid">
        <div className="admin-metric-card">
          <p className="admin-metric-label">Total Customers</p>
          <div className="admin-metric-value">{summary.totalCustomers}</div>
          <p className="admin-metric-note positive">Live registered accounts</p>
        </div>
        <div className="admin-metric-card">
          <p className="admin-metric-label">Active Repeat Bookers</p>
          <div className="admin-metric-value">{summary.activeRepeatRate}</div>
          <p className="admin-metric-note positive">&gt; 1 bookings completed</p>
        </div>
        <div className="admin-metric-card">
          <p className="admin-metric-label">Avg Lifetime Value</p>
          <div className="admin-metric-value">{summary.avgLifetimeValue}</div>
          <p className="admin-metric-note positive">Per engaged customer</p>
        </div>
        <div className="admin-metric-card">
          <p className="admin-metric-label">Account Health</p>
          <div className="admin-metric-value">{summary.accountHealth}</div>
          <p className="admin-metric-note positive">Zero active fraud holds</p>
        </div>
      </div>

      <div className="admin-table-card">
        <div className="admin-toolbar">
          <div className="admin-search-box" style={{ flex: '1 1 320px', maxWidth: '420px' }}>
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
            {search && (
              <button
                type="button"
                onClick={() => setSearch('')}
                style={{ background: 'transparent', border: 'none', cursor: 'pointer', color: '#8a9990', padding: 0 }}
              >
                ✕
              </button>
            )}
          </div>

          <div className="admin-filter-group">
            <AdminSelect
              value={statusFilter}
              onChange={setStatusFilter}
              title="Filter by Status"
              style={{ minWidth: '150px' }}
              options={[
                { value: 'All', label: 'All Statuses' },
                { value: 'Active', label: 'Active' },
                { value: 'Inactive', label: 'Inactive' },
                { value: 'Suspended', label: 'Suspended' },
              ]}
            />

            {(search || statusFilter !== 'All') && (
              <button
                type="button"
                className="admin-btn admin-btn-secondary"
                style={{ fontSize: '12.5px', padding: '6px 12px' }}
                onClick={() => {
                  setSearch('');
                  setStatusFilter('All');
                }}
              >
                Reset
              </button>
            )}
          </div>
        </div>

        {errorMsg && (
          <div style={{ margin: '0 24px 16px', padding: '12px 16px', background: '#fee2e2', color: '#b91c1c', borderRadius: '8px', fontSize: '13px' }}>
            {errorMsg}
          </div>
        )}

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
              {loading ? (
                <tr>
                  <td colSpan={9} style={{ textAlign: 'center', padding: '40px 20px', color: '#64736a' }}>
                    <div style={{ display: 'inline-flex', alignItems: 'center', gap: '10px' }}>
                      <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" style={{ animation: 'spin 1s linear infinite' }}>
                        <line x1="12" y1="2" x2="12" y2="6" />
                        <line x1="12" y1="18" x2="12" y2="22" />
                        <line x1="4.93" y1="4.93" x2="7.76" y2="7.76" />
                        <line x1="16.24" y1="16.24" x2="19.07" y2="19.07" />
                        <line x1="2" y1="12" x2="6" y2="12" />
                        <line x1="18" y1="12" x2="22" y2="12" />
                        <line x1="4.93" y1="19.07" x2="7.76" y2="16.24" />
                        <line x1="16.24" y1="7.76" x2="19.07" y2="4.93" />
                      </svg>
                      Loading real customers from database...
                    </div>
                  </td>
                </tr>
              ) : filtered.length === 0 ? (
                <tr>
                  <td colSpan={9} style={{ textAlign: 'center', padding: '48px 20px', color: '#8a9990' }}>
                    <div style={{ fontSize: '15px', fontWeight: 600, color: '#141f19', marginBottom: '6px' }}>
                      No customers found
                    </div>
                    <div style={{ fontSize: '13px', maxWidth: '400px', margin: '0 auto 16px' }}>
                      No customer accounts match the current filter or search criteria.
                    </div>
                  </td>
                </tr>
              ) : (
                filtered.map(c => (
                  <tr key={c.id}>
                    <td data-label="Customer">
                      <strong>{c.name}</strong>
                      <div style={{ fontSize: '11.5px', color: '#8a9990' }}>{c.id}</div>
                    </td>
                    <td data-label="Email">{c.email}</td>
                    <td data-label="Phone">{c.phone}</td>
                    <td data-label="District">{c.district}</td>
                    <td data-label="Bookings"><strong>{c.bookingsCount}</strong></td>
                    <td data-label="Total Spent"><strong>LKR {c.totalSpent.toLocaleString()}</strong></td>
                    <td data-label="Status">
                      <span className={`admin-badge ${c.status === 'Active' ? 'status-resolved' : c.status === 'Suspended' || c.status === 'Flagged' ? 'priority-high' : 'priority-normal'}`}>
                        {c.status}
                      </span>
                    </td>
                    <td data-label="Joined">
                      {new Date(c.joinedDate).toLocaleDateString(undefined, {
                        month: 'short',
                        year: 'numeric',
                      })}
                    </td>
                    <td data-label="Actions" className="actions-col">
                      <div style={{ display: 'inline-flex', gap: '6px' }}>
                        <button
                          type="button"
                          className="admin-btn admin-btn-secondary"
                          style={{ padding: '4px 10px', fontSize: '12px' }}
                          onClick={() => setSelectedCustomer(c)}
                        >
                          History
                        </button>
                        <button
                          type="button"
                          className="admin-btn admin-btn-secondary"
                          style={{
                            padding: '4px 8px',
                            fontSize: '11px',
                            color: c.status !== 'Suspended' ? '#b91c1c' : '#256b4a',
                            borderColor: c.status !== 'Suspended' ? '#fecaca' : '#bbf7d0',
                          }}
                          disabled={togglingId === c.userId}
                          onClick={() => handleToggleCustomerStatus(c)}
                          title={c.status !== 'Suspended' ? 'Suspend customer account' : 'Reactivate customer account'}
                        >
                          {c.status !== 'Suspended' ? 'Suspend' : 'Activate'}
                        </button>
                      </div>
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>

        <div className="admin-table-footer">
          <div>Showing <strong>{filtered.length}</strong> of <strong>{summary.totalCustomers}</strong> registered customers</div>
          {(search || statusFilter !== 'All') && (
            <div style={{ color: '#256b4a', fontSize: '12.5px', fontWeight: 500 }}>
              Filtered view active
            </div>
          )}
        </div>
      </div>

      {/* Customer Details Modal */}
      {selectedCustomer && (
        <div className="admin-modal-backdrop" onClick={() => setSelectedCustomer(null)}>
          <div className="admin-modal" style={{ maxWidth: '540px' }} onClick={(e) => e.stopPropagation()}>
            <div className="admin-modal-header">
              <div>
                <h2 className="admin-modal-title">Customer Account Profile</h2>
                <span className="admin-inquiry-code" style={{ fontSize: '13px' }}>
                  {selectedCustomer.id} • {selectedCustomer.name}
                </span>
              </div>
              <button
                type="button"
                className="admin-icon-btn"
                onClick={() => setSelectedCustomer(null)}
                aria-label="Close modal"
              >
                ✕
              </button>
            </div>

            <div className="admin-modal-body" style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '16px' }}>
                <div>
                  <div style={{ fontSize: '11.5px', color: '#64736a', textTransform: 'uppercase', fontWeight: 600 }}>Email Address</div>
                  <div style={{ fontSize: '13.5px', marginTop: '2px', wordBreak: 'break-all' }}>{selectedCustomer.email}</div>
                </div>
                <div>
                  <div style={{ fontSize: '11.5px', color: '#64736a', textTransform: 'uppercase', fontWeight: 600 }}>Contact Phone</div>
                  <div style={{ fontSize: '13.5px', marginTop: '2px' }}>{selectedCustomer.phone}</div>
                </div>
                <div>
                  <div style={{ fontSize: '11.5px', color: '#64736a', textTransform: 'uppercase', fontWeight: 600 }}>Primary Region</div>
                  <div style={{ fontSize: '13.5px', marginTop: '2px' }}>{selectedCustomer.district}</div>
                </div>
                <div>
                  <div style={{ fontSize: '11.5px', color: '#64736a', textTransform: 'uppercase', fontWeight: 600 }}>Account Status</div>
                  <div style={{ marginTop: '4px' }}>
                    <span className={`admin-badge ${selectedCustomer.status === 'Active' ? 'status-resolved' : 'priority-normal'}`}>
                      {selectedCustomer.status}
                    </span>
                  </div>
                </div>
                <div>
                  <div style={{ fontSize: '11.5px', color: '#64736a', textTransform: 'uppercase', fontWeight: 600 }}>Total Bookings</div>
                  <div style={{ fontSize: '15px', fontWeight: 600, marginTop: '2px' }}>
                    {selectedCustomer.bookingsCount} requests
                  </div>
                </div>
                <div>
                  <div style={{ fontSize: '11.5px', color: '#64736a', textTransform: 'uppercase', fontWeight: 600 }}>Lifetime Spend</div>
                  <div style={{ fontSize: '15px', fontWeight: 700, color: '#256b4a', marginTop: '2px' }}>
                    LKR {selectedCustomer.totalSpent.toLocaleString()}
                  </div>
                </div>
              </div>

              <div style={{ background: '#f5f7f5', padding: '12px 14px', borderRadius: '8px', fontSize: '12.5px', color: '#4a5b51' }}>
                Member since {new Date(selectedCustomer.joinedDate).toLocaleDateString(undefined, { dateStyle: 'long' })}.
              </div>
            </div>

            <div className="admin-modal-footer">
              <button
                type="button"
                className="admin-btn admin-btn-secondary"
                onClick={() => setSelectedCustomer(null)}
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
