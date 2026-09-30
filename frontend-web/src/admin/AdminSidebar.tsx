import React from 'react';
import type { AdminUser } from './types';

interface SidebarProps {
  currentTab: string;
  onSelectTab: (tab: string) => void;
  currentUser: AdminUser;
  onLogout: () => void;
}

export const AdminSidebar: React.FC<SidebarProps> = ({
  currentTab,
  onSelectTab,
  currentUser,
  onLogout,
}) => {
  return (
    <aside className="admin-sidebar">
      {/* Brand */}
      <div className="admin-brand">
        <h1 className="admin-brand-title">TASKBRIDGE</h1>
        <div className="admin-brand-subtitle">OPERATIONS CONSOLE</div>
      </div>

      {/* OPERATIONS */}
      <div className="admin-nav-group">
        <h2 className="admin-nav-heading">OPERATIONS</h2>
        <button
          type="button"
          className={`admin-nav-item ${currentTab === 'dashboard' ? 'active' : ''}`}
          onClick={() => onSelectTab('dashboard')}
        >
          <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
            <rect x="3" y="3" width="7" height="9" rx="1" />
            <rect x="14" y="3" width="7" height="5" rx="1" />
            <rect x="14" y="12" width="7" height="9" rx="1" />
            <rect x="3" y="16" width="7" height="5" rx="1" />
          </svg>
          Dashboard
        </button>

        <button
          type="button"
          className={`admin-nav-item ${currentTab === 'service-requests' ? 'active' : ''}`}
          onClick={() => onSelectTab('service-requests')}
        >
          <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
            <path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z" />
            <polyline points="14 2 14 8 20 8" />
            <line x1="16" y1="13" x2="8" y2="13" />
            <line x1="16" y1="17" x2="8" y2="17" />
            <polyline points="10 9 9 9 8 9" />
          </svg>
          Service Requests
        </button>

        <button
          type="button"
          className={`admin-nav-item ${currentTab === 'bookings' ? 'active' : ''}`}
          onClick={() => onSelectTab('bookings')}
        >
          <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
            <rect x="2" y="7" width="20" height="14" rx="2" ry="2" />
            <path d="M16 21V5a2 2 0 0 0-2-2h-4a2 2 0 0 0-2 2v16" />
          </svg>
          Bookings & Jobs
        </button>

        <button
          type="button"
          className={`admin-nav-item ${currentTab === 'inquiries' ? 'active' : ''}`}
          onClick={() => onSelectTab('inquiries')}
        >
          <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
            <path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z" />
          </svg>
          Inquiries
        </button>

        <button
          type="button"
          className={`admin-nav-item ${currentTab === 'complaints' ? 'active' : ''}`}
          onClick={() => onSelectTab('complaints')}
        >
          <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
            <circle cx="12" cy="12" r="10" />
            <line x1="12" y1="8" x2="12" y2="12" />
            <line x1="12" y1="16" x2="12.01" y2="16" />
          </svg>
          Complaints
        </button>
      </div>

      {/* MARKETPLACE */}
      <div className="admin-nav-group">
        <h2 className="admin-nav-heading">MARKETPLACE</h2>
        <button
          type="button"
          className={`admin-nav-item ${currentTab === 'providers' ? 'active' : ''}`}
          onClick={() => onSelectTab('providers')}
        >
          <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
            <path d="M16 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2" />
            <circle cx="8.5" cy="7" r="4" />
            <line x1="20" y1="8" x2="20" y2="14" />
            <line x1="23" y1="11" x2="17" y2="11" />
          </svg>
          Providers
        </button>

        <button
          type="button"
          className={`admin-nav-item ${currentTab === 'customers' ? 'active' : ''}`}
          onClick={() => onSelectTab('customers')}
        >
          <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
            <path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2" />
            <circle cx="12" cy="7" r="4" />
          </svg>
          Customers
        </button>

        <button
          type="button"
          className={`admin-nav-item ${currentTab === 'reviews' ? 'active' : ''}`}
          onClick={() => onSelectTab('reviews')}
        >
          <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
            <polygon points="12 2 15.09 8.26 22 9.27 17 14.14 18.18 21.02 12 17.77 5.82 21.02 7 14.14 2 9.27 8.91 8.26 12 2" />
          </svg>
          Reviews
        </button>
      </div>

      {/* AI */}
      <div className="admin-nav-group">
        <h2 className="admin-nav-heading">AI</h2>
        <button
          type="button"
          className={`admin-nav-item ${currentTab === 'ai-workflows' ? 'active' : ''}`}
          onClick={() => onSelectTab('ai-workflows')}
        >
          <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
            <polygon points="13 2 3 14 12 14 11 22 21 10 12 10 13 2" />
          </svg>
          AI Workflows
        </button>

        <button
          type="button"
          className={`admin-nav-item ${currentTab === 'ai-monitoring' ? 'active' : ''}`}
          onClick={() => onSelectTab('ai-monitoring')}
        >
          <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
            <rect x="2" y="3" width="20" height="14" rx="2" ry="2" />
            <line x1="8" y1="21" x2="16" y2="21" />
            <line x1="12" y1="17" x2="12" y2="21" />
          </svg>
          AI Monitoring
        </button>

        <button
          type="button"
          className={`admin-nav-item ${currentTab === 'human-reviews' ? 'active' : ''}`}
          onClick={() => onSelectTab('human-reviews')}
        >
          <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
            <path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z" />
          </svg>
          Human Reviews
        </button>
      </div>

      {/* COMMUNICATION */}
      <div className="admin-nav-group">
        <h2 className="admin-nav-heading">COMMUNICATION</h2>
        <button
          type="button"
          className={`admin-nav-item ${currentTab === 'chats' ? 'active' : ''}`}
          onClick={() => onSelectTab('chats')}
        >
          <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
            <path d="M21 11.5a8.38 8.38 0 0 1-.9 3.8 8.5 8.5 0 0 1-7.6 4.7 8.38 8.38 0 0 1-3.8-.9L3 21l1.9-5.7a8.38 8.38 0 0 1-.9-3.8 8.5 8.5 0 0 1 4.7-7.6 8.38 8.38 0 0 1 3.8-.9h.5a8.48 8.48 0 0 1 8 8v.5z" />
          </svg>
          Chats
        </button>
      </div>

      {/* ANALYTICS */}
      <div className="admin-nav-group">
        <h2 className="admin-nav-heading">ANALYTICS</h2>
        <button
          type="button"
          className={`admin-nav-item ${currentTab === 'reports' ? 'active' : ''}`}
          onClick={() => onSelectTab('reports')}
        >
          <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
            <line x1="18" y1="20" x2="18" y2="10" />
            <line x1="12" y1="20" x2="12" y2="4" />
            <line x1="6" y1="20" x2="6" y2="14" />
          </svg>
          Reports
        </button>
      </div>

      {/* SYSTEM */}
      <div className="admin-nav-group">
        <h2 className="admin-nav-heading">SYSTEM</h2>
        <button
          type="button"
          className={`admin-nav-item ${currentTab === 'admin-management' ? 'active' : ''}`}
          onClick={() => onSelectTab('admin-management')}
        >
          <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
            <path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2" />
            <circle cx="9" cy="7" r="4" />
            <path d="M23 21v-2a4 4 0 0 0-3-3.87" />
            <path d="M16 3.13a4 4 0 0 1 0 7.75" />
          </svg>
          Admin Management
        </button>

        <button
          type="button"
          className={`admin-nav-item ${currentTab === 'audit-logs' ? 'active' : ''}`}
          onClick={() => onSelectTab('audit-logs')}
        >
          <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
            <polyline points="22 12 18 12 15 21 9 3 6 12 2 12" />
          </svg>
          Audit Logs
        </button>

        <button
          type="button"
          className={`admin-nav-item ${currentTab === 'settings' ? 'active' : ''}`}
          onClick={() => onSelectTab('settings')}
        >
          <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
            <circle cx="12" cy="12" r="3" />
            <path d="M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 0 1 0 2.83 2 2 0 0 1-2.83 0l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 0 1-2 2 2 2 0 0 1-2-2v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 0 1-2.83 0 2 2 0 0 1 0-2.83l.06-.06a1.65 1.65 0 0 0 .33-1.82 1.65 1.65 0 0 0-1.51-1H3a2 2 0 0 1-2-2 2 2 0 0 1 2-2h.09A1.65 1.65 0 0 0 4.6 9a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 0 1 0-2.83 2 2 0 0 1 2.83 0l.06.06a1.65 1.65 0 0 0 1.82.33H9a1.65 1.65 0 0 0 1-1.51V3a2 2 0 0 1 2-2 2 2 0 0 1 2 2v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 0 1 2.83 0 2 2 0 0 1 0 2.83l-.06.06a1.65 1.65 0 0 0-.33 1.82V9a1.65 1.65 0 0 0 1.51 1H21a2 2 0 0 1 2 2 2 2 0 0 1-2 2h-.09a1.65 1.65 0 0 0-1.51 1z" />
          </svg>
          Settings
        </button>
      </div>

      {/* User Footer */}
      <div className="admin-sidebar-footer">
        <div className="admin-user-pill">
          <div className="admin-user-info">
            <span className="admin-user-name">
              {currentUser.fullName || 'Kavindu'}
            </span>
            <span className="admin-user-role">
              {currentUser.role === 'SuperAdmin' ? 'Super Administrator' : 'Administrator'}
            </span>
          </div>
          <button
            type="button"
            className="admin-logout-btn"
            title="Sign out of Operations Console"
            onClick={onLogout}
          >
            <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
              <path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4" />
              <polyline points="16 17 21 12 16 7" />
              <line x1="21" y1="12" x2="9" y2="12" />
            </svg>
          </button>
        </div>
      </div>
    </aside>
  );
};
