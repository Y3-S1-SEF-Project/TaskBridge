import React, { useState, useEffect } from 'react';
import { fetchAdminInquiries, respondAdminInquiry } from '../api';
import type { SupportInquiryRecord } from '../types';

export const InquiriesView: React.FC = () => {
  const [inquiries, setInquiries] = useState<SupportInquiryRecord[]>([]);
  const [totalCount, setTotalCount] = useState(0);
  const [openCount, setOpenCount] = useState(0);
  const [respondedCount, setRespondedCount] = useState(0);
  const [resolvedCount, setResolvedCount] = useState(0);
  const [loading, setLoading] = useState(true);

  // Filters
  const [search, setSearch] = useState('');
  const [priorityFilter, setPriorityFilter] = useState('All');
  const [statusFilter, setStatusFilter] = useState('All');

  // Modal & Response State
  const [selectedInquiry, setSelectedInquiry] = useState<SupportInquiryRecord | null>(null);
  const [adminResponseText, setAdminResponseText] = useState('');
  const [newStatus, setNewStatus] = useState<'Responded' | 'Resolved' | 'InProgress'>('Responded');
  const [submitting, setSubmitting] = useState(false);
  const [activePhoto, setActivePhoto] = useState<string | null>(null);
  const [feedback, setFeedback] = useState<{ type: 'success' | 'error'; text: string } | null>(null);

  const loadData = async () => {
    try {
      setLoading(true);
      const res = await fetchAdminInquiries({
        status: statusFilter,
        priority: priorityFilter,
        search,
      });
      setInquiries(res.inquiries);
      setTotalCount(res.totalCount);
      setOpenCount(res.openCount);
      setRespondedCount(res.respondedCount);
      setResolvedCount(res.resolvedCount);
    } catch {
      // ignore
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadData();
  }, [priorityFilter, statusFilter]);

  const handleSearchSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    loadData();
  };

  const handleOpenInquiry = (inq: SupportInquiryRecord) => {
    setSelectedInquiry(inq);
    setAdminResponseText(inq.adminResponse || '');
    setNewStatus(
      inq.status === 'Resolved'
        ? 'Resolved'
        : inq.status === 'Responded'
        ? 'Responded'
        : 'Responded'
    );
    setFeedback(null);
  };

  const handleSendResponse = async () => {
    if (!selectedInquiry) return;
    if (!adminResponseText.trim()) {
      setFeedback({ type: 'error', text: 'Please enter a response message for the user.' });
      return;
    }

    try {
      setSubmitting(true);
      setFeedback(null);
      const updated = await respondAdminInquiry(selectedInquiry.id, {
        responseMessage: adminResponseText.trim(),
        status: newStatus,
        adminName: 'TaskBridge Support Desk',
      });
      if (updated) {
        setSelectedInquiry(updated);
        setFeedback({ type: 'success', text: `Response sent to ${updated.userName} successfully!` });
        loadData();
      }
    } catch (err: any) {
      setFeedback({ type: 'error', text: err.message || 'Failed to send response.' });
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <div className="admin-content">
      {/* Header */}
      <div className="admin-page-header">
        <div>
          <h1 className="admin-page-title">Support & System Inquiries</h1>
          <p className="admin-page-subtitle">
            System issue reports, feature bugs, billing questions, and general inquiries submitted by users.
          </p>
        </div>
        <button
          type="button"
          className="admin-export-btn"
          onClick={() => loadData()}
        >
          <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.2">
            <polyline points="23 4 23 10 17 10" />
            <path d="M20.49 15a9 9 0 1 1-2.12-9.36L23 10" />
          </svg>
          Refresh Inquiries
        </button>
      </div>

      {/* Metrics */}
      <div className="admin-metrics-grid">
        <div className="admin-metric-card">
          <p className="admin-metric-label">Open Inquiries</p>
          <div className="admin-metric-value" style={{ color: openCount > 0 ? '#c81e1e' : '#15803d' }}>
            {openCount}
          </div>
          <p className="admin-metric-note">Awaiting supervisor response</p>
        </div>
        <div className="admin-metric-card">
          <p className="admin-metric-label">Responded</p>
          <div className="admin-metric-value" style={{ color: '#2563eb' }}>
            {respondedCount}
          </div>
          <p className="admin-metric-note">Response delivered to customer</p>
        </div>
        <div className="admin-metric-card">
          <p className="admin-metric-label">Resolved Cases</p>
          <div className="admin-metric-value" style={{ color: '#15803d' }}>
            {resolvedCount}
          </div>
          <p className="admin-metric-note positive">Closed inquiries</p>
        </div>
        <div className="admin-metric-card">
          <p className="admin-metric-label">Total Volume</p>
          <div className="admin-metric-value">{totalCount}</div>
          <p className="admin-metric-note positive">All-time tickets</p>
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
              placeholder="Search inquiry #, subject, customer, category..."
              value={search}
              onChange={(e) => setSearch(e.target.value)}
            />
          </div>

          <div style={{ display: 'flex', gap: '10px' }}>
            <select
              className="admin-filter-select"
              value={priorityFilter}
              onChange={(e) => setPriorityFilter(e.target.value)}
            >
              <option value="All">All Priorities</option>
              <option value="Urgent">Urgent</option>
              <option value="High">High</option>
              <option value="Normal">Normal</option>
            </select>

            <select
              className="admin-filter-select"
              value={statusFilter}
              onChange={(e) => setStatusFilter(e.target.value)}
            >
              <option value="All">All Statuses</option>
              <option value="Open">Open</option>
              <option value="Responded">Responded</option>
              <option value="Resolved">Resolved</option>
            </select>
          </div>
        </form>

        <div className="admin-table-container">
          <table className="admin-table">
            <thead>
              <tr>
                <th>Inquiry #</th>
                <th>User / Complainant</th>
                <th>Role</th>
                <th>Category</th>
                <th>Subject</th>
                <th>Priority</th>
                <th>Status</th>
                <th>Filed At</th>
                <th className="actions-col">Actions</th>
              </tr>
            </thead>
            <tbody>
              {loading ? (
                <tr>
                  <td colSpan={9} style={{ textAlign: 'center', padding: '40px', color: '#64736a' }}>
                    Loading user inquiries...
                  </td>
                </tr>
              ) : inquiries.length === 0 ? (
                <tr>
                  <td colSpan={9} style={{ textAlign: 'center', padding: '40px', color: '#64736a' }}>
                    No inquiries found.
                  </td>
                </tr>
              ) : (
                inquiries.map((inq) => {
                  const isResolved = inq.status === 'Resolved';
                  const isResponded = inq.status === 'Responded';
                  const isUrgent = inq.priority === 'Urgent' || inq.priority === 'High';

                  return (
                    <tr key={inq.id}>
                      <td>
                        <span style={{ fontFamily: 'monospace', fontWeight: 800, color: '#0369a1' }}>
                          #{inq.inquiryReference}
                        </span>
                      </td>
                      <td>
                        <div style={{ fontWeight: 700, color: '#0f172a' }}>{inq.userName}</div>
                        {inq.userEmail && (
                          <div style={{ fontSize: '11px', color: '#64748b' }}>{inq.userEmail}</div>
                        )}
                      </td>
                      <td>
                        <span className="admin-badge priority-normal" style={{ fontSize: '11px' }}>
                          {inq.userRole}
                        </span>
                      </td>
                      <td>
                        <span style={{ fontSize: '12px', fontWeight: 600, color: '#334155' }}>
                          {inq.category}
                        </span>
                      </td>
                      <td>
                        <div style={{ fontWeight: 600, maxWidth: '240px', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                          {inq.subject}
                        </div>
                      </td>
                      <td>
                        <span
                          className={`admin-badge ${isUrgent ? 'priority-high' : 'priority-normal'}`}
                          style={{ fontSize: '11px' }}
                        >
                          {inq.priority}
                        </span>
                      </td>
                      <td>
                        <span
                          className={`admin-badge ${
                            isResolved
                              ? 'status-resolved'
                              : isResponded
                              ? 'status-active'
                              : 'priority-high'
                          }`}
                        >
                          {inq.status}
                        </span>
                      </td>
                      <td style={{ fontSize: '12px', color: '#64748b' }}>
                        {new Date(inq.createdAt).toLocaleDateString()}
                      </td>
                      <td className="actions-col">
                        <button
                          type="button"
                          className="admin-btn admin-btn-secondary"
                          style={{ fontSize: '12px', padding: '6px 12px' }}
                          onClick={() => handleOpenInquiry(inq)}
                        >
                          {inq.adminResponse ? 'View / Update' : 'Respond'}
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
          <div>Showing {inquiries.length} inquiries</div>
        </div>
      </div>

      {/* Inquiry Details & Response Modal */}
      {selectedInquiry && (
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
          onClick={() => setSelectedInquiry(null)}
        >
          <div
            style={{
              backgroundColor: '#ffffff',
              borderRadius: '16px',
              border: '1px solid #e2e8f0',
              boxShadow: '0 25px 60px -15px rgba(0, 0, 0, 0.35)',
              width: '100%',
              maxWidth: '750px',
              maxHeight: '90vh',
              overflowY: 'auto',
              padding: '24px 28px',
              color: '#0f172a',
            }}
            onClick={(e) => e.stopPropagation()}
          >
            {/* Header */}
            <div
              style={{
                display: 'flex',
                justifyContent: 'space-between',
                alignItems: 'flex-start',
                borderBottom: '1px solid #e2e8f0',
                paddingBottom: '16px',
                marginBottom: '20px',
              }}
            >
              <div>
                <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
                  <span style={{ color: '#0369a1', fontWeight: 900, fontSize: '20px' }}>
                    #{selectedInquiry.inquiryReference}
                  </span>
                  <span
                    className={`admin-badge ${
                      selectedInquiry.status === 'Resolved'
                        ? 'status-resolved'
                        : selectedInquiry.status === 'Responded'
                        ? 'status-active'
                        : 'priority-high'
                    }`}
                  >
                    {selectedInquiry.status}
                  </span>
                  <span className="admin-badge priority-normal" style={{ fontSize: '11px' }}>
                    {selectedInquiry.priority} Priority
                  </span>
                </div>
                <div style={{ fontSize: '13px', color: '#64748b', marginTop: '4px' }}>
                  Filed on {new Date(selectedInquiry.createdAt).toLocaleString()} · Category: <strong>{selectedInquiry.category}</strong>
                </div>
              </div>
              <button
                type="button"
                className="admin-sidebar-close-btn"
                onClick={() => setSelectedInquiry(null)}
                style={{ fontSize: '18px', background: 'none', border: 'none', cursor: 'pointer' }}
              >
                ✕
              </button>
            </div>

            {/* Alert */}
            {feedback && (
              <div
                style={{
                  padding: '12px 16px',
                  borderRadius: '10px',
                  marginBottom: '18px',
                  fontSize: '13px',
                  fontWeight: 600,
                  backgroundColor: feedback.type === 'success' ? '#f0fdf4' : '#fef2f2',
                  color: feedback.type === 'success' ? '#15803d' : '#b91c1c',
                  border: `1px solid ${feedback.type === 'success' ? '#bbf7d0' : '#fecaca'}`,
                }}
              >
                {feedback.text}
              </div>
            )}

            {/* User Profile Card */}
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
                <span style={{ fontSize: '11px', textTransform: 'uppercase', color: '#64748b', fontWeight: 800 }}>
                  User Details
                </span>
                <div style={{ fontWeight: 800, fontSize: '15px', color: '#0f172a', marginTop: '2px' }}>
                  {selectedInquiry.userName}
                </div>
                {selectedInquiry.userPhone && (
                  <div style={{ fontSize: '12px', color: '#475569' }}>📞 {selectedInquiry.userPhone}</div>
                )}
                {selectedInquiry.userEmail && (
                  <div style={{ fontSize: '12px', color: '#475569' }}>✉️ {selectedInquiry.userEmail}</div>
                )}
              </div>
              <div>
                <span style={{ fontSize: '11px', textTransform: 'uppercase', color: '#64748b', fontWeight: 800 }}>
                  Account Role & Priority
                </span>
                <div style={{ fontWeight: 700, fontSize: '14px', color: '#0f172a', marginTop: '2px' }}>
                  {selectedInquiry.userRole}
                </div>
                <div style={{ fontSize: '12px', color: '#64748b' }}>
                  Severity: <strong>{selectedInquiry.priority}</strong>
                </div>
              </div>
            </div>

            {/* Inquiry Content Box */}
            <div
              style={{
                backgroundColor: '#f1f5f9',
                padding: '16px 20px',
                borderRadius: '12px',
                marginBottom: '20px',
                border: '1px solid #e2e8f0',
              }}
            >
              <div style={{ fontSize: '11px', fontWeight: 800, color: '#475569', textTransform: 'uppercase' }}>
                Subject / Issue Title
              </div>
              <div style={{ fontSize: '16px', fontWeight: 800, color: '#0f172a', margin: '4px 0 10px 0' }}>
                {selectedInquiry.subject}
              </div>
              <div style={{ fontSize: '11px', fontWeight: 800, color: '#475569', textTransform: 'uppercase' }}>
                User Description / Message
              </div>
              <div style={{ fontSize: '13.5px', color: '#334155', lineHeight: 1.5, marginTop: '4px', whiteSpace: 'pre-wrap' }}>
                {selectedInquiry.message}
              </div>
            </div>

            {/* Attachments if any */}
            {selectedInquiry.attachmentUrls && selectedInquiry.attachmentUrls.length > 0 && (
              <div style={{ marginBottom: '20px' }}>
                <span style={{ fontSize: '12px', fontWeight: 800, color: '#0f172a', display: 'block', marginBottom: '8px' }}>
                  Attached Screenshots / Proof ({selectedInquiry.attachmentUrls.length})
                </span>
                <div style={{ display: 'flex', gap: '10px', flexWrap: 'wrap' }}>
                  {selectedInquiry.attachmentUrls.map((url, i) => (
                    <img
                      key={i}
                      src={url}
                      alt="Attachment"
                      onClick={() => setActivePhoto(url)}
                      style={{
                        width: '80px',
                        height: '80px',
                        objectFit: 'cover',
                        borderRadius: '8px',
                        border: '1px solid #cbd5e1',
                        cursor: 'pointer',
                      }}
                    />
                  ))}
                </div>
              </div>
            )}

            {/* Lightbox */}
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
                    alt="Preview"
                    style={{ maxWidth: '100%', maxHeight: '85vh', borderRadius: '12px' }}
                  />
                </div>
              </div>
            )}

            {/* Existing Admin Response History */}
            {selectedInquiry.adminResponse && (
              <div
                style={{
                  backgroundColor: '#f0fdf4',
                  border: '1px solid #bbf7d0',
                  borderRadius: '12px',
                  padding: '16px',
                  marginBottom: '20px',
                }}
              >
                <div style={{ display: 'flex', alignItems: 'center', gap: '8px', color: '#15803d', fontWeight: 800 }}>
                  <span>💬 Previous Admin Response</span>
                </div>
                <p style={{ margin: '8px 0 6px 0', fontSize: '13px', color: '#1f2937', whiteSpace: 'pre-wrap' }}>
                  {selectedInquiry.adminResponse}
                </p>
                <div style={{ fontSize: '11px', color: '#64748b' }}>
                  Sent by {selectedInquiry.respondedByAdminName || 'Support Desk'} on{' '}
                  {selectedInquiry.respondedAt ? new Date(selectedInquiry.respondedAt).toLocaleString() : 'N/A'}
                </div>
              </div>
            )}

            {/* Admin Response Form */}
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
                ✍️ Write Admin Response to User
              </h4>

              <div style={{ marginBottom: '14px' }}>
                <label style={{ display: 'block', fontSize: '12px', fontWeight: 700, color: '#334155', marginBottom: '6px' }}>
                  Set Ticket Status After Responding:
                </label>
                <div style={{ display: 'flex', gap: '10px' }}>
                  {(['Responded', 'Resolved', 'InProgress'] as const).map((stat) => (
                    <button
                      key={stat}
                      type="button"
                      onClick={() => setNewStatus(stat)}
                      style={{
                        padding: '8px 14px',
                        borderRadius: '8px',
                        fontSize: '12.5px',
                        fontWeight: 700,
                        cursor: 'pointer',
                        border: `1.5px solid ${newStatus === stat ? '#2563eb' : '#cbd5e1'}`,
                        backgroundColor: newStatus === stat ? '#eff6ff' : '#ffffff',
                        color: newStatus === stat ? '#1d4ed8' : '#475569',
                      }}
                    >
                      {stat === 'Responded' ? 'Mark Responded' : stat === 'Resolved' ? 'Mark Resolved' : 'In Progress'}
                    </button>
                  ))}
                </div>
              </div>

              <div style={{ marginBottom: '16px' }}>
                <label style={{ display: 'block', fontSize: '12px', fontWeight: 700, color: '#334155', marginBottom: '6px' }}>
                  Official Response (Will be displayed to the user in their mobile app):
                </label>
                <textarea
                  rows={4}
                  value={adminResponseText}
                  onChange={(e) => setAdminResponseText(e.target.value)}
                  placeholder="Provide resolution details, explanation, or instructions for the user..."
                  style={{
                    width: '100%',
                    padding: '12px',
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
                  onClick={() => setSelectedInquiry(null)}
                  disabled={submitting}
                >
                  Cancel
                </button>
                <button
                  type="button"
                  className="admin-btn admin-btn-primary"
                  style={{
                    backgroundColor: '#0369a1',
                    borderColor: '#0284c7',
                    fontWeight: 800,
                  }}
                  onClick={handleSendResponse}
                  disabled={submitting}
                >
                  {submitting ? 'Sending Response...' : 'Send Response to User'}
                </button>
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};
export default InquiriesView;
