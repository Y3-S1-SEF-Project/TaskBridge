import React, { useState, useEffect } from 'react';
import type { DisputeRecord } from '../types';
import { fetchAdminDisputes, resolveAdminDispute } from '../api';

export const ComplaintsView: React.FC = () => {
  const [disputes, setDisputes] = useState<DisputeRecord[]>([]);
  const [loading, setLoading] = useState(true);
  const [search, setSearch] = useState('');
  const [statusFilter, setStatusFilter] = useState('All');
  const [selectedDispute, setSelectedDispute] = useState<DisputeRecord | null>(null);

  // Resolution modal state
  const [resolutionAction, setResolutionAction] = useState<'Completed' | 'Cancelled'>('Completed');
  const [resolutionSummary, setResolutionSummary] = useState('');
  const [resolving, setResolving] = useState(false);
  const [feedbackMsg, setFeedbackMsg] = useState<{ type: 'success' | 'error'; text: string } | null>(null);
  const [activePhoto, setActivePhoto] = useState<string | null>(null);

  useEffect(() => {
    loadDisputes();
  }, [statusFilter]);

  const loadDisputes = async () => {
    setLoading(true);
    try {
      const res = await fetchAdminDisputes({
        status: statusFilter,
        search,
      });
      setDisputes(res.disputes || []);
    } catch (err) {
      console.error('Error fetching disputes:', err);
    } finally {
      setLoading(false);
    }
  };

  const handleSearchSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    loadDisputes();
  };

  const handleOpenDispute = (disp: DisputeRecord) => {
    setSelectedDispute(disp);
    setResolutionAction(disp.resolutionAction === 'Cancelled' ? 'Cancelled' : 'Completed');
    setResolutionSummary(disp.resolutionSummary || '');
    setFeedbackMsg(null);
    setActivePhoto(null);
  };

  const handleResolve = async () => {
    if (!selectedDispute) return;
    if (!resolutionSummary.trim()) {
      setFeedbackMsg({ type: 'error', text: 'Please enter a resolution summary or explanation.' });
      return;
    }

    setResolving(true);
    setFeedbackMsg(null);
    try {
      const res = await resolveAdminDispute(
        selectedDispute.id,
        resolutionAction,
        resolutionSummary.trim()
      );

      setFeedbackMsg({
        type: 'success',
        text: `Dispute resolved successfully! Booking #${selectedDispute.bookingReference} marked as "${res.bookingStatus}".`,
      });

      setSelectedDispute(res.dispute);
      await loadDisputes();
    } catch (err: any) {
      setFeedbackMsg({ type: 'error', text: err.message || 'Failed to resolve dispute.' });
    } finally {
      setResolving(false);
    }
  };

  const totalCount = disputes.length;
  const pendingCount = disputes.filter(d => d.status === 'PendingAdminReview' || d.status === 'UnderInvestigation').length;
  const resolvedCount = disputes.filter(d => d.status === 'Resolved' || d.status.startsWith('Resolved_')).length;

  const filtered = disputes.filter(d => {
    if (!search.trim()) return true;
    const s = search.toLowerCase();
    return d.disputeReference.toLowerCase().includes(s) ||
      d.bookingReference.toLowerCase().includes(s) ||
      d.customerName.toLowerCase().includes(s) ||
      d.providerName.toLowerCase().includes(s) ||
      d.serviceTitle.toLowerCase().includes(s) ||
      d.reasonCategory.toLowerCase().includes(s);
  });

  return (
    <div className="admin-content">
      {/* Header */}
      <div className="admin-page-header">
        <div>
          <h1 className="admin-page-title">Customer Disputes & Complaints</h1>
          <p className="admin-page-subtitle">
            Formal job completion disputes, quality escalations, and administrative mediation console.
          </p>
        </div>
        <button
          type="button"
          className="admin-export-btn"
          onClick={() => loadDisputes()}
          disabled={loading}
        >
          <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.2">
            <polyline points="23 4 23 10 17 10" />
            <polyline points="1 20 1 14 7 14" />
            <path d="M3.51 9a9 9 0 0 1 14.85-3.36L23 10M1 14l4.64 4.36A9 9 0 0 0 20.49 15" />
          </svg>
          Refresh Feed
        </button>
      </div>

      {/* Metrics Bar */}
      <div className="admin-metrics-grid">
        <div className="admin-metric-card">
          <p className="admin-metric-label">Active / Open Disputes</p>
          <div className="admin-metric-value" style={{ color: pendingCount > 0 ? '#b91c1c' : '#15803d' }}>
            {pendingCount}
          </div>
          <p className="admin-metric-note">Jobs held on freeze awaiting admin review</p>
        </div>

        <div className="admin-metric-card">
          <p className="admin-metric-label">Resolved Disputes</p>
          <div className="admin-metric-value" style={{ color: '#15803d' }}>
            {resolvedCount}
          </div>
          <p className="admin-metric-note positive">Mediation concluded & bookings settled</p>
        </div>

        <div className="admin-metric-card">
          <p className="admin-metric-label">Total Logged Disputes</p>
          <div className="admin-metric-value">{totalCount}</div>
          <p className="admin-metric-note">Historical records across all categories</p>
        </div>

        <div className="admin-metric-card">
          <p className="admin-metric-label">Resolution Rate</p>
          <div className="admin-metric-value">
            {totalCount > 0 ? `${Math.round((resolvedCount / totalCount) * 100)}%` : '100%'}
          </div>
          <p className="admin-metric-note positive">Target resolution &lt; 24 hours</p>
        </div>
      </div>

      {/* Main Table Card */}
      <div className="admin-table-card">
        <form onSubmit={handleSearchSubmit} className="admin-toolbar" style={{ padding: '20px 24px 16px' }}>
          <div className="admin-search-box">
            <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
              <circle cx="11" cy="11" r="8" />
              <line x1="21" y1="21" x2="16.65" y2="16.65" />
            </svg>
            <input
              type="text"
              placeholder="Search dispute #, booking ref, customer, provider..."
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
            <option value="Pending">Open / Pending Review</option>
            <option value="Resolved">Resolved</option>
          </select>
        </form>

        <div className="admin-table-container">
          <table className="admin-table">
            <thead>
              <tr>
                <th style={{ width: '105px' }}>Dispute / Ref</th>
                <th style={{ width: '130px' }}>Complainant</th>
                <th style={{ width: '120px' }}>Provider</th>
                <th style={{ width: '140px' }}>Service</th>
                <th>Issue</th>
                <th style={{ width: '95px' }}>Fee</th>
                <th style={{ width: '90px' }}>Status</th>
                <th style={{ width: '85px' }}>Filed At</th>
                <th className="actions-col" style={{ textAlign: 'right', paddingRight: '20px' }}>Actions</th>
              </tr>
            </thead>
            <tbody>
              {loading ? (
                <tr>
                  <td colSpan={9} style={{ textAlign: 'center', padding: '40px', color: '#64736a' }}>
                    Loading dispute cases...
                  </td>
                </tr>
              ) : filtered.length === 0 ? (
                <tr>
                  <td colSpan={9} style={{ textAlign: 'center', padding: '40px', color: '#64736a' }}>
                    No disputes match the selected filters.
                  </td>
                </tr>
              ) : (
                filtered.map((d) => {
                  const isResolved = d.status === 'Resolved' || d.status.startsWith('Resolved_');
                  return (
                    <tr key={d.id}>
                      <td>
                        <span className="admin-inquiry-code" style={{ color: '#b91c1c', fontWeight: 700, fontSize: '12px' }}>
                          {d.disputeReference}
                        </span>
                        <div style={{ fontFamily: 'monospace', fontWeight: 600, fontSize: '11px', color: '#64736a', marginTop: '2px' }}>
                          #{d.bookingReference}
                        </div>
                      </td>
                      <td>
                        <strong style={{ fontSize: '13px' }}>{d.customerName}</strong>
                      </td>
                      <td>
                        <span style={{ fontSize: '13px' }}>{d.providerName}</span>
                      </td>
                      <td>
                        <div style={{ fontWeight: 600, fontSize: '12.5px', maxWidth: '140px', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                          {d.serviceTitle}
                        </div>
                        <div style={{ fontSize: '11px', color: '#64736a' }}>{d.category}</div>
                      </td>
                      <td>
                        <span className="admin-badge priority-normal" style={{ fontSize: '11px' }}>
                          {d.reasonCategory}
                        </span>
                      </td>
                      <td>
                        <strong style={{ fontWeight: 700, color: '#0f172a', fontSize: '12.5px', whiteSpace: 'nowrap' }}>
                          Rs. {d.feeAmount.toLocaleString('en-US', { minimumFractionDigits: 2 })}
                        </strong>
                      </td>
                      <td>
                        <span
                          className={`admin-badge ${
                            isResolved ? 'status-resolved' : 'priority-high'
                          }`}
                        >
                          {isResolved ? 'Resolved' : 'Under Review'}
                        </span>
                      </td>
                      <td style={{ fontSize: '12px', color: '#64736a', whiteSpace: 'nowrap' }}>
                        {new Date(d.createdAt).toLocaleDateString('en-GB', {
                          day: '2-digit',
                          month: 'short',
                          year: 'numeric',
                        })}
                      </td>
                      <td className="actions-col" style={{ textAlign: 'right', paddingRight: '20px' }}>
                        <button
                          type="button"
                          className="admin-btn admin-btn-secondary"
                          style={{
                            padding: '5px 12px',
                            fontSize: '12px',
                            fontWeight: 600,
                            whiteSpace: 'nowrap',
                          }}
                          onClick={() => handleOpenDispute(d)}
                          title="View dispute mediation and resolution details"
                        >
                          {isResolved ? 'View Details' : 'View / Resolve'}
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
          <div>Showing {filtered.length} of {disputes.length} disputes</div>
        </div>
      </div>

      {/* Dispute Mediation & Resolution Modal */}
      {selectedDispute && (
        <div
          className="admin-modal-backdrop"
          style={{
            position: 'fixed',
            inset: 0,
            backgroundColor: 'rgba(15, 23, 42, 0.65)',
            backdropFilter: 'blur(6px)',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            zIndex: 1000,
            padding: '20px',
          }}
          onClick={() => setSelectedDispute(null)}
        >
          <div
            style={{
              backgroundColor: '#ffffff',
              borderRadius: '16px',
              border: '1px solid #e2e8f0',
              boxShadow: '0 25px 60px -15px rgba(0, 0, 0, 0.35)',
              width: '100%',
              maxWidth: '820px',
              maxHeight: '90vh',
              overflowY: 'auto',
              padding: '24px 28px',
              color: '#0f172a',
            }}
            onClick={(e) => e.stopPropagation()}
          >
            {/* Modal Header */}
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', borderBottom: '1px solid #e2e8f0', paddingBottom: '16px', marginBottom: '20px' }}>
              <div>
                <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
                  <span style={{ color: '#b91c1c', fontWeight: 900, fontSize: '20px', letterSpacing: '0.5px' }}>
                    {selectedDispute.disputeReference}
                  </span>
                  <span
                    className={`admin-badge ${
                      selectedDispute.status === 'Resolved' || selectedDispute.status.startsWith('Resolved_')
                        ? 'status-resolved'
                        : 'priority-high'
                    }`}
                  >
                    {selectedDispute.status === 'Resolved' || selectedDispute.status.startsWith('Resolved_')
                      ? 'Resolved'
                      : 'Pending Admin Mediation'}
                  </span>
                </div>
                <div style={{ fontSize: '13px', color: '#64736a', marginTop: '4px' }}>
                  Booking Reference: <strong>#{selectedDispute.bookingReference}</strong> · Filed on{' '}
                  {new Date(selectedDispute.createdAt).toLocaleString()}
                </div>
              </div>
              <button
                type="button"
                className="admin-sidebar-close-btn"
                onClick={() => setSelectedDispute(null)}
                style={{ fontSize: '18px', background: 'none', border: 'none', cursor: 'pointer' }}
              >
                ✕
              </button>
            </div>

            {/* Notification alert message if any */}
            {feedbackMsg && (
              <div
                style={{
                  padding: '12px 16px',
                  borderRadius: '10px',
                  marginBottom: '18px',
                  fontSize: '13px',
                  fontWeight: 600,
                  backgroundColor: feedbackMsg.type === 'success' ? '#f0fdf4' : '#fef2f2',
                  color: feedbackMsg.type === 'success' ? '#15803d' : '#b91c1c',
                  border: `1px solid ${feedbackMsg.type === 'success' ? '#bbf7d0' : '#fecaca'}`,
                }}
              >
                {feedbackMsg.text}
              </div>
            )}

            {/* Dispute Parties Grid */}
            <div
              style={{
                display: 'grid',
                gridTemplateColumns: '1fr 1fr',
                gap: '16px',
                backgroundColor: '#f8fafc',
                padding: '16px',
                borderRadius: '12px',
                marginBottom: '20px',
              }}
            >
              <div>
                <span style={{ fontSize: '11px', textTransform: 'uppercase', color: '#64736a', fontWeight: 800 }}>
                  Customer (Complainant)
                </span>
                <div style={{ fontWeight: 800, fontSize: '15px', color: '#0f172a', marginTop: '2px' }}>
                  {selectedDispute.customerName}
                </div>
                {selectedDispute.customerPhone && (
                  <div style={{ fontSize: '12px', color: '#475569' }}>📞 {selectedDispute.customerPhone}</div>
                )}
              </div>
              <div>
                <span style={{ fontSize: '11px', textTransform: 'uppercase', color: '#64736a', fontWeight: 800 }}>
                  Specialist / Provider
                </span>
                <div style={{ fontWeight: 800, fontSize: '15px', color: '#0f172a', marginTop: '2px' }}>
                  {selectedDispute.providerName}
                </div>
                <div style={{ fontSize: '12px', color: '#475569' }}>
                  Job: {selectedDispute.serviceTitle} ({selectedDispute.category})
                </div>
              </div>
            </div>

            {/* Customer Issue Details */}
            <div style={{ marginBottom: '20px' }}>
              <h4 style={{ margin: '0 0 10px 0', fontSize: '14px', fontWeight: 800, color: '#0f172a' }}>
                Customer Dispute Statement
              </h4>
              <div
                style={{
                  backgroundColor: '#fff',
                  border: '1px solid #e2e8f0',
                  borderRadius: '10px',
                  padding: '14px 16px',
                }}
              >
                <div style={{ display: 'flex', gap: '20px', marginBottom: '8px' }}>
                  <div>
                    <span style={{ fontSize: '11px', color: '#64736a' }}>Reason Category: </span>
                    <strong style={{ color: '#b91c1c' }}>{selectedDispute.reasonCategory}</strong>
                  </div>
                  <div>
                    <span style={{ fontSize: '11px', color: '#64736a' }}>Desired Resolution: </span>
                    <strong style={{ color: '#0369a1' }}>{selectedDispute.desiredResolution}</strong>
                  </div>
                  <div>
                    <span style={{ fontSize: '11px', color: '#64736a' }}>Job Total: </span>
                    <strong>Rs. {selectedDispute.feeAmount.toLocaleString('en-US', { minimumFractionDigits: 2 })}</strong>
                  </div>
                </div>
                <p style={{ margin: 0, fontSize: '13.5px', color: '#334155', lineHeight: '1.5', whiteSpace: 'pre-wrap' }}>
                  "{selectedDispute.description}"
                </p>
              </div>
            </div>

            {/* Visual Evidence: Before vs After Photos */}
            <div style={{ marginBottom: '24px' }}>
              <h4 style={{ margin: '0 0 10px 0', fontSize: '14px', fontWeight: 800, color: '#0f172a' }}>
                Job Photo Evidence Submitted by Provider
              </h4>
              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '16px' }}>
                {/* Before Photos */}
                <div style={{ border: '1px solid #e2e8f0', borderRadius: '10px', padding: '12px' }}>
                  <div style={{ fontSize: '12px', fontWeight: 800, color: '#475569', marginBottom: '8px' }}>
                    📷 Before Photos ({selectedDispute.beforePhotoUrls.length})
                  </div>
                  {selectedDispute.beforePhotoUrls.length === 0 ? (
                    <div style={{ height: '110px', display: 'flex', alignItems: 'center', justifyContent: 'center', backgroundColor: '#f1f5f9', borderRadius: '8px', color: '#94a3b8', fontSize: '12px' }}>
                      No before photos provided
                    </div>
                  ) : (
                    <div style={{ display: 'flex', gap: '8px', flexWrap: 'wrap' }}>
                      {selectedDispute.beforePhotoUrls.map((url, i) => (
                        <img
                          key={i}
                          src={url}
                          alt={`Before ${i + 1}`}
                          style={{ width: '90px', height: '90px', objectFit: 'cover', borderRadius: '8px', cursor: 'pointer', border: '2px solid transparent' }}
                          onClick={() => setActivePhoto(url)}
                          title="Click to view large"
                        />
                      ))}
                    </div>
                  )}
                </div>

                {/* After Photos */}
                <div style={{ border: '1px solid #e2e8f0', borderRadius: '10px', padding: '12px' }}>
                  <div style={{ fontSize: '12px', fontWeight: 800, color: '#475569', marginBottom: '8px' }}>
                    ✨ After Photos ({selectedDispute.afterPhotoUrls.length})
                  </div>
                  {selectedDispute.afterPhotoUrls.length === 0 ? (
                    <div style={{ height: '110px', display: 'flex', alignItems: 'center', justifyContent: 'center', backgroundColor: '#f1f5f9', borderRadius: '8px', color: '#94a3b8', fontSize: '12px' }}>
                      No after photos provided
                    </div>
                  ) : (
                    <div style={{ display: 'flex', gap: '8px', flexWrap: 'wrap' }}>
                      {selectedDispute.afterPhotoUrls.map((url, i) => (
                        <img
                          key={i}
                          src={url}
                          alt={`After ${i + 1}`}
                          style={{ width: '90px', height: '90px', objectFit: 'cover', borderRadius: '8px', cursor: 'pointer', border: '2px solid transparent' }}
                          onClick={() => setActivePhoto(url)}
                          title="Click to view large"
                        />
                      ))}
                    </div>
                  )}
                </div>
              </div>

              {/* Customer evidence photos if present */}
              {selectedDispute.customerEvidencePhotoUrls && selectedDispute.customerEvidencePhotoUrls.length > 0 && (
                <div style={{ marginTop: '12px', border: '1px solid #fecaca', backgroundColor: '#fff5f5', borderRadius: '10px', padding: '12px' }}>
                  <div style={{ fontSize: '12px', fontWeight: 800, color: '#b91c1c', marginBottom: '8px' }}>
                    ⚠️ Customer Defect Evidence Photos ({selectedDispute.customerEvidencePhotoUrls.length})
                  </div>
                  <div style={{ display: 'flex', gap: '8px', flexWrap: 'wrap' }}>
                    {selectedDispute.customerEvidencePhotoUrls.map((url, i) => (
                      <img
                        key={i}
                        src={url}
                        alt={`Evidence ${i + 1}`}
                        style={{ width: '90px', height: '90px', objectFit: 'cover', borderRadius: '8px', cursor: 'pointer', border: '2px solid #ef4444' }}
                        onClick={() => setActivePhoto(url)}
                        title="Click to view large"
                      />
                    ))}
                  </div>
                </div>
              )}
            </div>

            {/* Active Large Image Preview Modal if clicked */}
            {activePhoto && (
              <div
                style={{
                  position: 'fixed',
                  top: 0,
                  left: 0,
                  right: 0,
                  bottom: 0,
                  backgroundColor: 'rgba(0,0,0,0.85)',
                  zIndex: 9999,
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  padding: '20px',
                }}
                onClick={() => setActivePhoto(null)}
              >
                <div style={{ position: 'relative', maxWidth: '90%', maxHeight: '90%' }}>
                  <img
                    src={activePhoto}
                    alt="Proof Preview"
                    style={{ maxWidth: '100%', maxHeight: '85vh', borderRadius: '12px', boxShadow: '0 20px 25px -5px rgba(0, 0, 0, 0.5)' }}
                  />
                  <div style={{ textAlign: 'center', marginTop: '10px', color: '#fff', fontSize: '13px' }}>
                    Tap anywhere to close preview
                  </div>
                </div>
              </div>
            )}

            {/* Admin Mediation & Resolution Box */}
            <div
              style={{
                borderTop: '2px dashed #e2e8f0',
                paddingTop: '20px',
                backgroundColor: '#fafaf9',
                padding: '20px',
                borderRadius: '12px',
              }}
            >
              <h4 style={{ margin: '0 0 12px 0', fontSize: '15px', fontWeight: 800, color: '#0f172a' }}>
                ⚖️ Admin Mediation Decision
              </h4>

              {selectedDispute.status === 'Resolved' || selectedDispute.status.startsWith('Resolved_') ? (
                <div
                  style={{
                    backgroundColor: '#f0fdf4',
                    border: '1px solid #bbf7d0',
                    borderRadius: '10px',
                    padding: '16px',
                  }}
                >
                  <div style={{ display: 'flex', alignItems: 'center', gap: '8px', color: '#15803d', fontWeight: 800 }}>
                    <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5">
                      <path d="M22 11.08V12a10 10 0 1 1-5.93-9.14" />
                      <polyline points="22 4 12 14.01 9 11.01" />
                    </svg>
                    Case Closed: {selectedDispute.resolutionAction === 'Cancelled' ? 'Booking Cancelled' : 'Issue Resolved & Completed'}
                  </div>
                  <p style={{ margin: '8px 0 4px 0', fontSize: '13px', color: '#334155' }}>
                    <strong>Admin Summary:</strong> {selectedDispute.resolutionSummary}
                  </p>
                  <div style={{ fontSize: '11px', color: '#64736a' }}>
                    Resolved by {selectedDispute.resolvedByAdminName || 'Operations Team'} on{' '}
                    {selectedDispute.resolvedAt ? new Date(selectedDispute.resolvedAt).toLocaleString() : 'N/A'}
                  </div>
                </div>
              ) : (
                <div>
                  <div style={{ marginBottom: '16px' }}>
                    <label style={{ display: 'block', fontSize: '13px', fontWeight: 800, color: '#1e293b', marginBottom: '8px' }}>
                      Resolution Action (Updates Booking Status):
                    </label>
                    <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '12px' }}>
                      <div
                        onClick={() => setResolutionAction('Completed')}
                        style={{
                          cursor: 'pointer',
                          padding: '12px 14px',
                          borderRadius: '10px',
                          border: `2px solid ${resolutionAction === 'Completed' ? '#15803d' : '#e2e8f0'}`,
                          backgroundColor: resolutionAction === 'Completed' ? '#f0fdf4' : '#ffffff',
                          transition: 'all 0.15s ease',
                          display: 'flex',
                          flexDirection: 'column',
                          gap: '4px',
                        }}
                      >
                        <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                          <span style={{ fontSize: '16px' }}>✅</span>
                          <strong style={{ fontSize: '13px', color: resolutionAction === 'Completed' ? '#15803d' : '#334155' }}>
                            Mark as "Completed"
                          </strong>
                        </div>
                        <p style={{ margin: 0, fontSize: '11.5px', color: '#64748b', lineHeight: 1.35 }}>
                          Approve resolution & move booking to <strong>Completed</strong> folder.
                        </p>
                      </div>

                      <div
                        onClick={() => setResolutionAction('Cancelled')}
                        style={{
                          cursor: 'pointer',
                          padding: '12px 14px',
                          borderRadius: '10px',
                          border: `2px solid ${resolutionAction === 'Cancelled' ? '#b91c1c' : '#e2e8f0'}`,
                          backgroundColor: resolutionAction === 'Cancelled' ? '#fef2f2' : '#ffffff',
                          transition: 'all 0.15s ease',
                          display: 'flex',
                          flexDirection: 'column',
                          gap: '4px',
                        }}
                      >
                        <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                          <span style={{ fontSize: '16px' }}>❌</span>
                          <strong style={{ fontSize: '13px', color: resolutionAction === 'Cancelled' ? '#b91c1c' : '#334155' }}>
                            Cancel Booking
                          </strong>
                        </div>
                        <p style={{ margin: 0, fontSize: '11.5px', color: '#64748b', lineHeight: 1.35 }}>
                          Reject work, cancel job & move booking to <strong>Cancelled</strong> folder.
                        </p>
                      </div>
                    </div>
                  </div>

                  <div style={{ marginBottom: '16px' }}>
                    <label style={{ display: 'block', fontSize: '12px', fontWeight: 700, color: '#334155', marginBottom: '6px' }}>
                      Admin Resolution Summary (Delivered to Customer and Provider):
                    </label>
                    <textarea
                      rows={3}
                      value={resolutionSummary}
                      onChange={(e) => setResolutionSummary(e.target.value)}
                      placeholder="Explain the mediation outcome (e.g., Photos verified, agreed on resolution, booking status updated accordingly)..."
                      style={{
                        width: '100%',
                        padding: '10px 12px',
                        borderRadius: '8px',
                        border: '1px solid #cbd5e1',
                        fontSize: '13px',
                        fontFamily: 'inherit',
                        backgroundColor: '#ffffff',
                        color: '#0f172a',
                        boxSizing: 'border-box',
                      }}
                    />
                  </div>

                  <div style={{ display: 'flex', justifyContent: 'flex-end', gap: '10px' }}>
                    <button
                      type="button"
                      className="admin-btn admin-btn-secondary"
                      onClick={() => setSelectedDispute(null)}
                      disabled={resolving}
                    >
                      Cancel
                    </button>
                    <button
                      type="button"
                      className="admin-btn admin-btn-primary"
                      style={{
                        backgroundColor: resolutionAction === 'Cancelled' ? '#dc2626' : '#16a34a',
                        borderColor: resolutionAction === 'Cancelled' ? '#dc2626' : '#16a34a',
                        fontWeight: 800,
                        padding: '8px 20px',
                      }}
                      onClick={handleResolve}
                      disabled={resolving}
                    >
                      {resolving ? 'Submitting Decision...' : `Confirm Resolution: Mark as ${resolutionAction}`}
                    </button>
                  </div>
                </div>
              )}
            </div>
          </div>
        </div>
      )}
    </div>
  );
};
