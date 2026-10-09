import React, { useState, useEffect } from 'react';
import type { ProviderVerificationItem, VerificationsSummary } from '../types';
import { fetchVerifications, adjudicateVerification } from '../api';

interface HumanReviewCase {
  id: string;
  bookingRef: string;
  agent: string;
  confidenceScore: number;
  flagReason: string;
  provider: string;
  customer: string;
  status: 'Pending Review' | 'Approved' | 'Rejected' | 'More Info Requested';
  timestamp: string;
}

const mockCases: HumanReviewCase[] = [
  { id: 'HREV-104', bookingRef: 'BK-499', agent: 'Review Agent (Vision)', confidenceScore: 68, flagReason: 'Bathroom repair photo blurry; unable to verify valve replacement autonomously', provider: 'Sunil Plumbing', customer: 'Malik De Silva', status: 'Pending Review', timestamp: '35 mins ago' },
  { id: 'HREV-103', bookingRef: 'BK-492', agent: 'Matching Agent (NLP)', confidenceScore: 72, flagReason: 'Ambiguous description: customer mentioned both electrical wiring and masonry work', provider: 'Pending Triage', customer: 'Hirantha Perera', status: 'Pending Review', timestamp: '1 hour ago' },
  { id: 'HREV-102', bookingRef: 'BK-481', agent: 'Planning Agent (Estimator)', confidenceScore: 61, flagReason: 'Estimated materials cost 300% higher than historical regional baseline', provider: 'Sanjaya Electricals', customer: 'Roshan Dias', status: 'Approved', timestamp: 'Yesterday' },
];

export const HumanReviewsView: React.FC = () => {
  const [activeTab, setActiveTab] = useState<'verifications' | 'ai_exceptions'>('verifications');

  // Verification state
  const [verificationsData, setVerificationsData] = useState<VerificationsSummary>({
    total: 0,
    pendingCount: 0,
    approvedCount: 0,
    rejectedCount: 0,
    unverifiedCount: 0,
    items: [],
  });
  const [loading, setLoading] = useState<boolean>(true);
  const [statusFilter, setStatusFilter] = useState<string>('All');
  const [searchQuery, setSearchQuery] = useState<string>('');
  const [inspectItem, setInspectItem] = useState<ProviderVerificationItem | null>(null);
  const [inspectPhotoIndex, setInspectPhotoIndex] = useState<number>(0);
  const [adjudicationNote, setAdjudicationNote] = useState<string>('');
  const [submittingAction, setSubmittingAction] = useState<boolean>(false);
  const [actionSuccessMsg, setActionSuccessMsg] = useState<string | null>(null);
  const [actionErrorMsg, setActionErrorMsg] = useState<string | null>(null);

  const getDocUrls = (item: ProviderVerificationItem | null): string[] => {
    if (!item) return [];
    if (item.documentUrls && item.documentUrls.length > 0) return item.documentUrls;
    if (item.verificationDocumentUrls && item.verificationDocumentUrls.length > 0) return item.verificationDocumentUrls;
    const raw = item.documentUrl || item.verificationDocumentUrl;
    if (!raw) return [];
    return raw.split(',').map(s => s.trim()).filter(Boolean);
  };

  // AI Exceptions state
  const [cases, setCases] = useState<HumanReviewCase[]>(mockCases);

  const loadVerifications = async () => {
    setLoading(true);
    try {
      const data = await fetchVerifications({
        status: statusFilter,
        search: searchQuery.trim(),
      });
      setVerificationsData(data);
    } catch (e) {
      console.error('Failed to load verifications:', e);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    if (activeTab === 'verifications') {
      loadVerifications();
    }
  }, [activeTab, statusFilter]);

  const handleSearchSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    loadVerifications();
  };

  const handleAdjudicate = async (
    item: ProviderVerificationItem,
    status: 'Approved' | 'Rejected',
    notes?: string
  ) => {
    setSubmittingAction(true);
    setActionErrorMsg(null);
    try {
      const targetId = item.providerProfileId || item.providerId || item.userId || '';
      await adjudicateVerification(targetId, {
        status,
        notes: notes || adjudicationNote,
      });

      setActionSuccessMsg(
        `Successfully ${status.toLowerCase()} provider ${item.fullName || item.businessName}.`
      );
      setTimeout(() => setActionSuccessMsg(null), 4000);

      // Refresh list
      await loadVerifications();

      // If inspect modal was open for this item, close or update
      if (inspectItem?.providerProfileId === item.providerProfileId) {
        setInspectItem(null);
        setAdjudicationNote('');
      }
    } catch (err: any) {
      setActionErrorMsg(err.message || `Failed to adjudicate verification.`);
    } finally {
      setSubmittingAction(false);
    }
  };

  const handleCaseAction = (id: string, newStatus: 'Approved' | 'Rejected') => {
    setCases(prev => prev.map(c => c.id === id ? { ...c, status: newStatus } : c));
  };

  const modalDocs = getDocUrls(inspectItem);
  const activeDocUrl = modalDocs[inspectPhotoIndex] || modalDocs[0] || '';

  return (
    <div className="admin-content">
      <div className="admin-page-header">
        <div>
          <h1 className="admin-page-title">Human-in-the-Loop Reviews</h1>
          <p className="admin-page-subtitle">
            Admin oversight queue for Provider Identity Verification (NIC / Driving License) and AI low-confidence exceptions.
          </p>
        </div>
        <div style={{ display: 'flex', gap: '8px' }}>
          <button
            type="button"
            className="admin-export-btn"
            onClick={loadVerifications}
            title="Refresh records"
          >
            <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.2">
              <path d="M23 4v6h-6" />
              <path d="M1 20v-6h6" />
              <path d="M3.51 9a9 9 0 0 1 14.85-3.36L23 10M1 14l4.64 4.36A9 9 0 0 0 20.49 15" />
            </svg>
            Refresh
          </button>
        </div>
      </div>

      {actionSuccessMsg && (
        <div style={{
          padding: '12px 16px',
          marginBottom: '16px',
          backgroundColor: '#e8f5ee',
          border: '1px solid #b8e5ca',
          borderRadius: '8px',
          color: '#1c553a',
          fontWeight: 600,
          display: 'flex',
          alignItems: 'center',
          gap: '8px'
        }}>
          <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5">
            <polyline points="20 6 9 17 4 12" />
          </svg>
          {actionSuccessMsg}
        </div>
      )}

      {actionErrorMsg && (
        <div style={{
          padding: '12px 16px',
          marginBottom: '16px',
          backgroundColor: '#fde8e8',
          border: '1px solid #fecaca',
          borderRadius: '8px',
          color: '#c81e1e',
          fontWeight: 600,
          display: 'flex',
          alignItems: 'center',
          gap: '8px'
        }}>
          <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5">
            <circle cx="12" cy="12" r="10" />
            <line x1="12" y1="8" x2="12" y2="12" />
            <line x1="12" y1="16" x2="12.01" y2="16" />
          </svg>
          {actionErrorMsg}
        </div>
      )}

      {/* Primary Tab Navigation */}
      <div style={{
        display: 'flex',
        gap: '8px',
        borderBottom: '2px solid #e3ebe6',
        marginBottom: '20px'
      }}>
        <button
          type="button"
          onClick={() => setActiveTab('verifications')}
          style={{
            padding: '10px 18px',
            fontSize: '14px',
            fontWeight: 700,
            cursor: 'pointer',
            border: 'none',
            background: 'none',
            borderBottom: activeTab === 'verifications' ? '3px solid #256b4a' : '3px solid transparent',
            color: activeTab === 'verifications' ? '#256b4a' : '#64736a',
            display: 'flex',
            alignItems: 'center',
            gap: '8px',
            marginBottom: '-2px'
          }}
        >
          <svg width="17" height="17" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
            <path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z" />
          </svg>
          Provider ID / DL Verifications
          {verificationsData.pendingCount > 0 && (
            <span style={{
              backgroundColor: '#c81e1e',
              color: '#ffffff',
              padding: '2px 7px',
              borderRadius: '10px',
              fontSize: '11px',
              fontWeight: 800
            }}>
              {verificationsData.pendingCount}
            </span>
          )}
        </button>

        <button
          type="button"
          onClick={() => setActiveTab('ai_exceptions')}
          style={{
            padding: '10px 18px',
            fontSize: '14px',
            fontWeight: 700,
            cursor: 'pointer',
            border: 'none',
            background: 'none',
            borderBottom: activeTab === 'ai_exceptions' ? '3px solid #256b4a' : '3px solid transparent',
            color: activeTab === 'ai_exceptions' ? '#256b4a' : '#64736a',
            display: 'flex',
            alignItems: 'center',
            gap: '8px',
            marginBottom: '-2px'
          }}
        >
          <svg width="17" height="17" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
            <polygon points="13 2 3 14 12 14 11 22 21 10 12 10 13 2" />
          </svg>
          AI Low-Confidence Exceptions
          <span style={{
            backgroundColor: '#edf5f0',
            color: '#256b4a',
            padding: '2px 7px',
            borderRadius: '10px',
            fontSize: '11px',
            fontWeight: 800
          }}>
            {cases.filter(c => c.status === 'Pending Review').length}
          </span>
        </button>
      </div>

      {activeTab === 'verifications' ? (
        <>
          {/* Metrics */}
          <div className="admin-metrics-grid">
            <div className="admin-metric-card">
              <p className="admin-metric-label">Pending Verification</p>
              <div className="admin-metric-value" style={{ color: '#d97706' }}>
                {verificationsData.pendingCount}
              </div>
              <p className="admin-metric-note">Awaiting admin document review</p>
            </div>
            <div className="admin-metric-card">
              <p className="admin-metric-label">Verified Providers</p>
              <div className="admin-metric-value" style={{ color: '#256b4a' }}>
                {verificationsData.approvedCount}
              </div>
              <p className="admin-metric-note positive">Badge active on customer & provider app</p>
            </div>
            <div className="admin-metric-card">
              <p className="admin-metric-label">Rejected / Revoked</p>
              <div className="admin-metric-value" style={{ color: '#c81e1e' }}>
                {verificationsData.rejectedCount}
              </div>
              <p className="admin-metric-note">Declined invalid/unclear document</p>
            </div>
            <div className="admin-metric-card">
              <p className="admin-metric-label">Total Submissions</p>
              <div className="admin-metric-value">
                {verificationsData.items.filter(it => getDocUrls(it).length > 0).length}
              </div>
              <p className="admin-metric-note">Document review backlog & history</p>
            </div>
          </div>

          {/* Filters & Search */}
          <div style={{
            display: 'flex',
            justifyContent: 'space-between',
            alignItems: 'center',
            flexWrap: 'wrap',
            gap: '12px',
            marginBottom: '16px'
          }}>
            <div style={{ display: 'flex', gap: '8px', flexWrap: 'wrap' }}>
              {(['All', 'Pending', 'Approved', 'Rejected'] as const).map(tab => {
                const isSelected = statusFilter === tab;
                const label = tab === 'All' ? 'All Submissions' : tab === 'Pending' ? 'Pending Review' : tab;
                return (
                  <button
                    key={tab}
                    type="button"
                    onClick={() => setStatusFilter(tab)}
                    style={{
                      fontSize: '13px',
                      padding: '7px 16px',
                      borderRadius: '8px',
                      fontWeight: 600,
                      cursor: 'pointer',
                      border: isSelected ? '1px solid #256b4a' : '1px solid #cbd5e1',
                      backgroundColor: isSelected ? '#256b4a' : '#ffffff',
                      color: isSelected ? '#ffffff' : '#334155',
                      boxShadow: isSelected ? '0 1px 3px rgba(37,107,74,0.3)' : 'none',
                      transition: 'all 0.15s ease'
                    }}
                  >
                    {label}
                  </button>
                );
              })}
            </div>

            <form onSubmit={handleSearchSubmit} style={{ display: 'flex', gap: '8px', alignItems: 'center' }}>
              <div style={{ position: 'relative', display: 'flex', alignItems: 'center' }}>
                <span style={{ position: 'absolute', left: '10px', color: '#64748b', display: 'flex', alignItems: 'center', pointerEvents: 'none' }}>
                  <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                    <circle cx="11" cy="11" r="8" />
                    <line x1="21" y1="21" x2="16.65" y2="16.65" />
                  </svg>
                </span>
                <input
                  type="text"
                  placeholder="Search provider name, category, phone..."
                  value={searchQuery}
                  onChange={e => setSearchQuery(e.target.value)}
                  style={{
                    padding: '8px 14px 8px 34px',
                    borderRadius: '8px',
                    border: '1px solid #cbd5e1',
                    backgroundColor: '#ffffff',
                    color: '#0f172a',
                    fontSize: '13px',
                    minWidth: '280px',
                    outline: 'none',
                    boxShadow: '0 1px 2px rgba(0,0,0,0.05)'
                  }}
                />
              </div>
              <button
                type="submit"
                style={{
                  padding: '8px 16px',
                  fontSize: '13px',
                  fontWeight: 600,
                  borderRadius: '8px',
                  border: '1px solid #cbd5e1',
                  backgroundColor: '#ffffff',
                  color: '#334155',
                  cursor: 'pointer',
                  boxShadow: '0 1px 2px rgba(0,0,0,0.05)'
                }}
              >
                Search
              </button>
            </form>
          </div>

          {/* Table */}
          <div className="admin-table-card">
            {(() => {
              const displayedItems = verificationsData.items.filter(item => getDocUrls(item).length > 0);
              return (
                <>
                  <h3 className="admin-table-title" style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                    <span>Provider Identity Documents (Stored in Cloudflare R2)</span>
                    <span style={{ fontSize: '12px', color: '#64736a', fontWeight: 'normal' }}>
                      {displayedItems.length} records matching filter
                    </span>
                  </h3>

                  {loading ? (
                    <div style={{ padding: '40px', textAlign: 'center', color: '#64736a' }}>
                      <div style={{ fontSize: '14px', fontWeight: 600 }}>Loading provider verification records...</div>
                    </div>
                  ) : displayedItems.length === 0 ? (
                    <div style={{ padding: '48px', textAlign: 'center', color: '#64736a' }}>
                      <svg width="40" height="40" viewBox="0 0 24 24" fill="none" stroke="#94a3b8" strokeWidth="1.5" style={{ margin: '0 auto 12px' }}>
                        <path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z" />
                      </svg>
                      <div style={{ fontWeight: 600, fontSize: '15px', color: '#1e293b' }}>No verifications found</div>
                      <div style={{ fontSize: '13px', marginTop: '4px' }}>
                        {statusFilter === 'Pending'
                          ? 'No pending identity verification submissions at this time.'
                          : 'Try selecting a different status filter or clear the search query.'}
                      </div>
                    </div>
                  ) : (
                    <div className="admin-table-container">
                      <table className="admin-table">
                        <thead>
                          <tr>
                            <th>Provider Details</th>
                            <th>Category & Location</th>
                            <th>Document Type</th>
                            <th>Cloudflare Document</th>
                            <th>Submitted Date</th>
                            <th>Status</th>
                            <th className="actions-col" style={{ textAlign: 'right', paddingRight: '20px' }}>Review / Action</th>
                          </tr>
                        </thead>
                        <tbody>
                          {displayedItems.map(item => {
                            const docs = getDocUrls(item);
                            const rawStatus = (item.status || item.verificationStatus || (item.isVerified ? 'Approved' : 'Pending')).toLowerCase();
                            const isApproved = rawStatus === 'approved' || item.isVerified === true;
                            const isPending = rawStatus === 'pending' && !isApproved;
                            const isRejected = rawStatus === 'rejected';

                            const docType = item.documentType || item.verificationDocumentType || (docs.length > 0 ? 'National ID' : null);
                            const submittedDate = item.submittedAt || item.verificationSubmittedAt;
                            const fullName = item.fullName || 'Provider';
                            const businessName = item.businessName || 'Independent';
                            const phone = item.phone || item.phoneNumber || 'N/A';
                            const city = item.city || item.location || 'Colombo';
                            const targetId = item.providerProfileId || item.providerId || item.userId;

                            return (
                              <tr key={targetId}>
                                <td>
                                  <div style={{ fontWeight: 700, fontSize: '14px', color: '#0f172a' }}>
                                    {fullName}
                                  </div>
                                  <div style={{ fontSize: '12px', color: '#475569' }}>
                                    {businessName}
                                  </div>
                                  <div style={{ fontSize: '11.5px', color: '#64748b', marginTop: '2px' }}>
                                    📞 {phone} • ✉️ {item.email || 'N/A'}
                                  </div>
                                </td>

                                <td>
                                  <span className="admin-badge priority-normal" style={{ fontSize: '11.5px' }}>
                                    {item.category || 'General'}
                                  </span>
                                  <div style={{ fontSize: '12px', color: '#64748b', marginTop: '4px' }}>
                                    📍 {city} • Rs. {item.hourlyRate}/hr
                                  </div>
                                </td>

                                <td>
                                  {docType ? (
                                    <span style={{
                                      display: 'inline-flex',
                                      alignItems: 'center',
                                      gap: '4px',
                                      padding: '3px 8px',
                                      borderRadius: '4px',
                                      fontSize: '12px',
                                      fontWeight: 600,
                                      backgroundColor: '#f1f5f9',
                                      color: '#334155'
                                    }}>
                                      <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                                        <rect x="3" y="4" width="18" height="16" rx="2" />
                                        <circle cx="9" cy="10" r="2" />
                                        <line x1="15" y1="8" x2="17" y2="8" />
                                        <line x1="15" y1="12" x2="17" y2="12" />
                                      </svg>
                                      {docType === 'DrivingLicense' ? 'Driving License' : 'National ID (NIC)'}
                                    </span>
                                  ) : (
                                    <span style={{ fontSize: '12px', color: '#94a3b8', fontStyle: 'italic' }}>
                                      Not uploaded
                                    </span>
                                  )}
                                </td>

                                <td>
                                  {docs.length === 0 ? (
                                    <span style={{ fontSize: '12px', color: '#94a3b8' }}>None</span>
                                  ) : (
                                    <div style={{ display: 'inline-flex', alignItems: 'center', gap: '6px' }}>
                                      <div
                                        onClick={() => {
                                          setInspectItem(item);
                                          setInspectPhotoIndex(0);
                                        }}
                                        style={{
                                          width: '38px',
                                          height: '28px',
                                          borderRadius: '4px',
                                          overflow: 'hidden',
                                          border: '1px solid #cbd5e1',
                                          cursor: 'pointer',
                                          position: 'relative',
                                          backgroundColor: '#f1f5f9',
                                          flexShrink: 0,
                                          display: 'flex',
                                          alignItems: 'center',
                                          justifyContent: 'center',
                                          boxShadow: '0 1px 2px rgba(0,0,0,0.06)'
                                        }}
                                        title="Click to inspect documents"
                                      >
                                        <img
                                          src={docs[0]}
                                          alt="Document"
                                          style={{
                                            width: '100%',
                                            height: '100%',
                                            objectFit: 'cover'
                                          }}
                                          onError={(e) => {
                                            (e.currentTarget as HTMLElement).style.display = 'none';
                                          }}
                                        />
                                        {docs.length > 1 && (
                                          <span style={{
                                            position: 'absolute',
                                            bottom: '1px',
                                            right: '1px',
                                            backgroundColor: 'rgba(15,23,42,0.85)',
                                            color: '#ffffff',
                                            fontSize: '8px',
                                            fontWeight: 700,
                                            padding: '0 3px',
                                            borderRadius: '2px',
                                            lineHeight: '10px'
                                          }}>
                                            +{docs.length - 1}
                                          </span>
                                        )}
                                      </div>
                                      <button
                                        type="button"
                                        onClick={() => {
                                          setInspectItem(item);
                                          setInspectPhotoIndex(0);
                                        }}
                                        style={{
                                          padding: '4px 8px',
                                          fontSize: '11.5px',
                                          fontWeight: 600,
                                          borderRadius: '6px',
                                          border: '1px solid #cbd5e1',
                                          backgroundColor: '#ffffff',
                                          color: '#334155',
                                          cursor: 'pointer',
                                          whiteSpace: 'nowrap'
                                        }}
                                      >
                                        Inspect ({docs.length})
                                      </button>
                                    </div>
                                  )}
                                </td>

                                <td style={{ fontSize: '12px', color: '#64748b' }}>
                                  {submittedDate ? (
                                    <>
                                      <div style={{ fontWeight: 600, color: '#334155' }}>{new Date(submittedDate).toLocaleDateString()}</div>
                                      <div style={{ fontSize: '11px', color: '#64748b' }}>{new Date(submittedDate).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}</div>
                                    </>
                                  ) : (
                                    <span style={{ color: '#94a3b8', fontStyle: 'italic' }}>Recently submitted</span>
                                  )}
                                </td>

                                <td>
                                  {isApproved ? (
                                    <span className="admin-badge status-resolved" style={{ display: 'inline-flex', alignItems: 'center', gap: '4px' }}>
                                      <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5">
                                        <polyline points="20 6 9 17 4 12" />
                                      </svg>
                                      Verified
                                    </span>
                                  ) : isPending ? (
                                    <span className="admin-badge status-waiting" style={{ display: 'inline-flex', alignItems: 'center', gap: '4px' }}>
                                      <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5">
                                        <circle cx="12" cy="12" r="10" />
                                        <polyline points="12 6 12 12 16 14" />
                                      </svg>
                                      Pending Review
                                    </span>
                                  ) : isRejected ? (
                                    <span className="admin-badge priority-high" style={{ display: 'inline-flex', alignItems: 'center', gap: '4px' }}>
                                      <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5">
                                        <line x1="18" y1="6" x2="6" y2="18" />
                                        <line x1="6" y1="6" x2="18" y2="18" />
                                      </svg>
                                      Rejected
                                    </span>
                                  ) : (
                                    <span className="admin-badge priority-low">
                                      Under Review
                                    </span>
                                  )}
                                </td>

                                <td className="actions-col" style={{ textAlign: 'right', paddingRight: '20px' }}>
                                  <div style={{ display: 'inline-flex', gap: '6px', justifyContent: 'flex-end', alignItems: 'center' }}>
                                    {!isApproved && (
                                      <button
                                        type="button"
                                        className="admin-btn admin-btn-primary"
                                        style={{ padding: '5px 12px', fontSize: '12px', fontWeight: 600, whiteSpace: 'nowrap' }}
                                        disabled={submittingAction}
                                        onClick={() => handleAdjudicate(item, 'Approved', 'Approved by administrator.')}
                                        title="Approve identity and grant verified badge"
                                      >
                                        ✓ Approve
                                      </button>
                                    )}

                                    {!isRejected && (
                                      <button
                                        type="button"
                                        className="admin-btn admin-btn-secondary"
                                        style={{
                                          padding: '5px 12px',
                                          fontSize: '12px',
                                          fontWeight: 600,
                                          whiteSpace: 'nowrap',
                                          color: '#c81e1e',
                                          borderColor: '#fecaca',
                                          backgroundColor: '#ffffff'
                                        }}
                                        disabled={submittingAction}
                                        onClick={() => handleAdjudicate(item, 'Rejected', 'Document unclear or invalid.')}
                                        title="Reject document or revoke verification"
                                      >
                                        {isApproved ? 'Revoke' : '✗ Reject'}
                                      </button>
                                    )}
                                  </div>
                                </td>
                              </tr>
                            );
                          })}
                        </tbody>
                      </table>
                    </div>
                  )}

                  <div className="admin-table-footer">
                    <div>Total {displayedItems.length} submitted providers displayed</div>
                  </div>
                </>
              );
            })()}
          </div>
        </>
      ) : (
        /* AI Low-Confidence Exceptions Tab */
        <>
          <div className="admin-metrics-grid">
            <div className="admin-metric-card">
              <p className="admin-metric-label">Queue Backlog</p>
              <div className="admin-metric-value">{cases.filter(c => c.status === 'Pending Review').length}</div>
              <p className="admin-metric-note">Under 15m review SLA</p>
            </div>
            <div className="admin-metric-card">
              <p className="admin-metric-label">AI Threshold Baseline</p>
              <div className="admin-metric-value">85%</div>
              <p className="admin-metric-note positive">Confidence below 85% routes here</p>
            </div>
            <div className="admin-metric-card">
              <p className="admin-metric-label">Human Approval Rate</p>
              <div className="admin-metric-value">88.4%</div>
              <p className="admin-metric-note positive">Staff validates AI assessment</p>
            </div>
            <div className="admin-metric-card">
              <p className="admin-metric-label">Escrow Release Safety</p>
              <div className="admin-metric-value">100%</div>
              <p className="admin-metric-note positive">Funds locked until sign-off</p>
            </div>
          </div>

          <div className="admin-table-card">
            <h3 className="admin-table-title">Exceptions Requiring Human Adjudication</h3>
            <div className="admin-table-container">
              <table className="admin-table">
                <thead>
                  <tr>
                    <th>Review ID</th>
                    <th>Booking Ref</th>
                    <th>Originating Agent</th>
                    <th>Confidence</th>
                    <th>Flag Reason</th>
                    <th>Customer / Provider</th>
                    <th>Status</th>
                    <th>Time</th>
                    <th className="actions-col" style={{ textAlign: 'right', paddingRight: '20px' }}>Adjudicate</th>
                  </tr>
                </thead>
                <tbody>
                  {cases.map(c => (
                    <tr key={c.id}>
                      <td><span className="admin-inquiry-code">{c.id}</span></td>
                      <td><strong>{c.bookingRef}</strong></td>
                      <td><span className="admin-badge priority-normal">{c.agent}</span></td>
                      <td>
                        <span style={{
                          fontWeight: 700,
                          color: c.confidenceScore < 70 ? '#c81e1e' : '#92400e'
                        }}>
                          {c.confidenceScore}%
                        </span>
                      </td>
                      <td style={{ maxWidth: '320px', whiteSpace: 'normal', fontSize: '13px' }}>
                        {c.flagReason}
                      </td>
                      <td>
                        <div style={{ fontSize: '12.5px' }}><strong>Cust:</strong> {c.customer}</div>
                        <div style={{ fontSize: '12px', color: '#64736a' }}><strong>Prov:</strong> {c.provider}</div>
                      </td>
                      <td>
                        <span className={`admin-badge ${
                          c.status === 'Approved' ? 'status-resolved' :
                          c.status === 'Rejected' ? 'priority-high' : 'status-waiting'
                        }`}>
                          {c.status}
                        </span>
                      </td>
                      <td>{c.timestamp}</td>
                      <td className="actions-col" style={{ textAlign: 'right', paddingRight: '20px' }}>
                        {c.status === 'Pending Review' ? (
                          <div style={{ display: 'inline-flex', gap: '6px' }}>
                            <button
                              type="button"
                              className="admin-btn admin-btn-primary"
                              style={{ padding: '4px 10px', fontSize: '12px' }}
                              onClick={() => handleCaseAction(c.id, 'Approved')}
                            >
                              Approve
                            </button>
                            <button
                              type="button"
                              className="admin-btn admin-btn-secondary"
                              style={{ padding: '4px 10px', fontSize: '12px', color: '#c81e1e', borderColor: '#fecaca' }}
                              onClick={() => handleCaseAction(c.id, 'Rejected')}
                            >
                              Reject
                            </button>
                          </div>
                        ) : (
                          <span style={{ fontSize: '12px', color: '#256b4a', fontWeight: 600 }}>Completed</span>
                        )}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>

            <div className="admin-table-footer">
              <div>Showing {cases.length} exception review records</div>
            </div>
          </div>
        </>
      )}

      {/* Lightbox / Document Inspection Modal */}
      {inspectItem && (
        <div style={{
          position: 'fixed',
          top: 0,
          left: 0,
          right: 0,
          bottom: 0,
          backgroundColor: 'rgba(15, 23, 42, 0.75)',
          backdropFilter: 'blur(4px)',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          zIndex: 1000,
          padding: '24px'
        }}>
          <div style={{
            backgroundColor: '#ffffff',
            borderRadius: '12px',
            maxWidth: '960px',
            width: '100%',
            maxHeight: '90vh',
            display: 'flex',
            flexDirection: 'column',
            overflow: 'hidden',
            boxShadow: '0 25px 50px -12px rgba(0, 0, 0, 0.25)'
          }}>
            {/* Modal Header */}
            <div style={{
              padding: '16px 24px',
              borderBottom: '1px solid #e2e8f0',
              display: 'flex',
              justifyContent: 'space-between',
              alignItems: 'center',
              backgroundColor: '#f8fafc'
            }}>
              <div>
                <h2 style={{ fontSize: '17px', fontWeight: 700, margin: 0, color: '#0f172a' }}>
                  Verification Document Inspection — {inspectItem.fullName || inspectItem.businessName}
                </h2>
                <p style={{ margin: '3px 0 0', fontSize: '12.5px', color: '#64748b' }}>
                  Document Type: <strong>{inspectItem.verificationDocumentType === 'DrivingLicense' ? 'Driving License' : 'National ID (NIC)'}</strong> • Stored securely on Cloudflare R2
                </p>
              </div>
              <button
                type="button"
                onClick={() => setInspectItem(null)}
                style={{
                  background: 'none',
                  border: 'none',
                  cursor: 'pointer',
                  fontSize: '20px',
                  color: '#64748b',
                  lineHeight: 1
                }}
              >
                ✕
              </button>
            </div>

            {/* Modal Body */}
            <div style={{
              display: 'flex',
              flex: 1,
              overflow: 'hidden',
              flexDirection: 'row'
            }}>
                  {/* Document Image Viewer */}
                  <div style={{
                    flex: 1.3,
                    backgroundColor: '#090d16',
                    display: 'flex',
                    flexDirection: 'column',
                    alignItems: 'center',
                    justifyContent: 'center',
                    padding: '20px',
                    overflow: 'auto',
                    position: 'relative'
                  }}>
                    {/* Multi-Photo Switcher Bar */}
                    {modalDocs.length > 1 && (
                      <div style={{
                        position: 'absolute',
                        top: '16px',
                        left: '20px',
                        display: 'flex',
                        gap: '8px',
                        zIndex: 10
                      }}>
                        {modalDocs.map((_url, idx) => (
                          <button
                            key={idx}
                            type="button"
                            onClick={() => setInspectPhotoIndex(idx)}
                            style={{
                              padding: '6px 14px',
                              borderRadius: '6px',
                              fontSize: '12px',
                              fontWeight: 700,
                              cursor: 'pointer',
                              border: inspectPhotoIndex === idx ? '1px solid #4ade80' : '1px solid rgba(255,255,255,0.2)',
                              backgroundColor: inspectPhotoIndex === idx ? '#256b4a' : 'rgba(15,23,42,0.7)',
                              color: '#ffffff',
                              backdropFilter: 'blur(4px)',
                              display: 'flex',
                              alignItems: 'center',
                              gap: '6px'
                            }}
                          >
                            <span>{idx === 0 ? '📷 Front Side' : idx === 1 ? '📷 Back Side' : `📷 Photo ${idx + 1}`}</span>
                            {inspectPhotoIndex === idx && (
                              <span style={{ width: '6px', height: '6px', borderRadius: '50%', backgroundColor: '#4ade80' }} />
                            )}
                          </button>
                        ))}
                      </div>
                    )}

                    {activeDocUrl ? (
                      <img
                        src={activeDocUrl}
                        alt={`Document Photo ${inspectPhotoIndex + 1}`}
                        style={{
                          maxWidth: '100%',
                          maxHeight: modalDocs.length > 1 ? '60vh' : '65vh',
                          objectFit: 'contain',
                          borderRadius: '6px',
                          boxShadow: '0 10px 25px rgba(0,0,0,0.5)'
                        }}
                      />
                    ) : (
                      <div style={{ color: '#94a3b8', fontSize: '14px' }}>No document image available</div>
                    )}

                    {/* Bottom Thumbnail Strip */}
                    {modalDocs.length > 1 && (
                      <div style={{
                        position: 'absolute',
                        bottom: '16px',
                        left: '20px',
                        display: 'flex',
                        gap: '8px',
                        zIndex: 10
                      }}>
                        {modalDocs.map((url, idx) => (
                          <div
                            key={idx}
                            onClick={() => setInspectPhotoIndex(idx)}
                            style={{
                              width: '54px',
                              height: '38px',
                              borderRadius: '4px',
                              overflow: 'hidden',
                              border: inspectPhotoIndex === idx ? '2px solid #4ade80' : '1px solid rgba(255,255,255,0.4)',
                              cursor: 'pointer',
                              boxShadow: '0 2px 6px rgba(0,0,0,0.4)'
                            }}
                            title={`Jump to photo ${idx + 1}`}
                          >
                            <img
                              src={url}
                              alt={`Thumb ${idx + 1}`}
                              style={{ width: '100%', height: '100%', objectFit: 'cover' }}
                            />
                          </div>
                        ))}
                      </div>
                    )}

                    {activeDocUrl && (
                      <a
                        href={activeDocUrl}
                        target="_blank"
                        rel="noopener noreferrer"
                        style={{
                          position: 'absolute',
                          bottom: '16px',
                          right: '16px',
                          backgroundColor: 'rgba(255, 255, 255, 0.9)',
                          color: '#0f172a',
                          padding: '6px 12px',
                          borderRadius: '6px',
                          fontSize: '12px',
                          fontWeight: 600,
                          textDecoration: 'none',
                          display: 'flex',
                          alignItems: 'center',
                          gap: '4px',
                          zIndex: 10
                        }}
                      >
                        ↗ Open Original ({inspectPhotoIndex === 0 ? 'Front' : inspectPhotoIndex === 1 ? 'Back' : `Photo ${inspectPhotoIndex + 1}`})
                      </a>
                    )}
                  </div>

              {/* Provider Info & Action Sidebar */}
              <div style={{
                flex: 0.9,
                padding: '24px',
                backgroundColor: '#ffffff',
                borderLeft: '1px solid #e2e8f0',
                display: 'flex',
                flexDirection: 'column',
                justifyContent: 'space-between',
                overflowY: 'auto'
              }}>
                <div>
                  <h4 style={{ margin: '0 0 16px', fontSize: '15px', color: '#0f172a' }}>Provider Profile</h4>

                  <div style={{ display: 'flex', flexDirection: 'column', gap: '10px', fontSize: '13px' }}>
                    <div>
                      <span style={{ color: '#64748b' }}>Full Name:</span>
                      <strong style={{ display: 'block', color: '#0f172a' }}>{inspectItem.fullName || '—'}</strong>
                    </div>
                    <div>
                      <span style={{ color: '#64748b' }}>Business / Brand:</span>
                      <strong style={{ display: 'block', color: '#0f172a' }}>{inspectItem.businessName || 'Independent'}</strong>
                    </div>
                    <div>
                      <span style={{ color: '#64748b' }}>Category:</span>
                      <strong style={{ display: 'block', color: '#0f172a' }}>{inspectItem.category}</strong>
                    </div>
                    <div>
                      <span style={{ color: '#64748b' }}>Phone Number:</span>
                      <strong style={{ display: 'block', color: '#0f172a' }}>{inspectItem.phoneNumber || inspectItem.phone || 'N/A'}</strong>
                    </div>
                    <div>
                      <span style={{ color: '#64748b' }}>Location:</span>
                      <strong style={{ display: 'block', color: '#0f172a' }}>{inspectItem.city || inspectItem.location || 'Colombo'}</strong>
                    </div>
                    <div>
                      <span style={{ color: '#64748b' }}>Current Verification Status:</span>
                      <strong style={{ display: 'block', color: (inspectItem.isVerified || inspectItem.status?.toLowerCase() === 'approved' || inspectItem.verificationStatus?.toLowerCase() === 'approved') ? '#256b4a' : '#c81e1e' }}>
                        {(inspectItem.isVerified || inspectItem.status?.toLowerCase() === 'approved' || inspectItem.verificationStatus?.toLowerCase() === 'approved') ? 'Approved (Badge Active)' : (inspectItem.status?.toLowerCase() === 'rejected' || inspectItem.verificationStatus?.toLowerCase() === 'rejected') ? 'Rejected' : 'Pending Review'}
                      </strong>
                    </div>
                    <div>
                      <span style={{ color: '#64748b' }}>Submitted Documents:</span>
                      {(() => {
                        const docs = getDocUrls(inspectItem);
                        return (
                          <strong style={{ display: 'block', color: docs.length >= 2 ? '#256b4a' : '#0f172a' }}>
                            {docs.length} {docs.length === 1 ? 'photo' : 'photos'} ({docs.length >= 2 ? 'Both Sides Attached' : docs.length === 1 ? '1 side only' : 'None'})
                          </strong>
                        );
                      })()}
                    </div>
                    {inspectItem.verificationNotes && (
                      <div style={{ backgroundColor: '#f8fafc', padding: '8px 12px', borderRadius: '6px' }}>
                        <span style={{ color: '#64748b', fontSize: '12px' }}>Previous Notes:</span>
                        <div style={{ color: '#334155', fontSize: '12.5px', marginTop: '2px' }}>{inspectItem.verificationNotes}</div>
                      </div>
                    )}
                  </div>

                  <div style={{ marginTop: '20px' }}>
                    <label style={{ display: 'block', fontSize: '12.5px', fontWeight: 600, color: '#334155', marginBottom: '6px' }}>
                      Adjudication Notes (Optional)
                    </label>
                    <textarea
                      rows={3}
                      value={adjudicationNote}
                      onChange={e => setAdjudicationNote(e.target.value)}
                      placeholder="Add reason for approval or rejection (visible in audit log)..."
                      style={{
                        width: '100%',
                        padding: '8px 12px',
                        borderRadius: '6px',
                        border: '1px solid #cbd5e1',
                        backgroundColor: '#ffffff',
                        color: '#0f172a',
                        fontSize: '13px',
                        boxSizing: 'border-box'
                      }}
                    />
                  </div>
                </div>

                <div style={{ display: 'flex', gap: '10px', marginTop: '24px', paddingTop: '16px', borderTop: '1px solid #e2e8f0' }}>
                  <button
                    type="button"
                    disabled={submittingAction}
                    onClick={() => handleAdjudicate(inspectItem, 'Approved')}
                    style={{
                      flex: 1,
                      padding: '10px 16px',
                      backgroundColor: '#256b4a',
                      color: '#ffffff',
                      border: 'none',
                      borderRadius: '6px',
                      fontWeight: 700,
                      fontSize: '13px',
                      cursor: 'pointer'
                    }}
                  >
                    ✓ Approve Provider
                  </button>
                  <button
                    type="button"
                    disabled={submittingAction}
                    onClick={() => handleAdjudicate(inspectItem, 'Rejected')}
                    style={{
                      flex: 1,
                      padding: '10px 16px',
                      backgroundColor: '#ffffff',
                      color: '#c81e1e',
                      border: '1px solid #fecaca',
                      borderRadius: '6px',
                      fontWeight: 700,
                      fontSize: '13px',
                      cursor: 'pointer'
                    }}
                  >
                    ✗ Reject / Revoke
                  </button>
                </div>
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};
