import React, { useState, useEffect, useCallback } from 'react';
import type { ServiceRequestItem, ServiceRequestsSummary } from '../types';
import { fetchServiceRequests } from '../api';
import { AdminSelect } from '../components/AdminSelect';

export const ServiceRequestsView: React.FC = () => {
  const [loading, setLoading] = useState(true);
  const [errorMsg, setErrorMsg] = useState('');
  const [summary, setSummary] = useState<ServiceRequestsSummary>({
    totalRequests: 0,
    pendingCount: 0,
    acceptedCount: 0,
    completedCount: 0,
    cancelledCount: 0,
    availableCategories: [],
    items: [],
  });

  // Filter States
  const [search, setSearch] = useState('');
  const [searchBy, setSearchBy] = useState('customer');
  const [filterCategory, setFilterCategory] = useState('All');
  const [filterStatus, setFilterStatus] = useState('All');
  const [filterUrgency, setFilterUrgency] = useState('All');

  // Detail Modal State
  const [selectedRequest, setSelectedRequest] = useState<ServiceRequestItem | null>(null);

  const loadRequests = useCallback(async () => {
    setLoading(true);
    setErrorMsg('');
    try {
      const data = await fetchServiceRequests({
        search: search.trim() || undefined,
        searchBy,
        category: filterCategory !== 'All' ? filterCategory : undefined,
        status: filterStatus !== 'All' ? filterStatus : undefined,
        urgency: filterUrgency !== 'All' ? filterUrgency : undefined,
      });
      setSummary(data);
    } catch (err: any) {
      setErrorMsg(err.message || 'Failed to load service requests from database.');
    } finally {
      setLoading(false);
    }
  }, [search, searchBy, filterCategory, filterStatus, filterUrgency]);

  useEffect(() => {
    const timer = setTimeout(() => {
      loadRequests();
    }, 200);
    return () => clearTimeout(timer);
  }, [loadRequests]);

  const handleResetFilters = () => {
    setSearch('');
    setSearchBy('customer');
    setFilterCategory('All');
    setFilterStatus('All');
    setFilterUrgency('All');
  };

  const getStatusBadge = (status: string) => {
    const s = status.toLowerCase();
    if (s.includes('complete') || s.includes('customerapproved')) return 'status-resolved';
    if (s.includes('progress') || s.includes('started')) return 'status-in-progress';
    if (s.includes('accept') || s.includes('upcoming')) return 'status-in-progress';
    if (s.includes('pending') || s.includes('open') || s.includes('matching')) return 'status-open';
    if (s.includes('cancel') || s.includes('decline')) return 'priority-high';
    return 'priority-normal';
  };

  const getUrgencyBadge = (urgency: string) => {
    const u = urgency.toLowerCase();
    if (u === 'immediate') return 'priority-high';
    if (u === 'scheduled') return 'priority-normal';
    return 'priority-low';
  };

  // Client-side filtering ensures immediate and accurate matching across any network state
  const filteredItems = summary.items.filter((item) => {
    if (!search.trim()) return true;
    const q = search.trim().toLowerCase();
    if (searchBy === 'customer') {
      return (
        item.customerName.toLowerCase().includes(q) ||
        (q.startsWith('pr-') && item.reference.toLowerCase().includes(q)) ||
        (q.startsWith('tb-') && (item.reference.toLowerCase().includes(q) || item.linkedBookingReference?.toLowerCase().includes(q)))
      );
    }
    if (searchBy === 'provider') {
      return item.providerName.toLowerCase().includes(q);
    }
    if (searchBy === 'reference') {
      return (
        item.reference.toLowerCase().includes(q) ||
        (item.linkedBookingReference ? item.linkedBookingReference.toLowerCase().includes(q) : false)
      );
    }
    if (searchBy === 'service') {
      return item.serviceTitle.toLowerCase().includes(q);
    }
    // 'all'
    return (
      item.customerName.toLowerCase().includes(q) ||
      item.providerName.toLowerCase().includes(q) ||
      item.reference.toLowerCase().includes(q) ||
      (item.linkedBookingReference && item.linkedBookingReference.toLowerCase().includes(q)) ||
      item.serviceTitle.toLowerCase().includes(q) ||
      item.location.toLowerCase().includes(q) ||
      (item.notes && item.notes.toLowerCase().includes(q))
    );
  });

  return (
    <div className="admin-content">
      {/* Title & Action */}
      <div className="admin-page-header">
        <div>
          <h1 className="admin-page-title">Service Requests</h1>
          <p className="admin-page-subtitle">
            Real customer work requests, quotation bids, and dispatch statuses connected live to database.
          </p>
        </div>
        <div style={{ display: 'flex', gap: '10px' }}>
          <button
            type="button"
            className="admin-btn admin-btn-secondary"
            onClick={loadRequests}
            title="Refresh requests from database"
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
            onClick={() => alert(`Exporting ${summary.items.length} service requests to CSV...`)}
          >
            <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.2">
              <path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4" />
              <polyline points="7 10 12 15 17 10" />
              <line x1="12" y1="15" x2="12" y2="3" />
            </svg>
            Export Requests
          </button>
        </div>
      </div>

      {/* Metrics Grid from Real Database Counts */}
      <div className="admin-metrics-grid">
        <div className="admin-metric-card">
          <p className="admin-metric-label">Total Requests</p>
          <div className="admin-metric-value">{summary.totalRequests}</div>
          <p className="admin-metric-note positive">Live database records</p>
        </div>
        <div className="admin-metric-card">
          <p className="admin-metric-label">Completed Jobs</p>
          <div className="admin-metric-value">{summary.completedCount}</div>
          <p className="admin-metric-note positive">
            {summary.totalRequests > 0 ? `${Math.round((summary.completedCount / summary.totalRequests) * 100)}% completion rate` : '0%'}
          </p>
        </div>
        <div className="admin-metric-card">
          <p className="admin-metric-label">Pending / Matching</p>
          <div className="admin-metric-value">{summary.pendingCount}</div>
          <p className="admin-metric-note">Awaiting provider quotes</p>
        </div>
        <div className="admin-metric-card">
          <p className="admin-metric-label">Cancelled / Declined</p>
          <div className="admin-metric-value" style={{ color: summary.cancelledCount > 0 ? '#c81e1e' : undefined }}>
            {summary.cancelledCount}
          </div>
          <p className="admin-metric-note">Customer cancelled or provider declined</p>
        </div>
      </div>

      {/* Table Card with Real Data & Dynamic Filters */}
      <div className="admin-table-card">
        <div className="admin-toolbar">
          {/* Live Search with Scope Selector */}
          <div className="admin-search-group">
            <AdminSelect
              className="admin-search-scope"
              value={searchBy}
              onChange={setSearchBy}
              title="Search Target"
              options={[
                { value: 'customer', label: 'Customer Name' },
                { value: 'all', label: 'All Fields' },
                { value: 'provider', label: 'Provider Name' },
                { value: 'reference', label: 'Reference ID' },
                { value: 'service', label: 'Service Title' },
              ]}
            />

            <div className="admin-search-box">
              <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                <circle cx="11" cy="11" r="8" />
                <line x1="21" y1="21" x2="16.65" y2="16.65" />
              </svg>
              <input
                type="text"
                placeholder={
                  searchBy === 'customer'
                    ? 'Search customer...'
                    : searchBy === 'provider'
                    ? 'Search provider...'
                    : searchBy === 'reference'
                    ? 'Search ref ID...'
                    : searchBy === 'service'
                    ? 'Search service...'
                    : 'Search requests...'
                }
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
          </div>

          {/* Filters Row */}
          <div className="admin-filter-group">
            {/* Category Filter */}
            <AdminSelect
              value={filterCategory}
              onChange={setFilterCategory}
              title="Filter by Category"
              options={[
                { value: 'All', label: `All Categories (${summary.availableCategories.length})` },
                ...summary.availableCategories.map((cat) => ({ value: cat, label: cat })),
              ]}
            />

            {/* Status Filter */}
            <AdminSelect
              value={filterStatus}
              onChange={setFilterStatus}
              title="Filter by Status"
              options={[
                { value: 'All', label: 'All Statuses' },
                { value: 'Completed', label: 'Completed' },
                { value: 'Accepted', label: 'Accepted' },
                { value: 'In Progress', label: 'In Progress' },
                { value: 'Pending', label: 'Pending' },
                { value: 'Cancelled', label: 'Cancelled' },
                { value: 'Declined', label: 'Declined' },
              ]}
            />

            {/* Urgency Filter */}
            <AdminSelect
              value={filterUrgency}
              onChange={setFilterUrgency}
              title="Filter by Urgency"
              options={[
                { value: 'All', label: 'All Urgency' },
                { value: 'Immediate', label: 'Immediate (<24h)' },
                { value: 'Scheduled', label: 'Scheduled' },
                { value: 'Flexible', label: 'Flexible' },
              ]}
            />

            {(search || filterCategory !== 'All' || filterStatus !== 'All' || filterUrgency !== 'All') && (
              <button
                type="button"
                className="admin-btn admin-btn-secondary"
                style={{ fontSize: '12.5px', padding: '6px 12px' }}
                onClick={handleResetFilters}
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
                <th>Reference ID</th>
                <th>Customer</th>
                <th>Assigned Provider</th>
                <th>Service Title</th>
                <th>Category</th>
                <th>Location</th>
                <th>Urgency</th>
                <th>Rate / Price</th>
                <th>Status</th>
                <th>Requested</th>
                <th className="actions-col">Actions</th>
              </tr>
            </thead>
            <tbody>
              {loading ? (
                <tr>
                  <td colSpan={11} style={{ textAlign: 'center', padding: '40px 20px', color: '#64736a' }}>
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
                      Loading real service requests from database...
                    </div>
                  </td>
                </tr>
              ) : filteredItems.length === 0 ? (
                <tr>
                  <td colSpan={11} style={{ textAlign: 'center', padding: '48px 20px', color: '#8a9990' }}>
                    <div style={{ fontSize: '15px', fontWeight: 600, color: '#141f19', marginBottom: '6px' }}>
                      No service requests found
                    </div>
                    <div style={{ fontSize: '13px', maxWidth: '400px', margin: '0 auto 16px' }}>
                      No requests match the current search or filters. Try adjusting your query or resetting filters.
                    </div>
                    <button
                      type="button"
                      className="admin-btn admin-btn-secondary"
                      onClick={handleResetFilters}
                    >
                      Clear All Filters
                    </button>
                  </td>
                </tr>
              ) : (
                filteredItems.map((req) => (
                  <tr key={req.id}>
                    <td data-label="Reference ID">
                      <span className="admin-inquiry-code">{req.reference}</span>
                      {req.linkedBookingReference && req.linkedBookingReference !== req.reference && (
                        <div style={{ fontSize: '11px', color: '#256b4a' }}>Job: {req.linkedBookingReference}</div>
                      )}
                    </td>
                    <td data-label="Customer">
                      <strong>{req.customerName}</strong>
                    </td>
                    <td data-label="Provider">
                      {req.providerName && req.providerName !== 'Unassigned' ? (
                        <span style={{ fontWeight: 500, color: '#113c2b' }}>{req.providerName}</span>
                      ) : (
                        <span style={{ color: '#8a9990', fontStyle: 'italic' }}>Unassigned</span>
                      )}
                    </td>
                    <td data-label="Service">
                      <strong>{req.serviceTitle}</strong>
                    </td>
                    <td data-label="Category">{req.category}</td>
                    <td data-label="Location">
                      <span style={{ fontSize: '13px', color: '#64736a' }}>
                        {req.location || 'Not specified'}
                      </span>
                    </td>
                    <td data-label="Urgency">
                      <span className={`admin-badge ${getUrgencyBadge(req.urgency)}`}>
                        {req.urgency}
                      </span>
                    </td>
                    <td data-label="Rate / Price">
                      <strong>LKR {req.price?.toLocaleString()}</strong>
                      <span style={{ fontSize: '11px', color: '#8a9990', marginLeft: '4px' }}>
                        /{req.rateType || 'job'}
                      </span>
                    </td>
                    <td data-label="Status">
                      <span className={`admin-badge ${getStatusBadge(req.status)}`}>
                        {req.status}
                      </span>
                    </td>
                    <td data-label="Requested" style={{ fontSize: '12.5px', color: '#64736a' }}>
                      {new Date(req.createdAt).toLocaleDateString(undefined, {
                        month: 'short',
                        day: 'numeric',
                        hour: '2-digit',
                        minute: '2-digit',
                      })}
                    </td>
                    <td data-label="Actions" className="actions-col">
                      <button
                        type="button"
                        className="admin-btn admin-btn-secondary"
                        style={{ padding: '4px 10px', fontSize: '12px' }}
                        onClick={() => setSelectedRequest(req)}
                      >
                        Details
                      </button>
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>

        <div className="admin-table-footer">
          <div>
            Showing <strong>{filteredItems.length}</strong> of <strong>{summary.totalRequests}</strong> requests in database
          </div>
          {(search || filterCategory !== 'All' || filterStatus !== 'All' || filterUrgency !== 'All') && (
            <div style={{ color: '#256b4a', fontSize: '12.5px', fontWeight: 500 }}>
              Filtered view active
            </div>
          )}
        </div>
      </div>

      {/* Request Details Modal */}
      {selectedRequest && (
        <div className="admin-modal-backdrop" onClick={() => setSelectedRequest(null)}>
          <div className="admin-modal" style={{ maxWidth: '640px' }} onClick={(e) => e.stopPropagation()}>
            <div className="admin-modal-header">
              <div>
                <h2 className="admin-modal-title">Service Request Details</h2>
                <span className="admin-inquiry-code" style={{ fontSize: '13px' }}>
                  {selectedRequest.reference}
                </span>
              </div>
              <button
                type="button"
                className="admin-icon-btn"
                onClick={() => setSelectedRequest(null)}
              >
                ✕
              </button>
            </div>

            <div className="admin-modal-body" style={{ maxHeight: '70vh', overflowY: 'auto' }}>
              {/* Header Box */}
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', padding: '16px', background: '#f5f8f6', borderRadius: '12px', border: '1px solid #e3ebe6' }}>
                <div>
                  <h3 style={{ margin: '0 0 4px 0', fontSize: '17px', color: '#141f19' }}>
                    {selectedRequest.serviceTitle}
                  </h3>
                  <div style={{ fontSize: '13px', color: '#64736a' }}>
                    Category: <strong>{selectedRequest.category}</strong>
                  </div>
                </div>
                <div style={{ textAlign: 'right' }}>
                  <span className={`admin-badge ${getStatusBadge(selectedRequest.status)}`} style={{ fontSize: '13px', padding: '6px 12px' }}>
                    {selectedRequest.status}
                  </span>
                  <div style={{ fontSize: '11.5px', color: '#8a9990', marginTop: '4px' }}>
                    Urgency: {selectedRequest.urgency}
                  </div>
                </div>
              </div>

              {/* Info Grid */}
              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '16px' }}>
                <div className="admin-cred-box">
                  <div style={{ fontWeight: 600, fontSize: '13px', color: '#113c2b', marginBottom: '8px' }}>Customer Information</div>
                  <div className="admin-cred-row">
                    <span className="admin-cred-label">Name:</span>
                    <span style={{ fontWeight: 600 }}>{selectedRequest.customerName}</span>
                  </div>
                  {selectedRequest.customerId && (
                    <div className="admin-cred-row">
                      <span className="admin-cred-label">User ID:</span>
                      <span style={{ fontFamily: 'monospace', fontSize: '11px' }}>{selectedRequest.customerId}</span>
                    </div>
                  )}
                </div>

                <div className="admin-cred-box">
                  <div style={{ fontWeight: 600, fontSize: '13px', color: '#113c2b', marginBottom: '8px' }}>Assigned Provider</div>
                  <div className="admin-cred-row">
                    <span className="admin-cred-label">Provider:</span>
                    <span style={{ fontWeight: 600 }}>{selectedRequest.providerName || 'Unassigned'}</span>
                  </div>
                  {selectedRequest.providerId && (
                    <div className="admin-cred-row">
                      <span className="admin-cred-label">Provider ID:</span>
                      <span style={{ fontFamily: 'monospace', fontSize: '11px' }}>{selectedRequest.providerId}</span>
                    </div>
                  )}
                </div>
              </div>

              {/* Schedule & Location */}
              <div className="admin-cred-box">
                <div style={{ fontWeight: 600, fontSize: '13px', color: '#113c2b', marginBottom: '8px' }}>Schedule &amp; Location</div>
                <div className="admin-cred-row">
                  <span className="admin-cred-label">Preferred Time:</span>
                  <span>{selectedRequest.preferredSchedule || 'Immediate / Flexible'}</span>
                </div>
                <div className="admin-cred-row">
                  <span className="admin-cred-label">Location:</span>
                  <span>{selectedRequest.location || 'Not specified'}</span>
                </div>
                <div className="admin-cred-row">
                  <span className="admin-cred-label">Estimated Rate:</span>
                  <span style={{ fontWeight: 700, color: '#256b4a' }}>
                    LKR {selectedRequest.price?.toLocaleString()} ({selectedRequest.rateType || 'Hourly'})
                  </span>
                </div>
                {selectedRequest.linkedBookingReference && (
                  <div className="admin-cred-row">
                    <span className="admin-cred-label">Linked Booking:</span>
                    <span className="admin-inquiry-code">{selectedRequest.linkedBookingReference}</span>
                  </div>
                )}
              </div>

              {/* Customer Notes */}
              {selectedRequest.notes && (
                <div style={{ padding: '14px', background: '#fafcfb', border: '1px solid #e3ebe6', borderRadius: '10px' }}>
                  <div style={{ fontSize: '12px', fontWeight: 600, color: '#64736a', marginBottom: '4px' }}>Customer Special Notes:</div>
                  <div style={{ fontSize: '13.5px', color: '#141f19' }}>{selectedRequest.notes}</div>
                </div>
              )}

              <div style={{ fontSize: '12px', color: '#8a9990', textAlign: 'right' }}>
                Recorded in database at: {new Date(selectedRequest.createdAt).toLocaleString()}
              </div>
            </div>

            <div className="admin-modal-footer">
              <button
                type="button"
                className="admin-btn admin-btn-secondary"
                onClick={() => setSelectedRequest(null)}
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
