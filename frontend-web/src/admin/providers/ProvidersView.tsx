import React, { useState, useEffect, useCallback } from 'react';
import type { ProviderItem, ProvidersSummary } from '../types';
import { fetchProviders, toggleProviderStatus } from '../api';

export const ProvidersView: React.FC = () => {
  const [loading, setLoading] = useState(true);
  const [errorMsg, setErrorMsg] = useState('');
  const [summary, setSummary] = useState<ProvidersSummary>({
    totalProviders: 0,
    verifiedCount: 0,
    pendingKycCount: 0,
    averageRating: 0,
    availableCategories: [],
    items: [],
  });

  // Filter States
  const [search, setSearch] = useState('');
  const [categoryFilter, setCategoryFilter] = useState('All');
  const [statusFilter, setStatusFilter] = useState('All');

  // Detail Modal
  const [selectedProvider, setSelectedProvider] = useState<ProviderItem | null>(null);
  const [togglingId, setTogglingId] = useState<string | null>(null);

  const loadProviders = useCallback(async () => {
    setLoading(true);
    setErrorMsg('');
    try {
      const data = await fetchProviders({
        search: search.trim() || undefined,
        category: categoryFilter !== 'All' ? categoryFilter : undefined,
        status: statusFilter !== 'All' ? statusFilter : undefined,
      });
      setSummary(data);
    } catch (err: any) {
      setErrorMsg(err.message || 'Failed to load service providers from database.');
    } finally {
      setLoading(false);
    }
  }, [search, categoryFilter, statusFilter]);

  useEffect(() => {
    const timer = setTimeout(() => {
      loadProviders();
    }, 200);
    return () => clearTimeout(timer);
  }, [loadProviders]);

  const handleToggleStatus = async (provider: ProviderItem) => {
    if (!confirm(`Are you sure you want to change status for ${provider.name}?`)) return;
    setTogglingId(provider.userId);
    try {
      const res = await toggleProviderStatus(provider.userId);
      setSummary(prev => ({
        ...prev,
        items: prev.items.map(p => p.userId === provider.userId ? {
          ...p,
          accountStatus: res.isActive ? 'Active' : 'Suspended'
        } : p)
      }));
      if (selectedProvider && selectedProvider.userId === provider.userId) {
        setSelectedProvider(prev => prev ? { ...prev, accountStatus: res.isActive ? 'Active' : 'Suspended' } : null);
      }
    } catch (err: any) {
      alert(err.message || 'Failed to update provider status.');
    } finally {
      setTogglingId(null);
    }
  };

  const handleExport = () => {
    if (summary.items.length === 0) return;
    const headers = ['ID', 'Name', 'Category', 'Phone', 'Location', 'Rating', 'JobsDone', 'KYC', 'AccountStatus'];
    const rows = summary.items.map(p => [
      p.id,
      `"${p.name.replace(/"/g, '""')}"`,
      `"${p.category}"`,
      `"${p.phone}"`,
      `"${p.location}"`,
      p.rating,
      p.completedJobs,
      p.kycStatus,
      p.accountStatus,
    ]);
    const csvContent = [headers.join(','), ...rows.map(r => r.join(','))].join('\n');
    const blob = new Blob([csvContent], { type: 'text/csv;charset=utf-8;' });
    const url = URL.createObjectURL(blob);
    const link = document.createElement('a');
    link.href = url;
    link.setAttribute('download', `TaskBridge_Providers_${new Date().toISOString().split('T')[0]}.csv`);
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
  };

  // Client-side filtering ensures instant response
  const filtered = summary.items.filter(p => {
    if (!search.trim()) return true;
    const q = search.trim().toLowerCase();
    return (
      p.name.toLowerCase().includes(q) ||
      p.category.toLowerCase().includes(q) ||
      p.phone.includes(q) ||
      p.location.toLowerCase().includes(q) ||
      p.id.toLowerCase().includes(q)
    );
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
        <div style={{ display: 'flex', gap: '10px' }}>
          <button
            type="button"
            className="admin-btn admin-btn-secondary"
            onClick={loadProviders}
            title="Refresh providers from database"
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
            Export Providers
          </button>
        </div>
      </div>

      {/* Dynamic Metrics Cards */}
      <div className="admin-metrics-grid">
        <div className="admin-metric-card">
          <p className="admin-metric-label">Total Providers</p>
          <div className="admin-metric-value">{summary.totalProviders}</div>
          <p className="admin-metric-note positive">Live registered professionals</p>
        </div>
        <div className="admin-metric-card">
          <p className="admin-metric-label">Verified &amp; Active</p>
          <div className="admin-metric-value">{summary.verifiedCount}</div>
          <p className="admin-metric-note positive">
            {summary.totalProviders > 0 ? `${Math.round((summary.verifiedCount / summary.totalProviders) * 100)}% verified rate` : '0%'}
          </p>
        </div>
        <div className="admin-metric-card">
          <p className="admin-metric-label">Pending KYC Verification</p>
          <div className="admin-metric-value" style={{ color: summary.pendingKycCount > 0 ? '#b91c1c' : '#141f19' }}>
            {summary.pendingKycCount}
          </div>
          <p className="admin-metric-note">NIC &amp; credentials review</p>
        </div>
        <div className="admin-metric-card">
          <p className="admin-metric-label">Platform Average Rating</p>
          <div className="admin-metric-value">{summary.averageRating.toFixed(2)} ★</div>
          <p className="admin-metric-note positive">Top-tier service standard</p>
        </div>
      </div>

      {/* Main Table Card */}
      <div className="admin-table-card">
        <div className="admin-toolbar" style={{ padding: '20px 24px 16px', display: 'flex', gap: '12px', flexWrap: 'wrap', alignItems: 'center' }}>
          <div className="admin-search-box" style={{ flex: '1 1 300px' }}>
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

          <div style={{ display: 'flex', gap: '10px', flexWrap: 'wrap' }}>
            <select
              className="admin-filter-select"
              value={categoryFilter}
              onChange={(e) => setCategoryFilter(e.target.value)}
            >
              <option value="All">All Trades ({summary.availableCategories.length})</option>
              {summary.availableCategories.map(cat => (
                <option key={cat} value={cat}>{cat}</option>
              ))}
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

            {(search || categoryFilter !== 'All' || statusFilter !== 'All') && (
              <button
                type="button"
                className="admin-btn admin-btn-secondary"
                style={{ fontSize: '12.5px', padding: '6px 12px' }}
                onClick={() => {
                  setSearch('');
                  setCategoryFilter('All');
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
                      Loading real service providers from database...
                    </div>
                  </td>
                </tr>
              ) : filtered.length === 0 ? (
                <tr>
                  <td colSpan={9} style={{ textAlign: 'center', padding: '48px 20px', color: '#8a9990' }}>
                    <div style={{ fontSize: '15px', fontWeight: 600, color: '#141f19', marginBottom: '6px' }}>
                      No service providers found
                    </div>
                    <div style={{ fontSize: '13px', maxWidth: '400px', margin: '0 auto 16px' }}>
                      No providers match the current search or filters. Try adjusting your search term.
                    </div>
                  </td>
                </tr>
              ) : (
                filtered.map(p => (
                  <tr key={p.id}>
                    <td>
                      <strong>{p.name}</strong>
                      <div style={{ fontSize: '11.5px', color: '#8a9990' }}>{p.id}</div>
                    </td>
                    <td>{p.category}</td>
                    <td>{p.phone}</td>
                    <td>{p.location}</td>
                    <td>
                      <span style={{ fontWeight: 600, color: '#256b4a' }}>★ {p.rating.toFixed(1)}</span>
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
                      <div style={{ display: 'inline-flex', gap: '6px' }}>
                        <button
                          type="button"
                          className="admin-btn admin-btn-secondary"
                          style={{ padding: '4px 10px', fontSize: '12px' }}
                          onClick={() => setSelectedProvider(p)}
                        >
                          Profile
                        </button>
                        <button
                          type="button"
                          className="admin-btn admin-btn-secondary"
                          style={{
                            padding: '4px 8px',
                            fontSize: '11px',
                            color: p.accountStatus === 'Active' ? '#b91c1c' : '#256b4a',
                            borderColor: p.accountStatus === 'Active' ? '#fecaca' : '#bbf7d0',
                          }}
                          disabled={togglingId === p.userId}
                          onClick={() => handleToggleStatus(p)}
                          title={p.accountStatus === 'Active' ? 'Suspend provider access' : 'Activate provider account'}
                        >
                          {p.accountStatus === 'Active' ? 'Suspend' : 'Activate'}
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
          <div>Showing <strong>{filtered.length}</strong> of <strong>{summary.totalProviders}</strong> providers in database</div>
          {(search || categoryFilter !== 'All' || statusFilter !== 'All') && (
            <div style={{ color: '#256b4a', fontSize: '12.5px', fontWeight: 500 }}>
              Filtered view active
            </div>
          )}
        </div>
      </div>

      {/* Provider Profile Details Modal */}
      {selectedProvider && (
        <div className="admin-modal-backdrop" onClick={() => setSelectedProvider(null)}>
          <div className="admin-modal" style={{ maxWidth: '600px' }} onClick={(e) => e.stopPropagation()}>
            <div className="admin-modal-header">
              <div>
                <h2 className="admin-modal-title">Provider Profile Details</h2>
                <span className="admin-inquiry-code" style={{ fontSize: '13px' }}>
                  {selectedProvider.id} • {selectedProvider.name}
                </span>
              </div>
              <button
                type="button"
                className="admin-icon-btn"
                onClick={() => setSelectedProvider(null)}
                aria-label="Close modal"
              >
                ✕
              </button>
            </div>

            <div className="admin-modal-body" style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '16px' }}>
                <div>
                  <div style={{ fontSize: '11.5px', color: '#64736a', textTransform: 'uppercase', fontWeight: 600 }}>Primary Trade</div>
                  <div style={{ fontSize: '14px', fontWeight: 600, marginTop: '2px' }}>{selectedProvider.category}</div>
                </div>
                <div>
                  <div style={{ fontSize: '11.5px', color: '#64736a', textTransform: 'uppercase', fontWeight: 600 }}>Hourly Rate</div>
                  <div style={{ fontSize: '14px', fontWeight: 600, marginTop: '2px', color: '#256b4a' }}>
                    LKR {selectedProvider.hourlyRate.toLocaleString()} /hr
                  </div>
                </div>
                <div>
                  <div style={{ fontSize: '11.5px', color: '#64736a', textTransform: 'uppercase', fontWeight: 600 }}>Contact Phone</div>
                  <div style={{ fontSize: '14px', marginTop: '2px' }}>{selectedProvider.phone}</div>
                </div>
                <div>
                  <div style={{ fontSize: '11.5px', color: '#64736a', textTransform: 'uppercase', fontWeight: 600 }}>Operating Area</div>
                  <div style={{ fontSize: '14px', marginTop: '2px' }}>{selectedProvider.location}</div>
                </div>
                <div>
                  <div style={{ fontSize: '11.5px', color: '#64736a', textTransform: 'uppercase', fontWeight: 600 }}>Rating &amp; Reputation</div>
                  <div style={{ fontSize: '14px', marginTop: '2px', fontWeight: 600, color: '#256b4a' }}>
                    ★ {selectedProvider.rating.toFixed(1)} ({selectedProvider.completedJobs} jobs completed)
                  </div>
                </div>
                <div>
                  <div style={{ fontSize: '11.5px', color: '#64736a', textTransform: 'uppercase', fontWeight: 600 }}>KYC &amp; Vetting Status</div>
                  <div style={{ marginTop: '4px' }}>
                    <span className={`admin-badge ${selectedProvider.kycStatus === 'Verified' ? 'status-resolved' : 'status-waiting'}`}>
                      {selectedProvider.kycStatus}
                    </span>
                  </div>
                </div>
              </div>

              {selectedProvider.skills && (
                <div>
                  <div style={{ fontSize: '11.5px', color: '#64736a', textTransform: 'uppercase', fontWeight: 600, marginBottom: '4px' }}>Skills &amp; Specialties</div>
                  <div style={{ background: '#f5f7f5', padding: '10px 14px', borderRadius: '8px', fontSize: '13px' }}>
                    {selectedProvider.skills}
                  </div>
                </div>
              )}

              {selectedProvider.services && (
                <div>
                  <div style={{ fontSize: '11.5px', color: '#64736a', textTransform: 'uppercase', fontWeight: 600, marginBottom: '4px' }}>Available Service Catalog</div>
                  <div style={{ background: '#f5f7f5', padding: '10px 14px', borderRadius: '8px', fontSize: '13px' }}>
                    {selectedProvider.services}
                  </div>
                </div>
              )}

              {selectedProvider.bio && (
                <div>
                  <div style={{ fontSize: '11.5px', color: '#64736a', textTransform: 'uppercase', fontWeight: 600, marginBottom: '4px' }}>Bio / Overview</div>
                  <div style={{ background: '#f5f7f5', padding: '10px 14px', borderRadius: '8px', fontSize: '13px', fontStyle: 'italic' }}>
                    "{selectedProvider.bio}"
                  </div>
                </div>
              )}
            </div>

            <div className="admin-modal-footer">
              <button
                type="button"
                className="admin-btn admin-btn-secondary"
                onClick={() => setSelectedProvider(null)}
              >
                Close
              </button>
              <button
                type="button"
                className="admin-btn admin-btn-primary"
                onClick={() => {
                  handleToggleStatus(selectedProvider);
                }}
              >
                {selectedProvider.accountStatus === 'Active' ? 'Suspend Account' : 'Activate Account'}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};
