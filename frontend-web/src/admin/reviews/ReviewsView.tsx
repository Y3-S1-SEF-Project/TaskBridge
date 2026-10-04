import React, { useState, useEffect, useCallback } from 'react';
import type { ReviewsSummary } from '../types';
import { fetchReviews } from '../api';

export const ReviewsView: React.FC = () => {
  const [loading, setLoading] = useState(true);
  const [errorMsg, setErrorMsg] = useState('');
  const [summary, setSummary] = useState<ReviewsSummary>({
    totalReviews: 0,
    overallRating: 0,
    flaggedCount: 0,
    positiveSentimentRate: '0%',
    items: [],
  });

  const [search, setSearch] = useState('');
  const [sentimentFilter, setSentimentFilter] = useState('All');

  const loadReviews = useCallback(async () => {
    setLoading(true);
    setErrorMsg('');
    try {
      const data = await fetchReviews({
        search: search.trim() || undefined,
      });
      setSummary(data);
    } catch (err: any) {
      setErrorMsg(err.message || 'Failed to load reviews from database.');
    } finally {
      setLoading(false);
    }
  }, [search]);

  useEffect(() => {
    const timer = setTimeout(() => {
      loadReviews();
    }, 200);
    return () => clearTimeout(timer);
  }, [loadReviews]);

  const handleExport = () => {
    if (summary.items.length === 0) return;
    const headers = ['ReviewID', 'Customer', 'Provider', 'Service', 'Rating', 'Comment', 'Sentiment', 'Date'];
    const rows = summary.items.map(r => [
      r.id,
      `"${r.customerName.replace(/"/g, '""')}"`,
      `"${r.providerName.replace(/"/g, '""')}"`,
      `"${r.service}"`,
      r.rating,
      `"${r.comment.replace(/"/g, '""')}"`,
      r.sentiment,
      `"${new Date(r.createdAt).toLocaleDateString()}"`,
    ]);
    const csvContent = [headers.join(','), ...rows.map(row => row.join(','))].join('\n');
    const blob = new Blob([csvContent], { type: 'text/csv;charset=utf-8;' });
    const url = URL.createObjectURL(blob);
    const link = document.createElement('a');
    link.href = url;
    link.setAttribute('download', `TaskBridge_Reviews_${new Date().toISOString().split('T')[0]}.csv`);
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
  };

  const filtered = summary.items.filter(r => {
    const matchSearch =
      !search.trim() ||
      r.customerName.toLowerCase().includes(search.trim().toLowerCase()) ||
      r.providerName.toLowerCase().includes(search.trim().toLowerCase()) ||
      r.comment.toLowerCase().includes(search.trim().toLowerCase()) ||
      r.service.toLowerCase().includes(search.trim().toLowerCase()) ||
      r.id.toLowerCase().includes(search.trim().toLowerCase());

    const matchSentiment =
      sentimentFilter === 'All' ||
      r.sentiment.toLowerCase() === sentimentFilter.toLowerCase();

    return matchSearch && matchSentiment;
  });

  const fiveStarCount = summary.items.filter(r => r.rating === 5).length;

  return (
    <div className="admin-content">
      <div className="admin-page-header">
        <div>
          <h1 className="admin-page-title">Feedback &amp; Reviews</h1>
          <p className="admin-page-subtitle">
            Customer reviews, ratings telemetry, and natural language sentiment insights.
          </p>
        </div>
        <div style={{ display: 'flex', gap: '10px' }}>
          <button
            type="button"
            className="admin-btn admin-btn-secondary"
            onClick={loadReviews}
            title="Refresh reviews from database"
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
            Export Reviews
          </button>
        </div>
      </div>

      {/* Dynamic Metrics Cards */}
      <div className="admin-metrics-grid">
        <div className="admin-metric-card">
          <p className="admin-metric-label">Total Verified Reviews</p>
          <div className="admin-metric-value">{summary.totalReviews}</div>
          <p className="admin-metric-note positive">100% booking verified</p>
        </div>
        <div className="admin-metric-card">
          <p className="admin-metric-label">Overall Platform Rating</p>
          <div className="admin-metric-value">{summary.overallRating.toFixed(2)} ★</div>
          <p className="admin-metric-note positive">Based on customer feedback</p>
        </div>
        <div className="admin-metric-card">
          <p className="admin-metric-label">5-Star Ratings</p>
          <div className="admin-metric-value" style={{ color: '#256b4a' }}>
            {fiveStarCount}
          </div>
          <p className="admin-metric-note positive">Top satisfaction ratings</p>
        </div>
        <div className="admin-metric-card">
          <p className="admin-metric-label">Positive Sentiment Rate</p>
          <div className="admin-metric-value">{summary.positiveSentimentRate}</div>
          <p className="admin-metric-note positive">Natural language analyzed</p>
        </div>
      </div>

      <div className="admin-table-card">
        <div className="admin-toolbar" style={{ padding: '20px 24px 16px', display: 'flex', gap: '12px', flexWrap: 'wrap', alignItems: 'center' }}>
          <div className="admin-search-box" style={{ flex: '1 1 320px' }}>
            <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
              <circle cx="11" cy="11" r="8" />
              <line x1="21" y1="21" x2="16.65" y2="16.65" />
            </svg>
            <input
              type="text"
              placeholder="Search reviewer, provider, service, feedback keywords..."
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

          <div style={{ display: 'flex', gap: '10px' }}>
            <select
              className="admin-filter-select"
              value={sentimentFilter}
              onChange={(e) => setSentimentFilter(e.target.value)}
            >
              <option value="All">All Sentiments</option>
              <option value="Positive">Positive</option>
              <option value="Neutral">Neutral</option>
              <option value="Negative">Negative</option>
            </select>

            {(search || sentimentFilter !== 'All') && (
              <button
                type="button"
                className="admin-btn admin-btn-secondary"
                style={{ fontSize: '12.5px', padding: '6px 12px' }}
                onClick={() => {
                  setSearch('');
                  setSentimentFilter('All');
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
                <th>Review ID</th>
                <th>Reviewer</th>
                <th>Provider</th>
                <th>Trade</th>
                <th>Rating</th>
                <th>Customer Feedback</th>
                <th>Sentiment</th>
              </tr>
            </thead>
            <tbody>
              {loading ? (
                <tr>
                  <td colSpan={7} style={{ textAlign: 'center', padding: '40px 20px', color: '#64736a' }}>
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
                      Loading customer feedback &amp; reviews from database...
                    </div>
                  </td>
                </tr>
              ) : filtered.length === 0 ? (
                <tr>
                  <td colSpan={7} style={{ textAlign: 'center', padding: '48px 20px', color: '#8a9990' }}>
                    <div style={{ fontSize: '15px', fontWeight: 600, color: '#141f19', marginBottom: '6px' }}>
                      No reviews found
                    </div>
                    <div style={{ fontSize: '13px', maxWidth: '400px', margin: '0 auto 16px' }}>
                      No customer reviews match the current query or sentiment filter.
                    </div>
                  </td>
                </tr>
              ) : (
                filtered.map(r => (
                  <tr key={r.reviewGuid}>
                    <td><span className="admin-inquiry-code">{r.id}</span></td>
                    <td><strong>{r.customerName}</strong></td>
                    <td>{r.providerName}</td>
                    <td>{r.service}</td>
                    <td>
                      <span style={{ fontWeight: 700, color: r.rating >= 4 ? '#256b4a' : '#c81e1e' }}>
                        {'★'.repeat(Math.max(1, Math.min(5, r.rating)))}
                      </span>
                    </td>
                    <td style={{ maxWidth: '360px', whiteSpace: 'normal' }}>
                      <p style={{ margin: 0, fontSize: '13px', color: '#141f19' }}>"{r.comment}"</p>
                      <span style={{ fontSize: '11px', color: '#8a9990' }}>
                        {new Date(r.createdAt).toLocaleDateString(undefined, {
                          month: 'short',
                          day: 'numeric',
                          year: 'numeric',
                        })}
                      </span>
                    </td>
                    <td>
                      <span className={`admin-badge ${
                        r.sentiment === 'Positive' ? 'status-resolved' :
                        r.sentiment === 'Neutral' ? 'priority-normal' : 'priority-high'
                      }`}>
                        {r.sentiment}
                      </span>
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>

        <div className="admin-table-footer">
          <div>Showing <strong>{filtered.length}</strong> of <strong>{summary.totalReviews}</strong> customer reviews</div>
          {(search || sentimentFilter !== 'All') && (
            <div style={{ color: '#256b4a', fontSize: '12.5px', fontWeight: 500 }}>
              Filtered view active
            </div>
          )}
        </div>
      </div>
    </div>
  );
};
