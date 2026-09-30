import React, { useState } from 'react';
import type { DashboardStats } from './types';

interface DashboardViewProps {
  stats: DashboardStats;
  onRefresh?: () => void;
  onOpenInquiry?: (inquiryNumber: string) => void;
}

export const DashboardView: React.FC<DashboardViewProps> = ({ stats }) => {
  const [currentPage, setCurrentPage] = useState(1);

  // Helper for Priority badge class
  const getPriorityClass = (priority: string) => {
    switch (priority.toLowerCase()) {
      case 'high': return 'priority-high';
      case 'normal': return 'priority-normal';
      case 'low': return 'priority-low';
      default: return 'priority-normal';
    }
  };

  // Helper for Status badge class
  const getStatusClass = (status: string) => {
    const s = status.toLowerCase();
    if (s.includes('open')) return 'status-open';
    if (s.includes('progress')) return 'status-in-progress';
    if (s.includes('wait')) return 'status-waiting';
    if (s.includes('resolved')) return 'status-resolved';
    return 'status-open';
  };

  // Chart height calculations
  const maxReq = Math.max(...stats.serviceRequestsChart.map(d => d.requests), 100);
  const maxProv = Math.max(...stats.providerActivityChart.map(d => d.providerActive), 100);

  return (
    <div className="admin-content">
      {/* Title & Action */}
      <div className="admin-page-header">
        <div>
          <h1 className="admin-page-title">Dashboard</h1>
          <p className="admin-page-subtitle">
            A clear view of marketplace activity and the cases that need attention.
          </p>
        </div>
        <button
          type="button"
          className="admin-export-btn"
          onClick={() => alert('Exporting Operations Console summary report (CSV/PDF)...')}
        >
          <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round">
            <path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4" />
            <polyline points="7 10 12 15 17 10" />
            <line x1="12" y1="15" x2="12" y2="3" />
          </svg>
          Export
        </button>
      </div>

      {/* Row 1 Metrics (4 cards) */}
      <div className="admin-metrics-grid">
        <div className="admin-metric-card">
          <p className="admin-metric-label">Total requests</p>
          <div className="admin-metric-value">{stats.totalRequests.toLocaleString()}</div>
          <p className="admin-metric-note positive">{stats.requestsChange}</p>
        </div>

        <div className="admin-metric-card">
          <p className="admin-metric-label">Active jobs</p>
          <div className="admin-metric-value">{stats.activeJobs}</div>
          <p className="admin-metric-note">{stats.jobsStartingToday} starting today</p>
        </div>

        <div className="admin-metric-card">
          <p className="admin-metric-label">Completed jobs</p>
          <div className="admin-metric-value">{stats.completedJobs.toLocaleString()}</div>
          <p className="admin-metric-note">{stats.completionRate}</p>
        </div>

        <div className="admin-metric-card">
          <p className="admin-metric-label">Open inquiries</p>
          <div className="admin-metric-value">{stats.openInquiries}</div>
          <p className="admin-metric-note">{stats.inquiriesNeedingResponse} need a response</p>
        </div>
      </div>

      {/* Row 2 Metrics (4 cards) */}
      <div className="admin-metrics-grid">
        <div className="admin-metric-card">
          <p className="admin-metric-label">AI workflows</p>
          <div className="admin-metric-value">{stats.aiWorkflows}</div>
          <p className="admin-metric-note">{stats.aiSuccessRate}</p>
        </div>

        <div className="admin-metric-card">
          <p className="admin-metric-label">Human reviews</p>
          <div className="admin-metric-value">{stats.humanReviews}</div>
          <p className="admin-metric-note">Exceptions only</p>
        </div>

        <div className="admin-metric-card">
          <p className="admin-metric-label">Failed workflows</p>
          <div className="admin-metric-value">{stats.failedWorkflows}</div>
          <p className="admin-metric-note">Investigate failures</p>
        </div>

        <div className="admin-metric-card">
          <p className="admin-metric-label">Completion issues</p>
          <div className="admin-metric-value">{stats.completionIssues}</div>
          <p className="admin-metric-note">Evidence needs attention</p>
        </div>
      </div>

      {/* 2 Chart Cards */}
      <div className="admin-charts-grid">
        {/* Service requests & bookings */}
        <div className="admin-chart-card">
          <h3 className="admin-chart-title">Service requests & bookings</h3>
          <p className="admin-chart-range">Last 7 days</p>

          <div className="admin-bar-chart">
            {stats.serviceRequestsChart.map((col, idx) => {
              const heightPct = Math.round((col.requests / maxReq) * 85) + 15;
              const isHighlight = idx === stats.serviceRequestsChart.length - 1; // Sun
              return (
                <div key={col.day} className="admin-chart-column">
                  <div className="admin-bar-wrapper">
                    <div
                      className={`admin-bar ${isHighlight ? 'highlight' : ''}`}
                      style={{ height: `${heightPct}%` }}
                      title={`${col.day}: ${col.requests} requests, ${col.bookings} bookings`}
                    />
                  </div>
                  <span className="admin-chart-day">{col.day}</span>
                </div>
              );
            })}
          </div>
        </div>

        {/* Provider activity */}
        <div className="admin-chart-card">
          <h3 className="admin-chart-title">Provider activity</h3>
          <p className="admin-chart-range">Last 7 days</p>

          <div className="admin-bar-chart">
            {stats.providerActivityChart.map((col, idx) => {
              const heightPct = Math.round((col.providerActive / maxProv) * 85) + 15;
              const isHighlight = idx === stats.providerActivityChart.length - 1; // Sun
              return (
                <div key={col.day} className="admin-chart-column">
                  <div className="admin-bar-wrapper">
                    <div
                      className={`admin-bar ${isHighlight ? 'highlight' : ''}`}
                      style={{ height: `${heightPct}%` }}
                      title={`${col.day}: ${col.providerActive} active providers`}
                    />
                  </div>
                  <span className="admin-chart-day">{col.day}</span>
                </div>
              );
            })}
          </div>
        </div>
      </div>

      {/* Recent Inquiries Table */}
      <div className="admin-table-card">
        <h3 className="admin-table-title">Recent inquiries</h3>
        <div className="admin-table-container">
          <table className="admin-table">
            <thead>
              <tr>
                <th>Inquiry</th>
                <th>Customer</th>
                <th>Issue</th>
                <th>Provider</th>
                <th>Priority</th>
                <th>Status</th>
              </tr>
            </thead>
            <tbody>
              {stats.recentInquiries.map((inq) => (
                <tr key={inq.inquiryNumber}>
                  <td>
                    <span className="admin-inquiry-code">{inq.inquiryNumber}</span>
                  </td>
                  <td>{inq.customer}</td>
                  <td>{inq.issue}</td>
                  <td>{inq.provider}</td>
                  <td>
                    <span className={`admin-badge ${getPriorityClass(inq.priority)}`}>
                      {inq.priority}
                    </span>
                  </td>
                  <td>
                    <span className={`admin-badge ${getStatusClass(inq.status)}`}>
                      {inq.status}
                    </span>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>

        <div className="admin-table-footer">
          <div>Showing {stats.recentInquiries.length} of 128 results</div>
          <div className="admin-pagination">
            <span
              className="admin-page-link"
              onClick={() => setCurrentPage(p => Math.max(1, p - 1))}
            >
              Previous
            </span>
            <span
              className={`admin-page-link ${currentPage === 1 ? 'active' : ''}`}
              onClick={() => setCurrentPage(1)}
            >
              1
            </span>
            <span
              className={`admin-page-link ${currentPage === 2 ? 'active' : ''}`}
              onClick={() => setCurrentPage(2)}
            >
              2
            </span>
            <span
              className={`admin-page-link ${currentPage === 3 ? 'active' : ''}`}
              onClick={() => setCurrentPage(3)}
            >
              3
            </span>
            <span
              className="admin-page-link"
              onClick={() => setCurrentPage(p => Math.min(3, p + 1))}
            >
              Next
            </span>
          </div>
        </div>
      </div>
    </div>
  );
};
