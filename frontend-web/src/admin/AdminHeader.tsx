import React from 'react';
import type { AdminUser } from './types';

interface HeaderProps {
  currentTab: string;
  currentUser: AdminUser;
  onToggleMobileMenu?: () => void;
}

export const AdminHeader: React.FC<HeaderProps> = ({
  currentTab,
  currentUser,
  onToggleMobileMenu,
}) => {
  const getTabLabel = (tab: string) => {
    switch (tab) {
      case 'dashboard': return 'Dashboard';
      case 'service-requests': return 'Service Requests';
      case 'bookings': return 'Bookings & Jobs';
      case 'inquiries': return 'Inquiries';
      case 'complaints': return 'Complaints';
      case 'providers': return 'Providers';
      case 'customers': return 'Customers';
      case 'reviews': return 'Reviews';
      case 'ai-workflows': return 'AI Workflows';
      case 'ai-monitoring': return 'AI Monitoring';
      case 'human-reviews': return 'Human Reviews';
      case 'chats': return 'Dispute & Communication Chats';
      case 'reports': return 'Reports';
      case 'admin-management': return 'Admin Management';
      case 'audit-logs': return 'Audit Logs';
      case 'settings': return 'Settings';
      default: return 'Dashboard';
    }
  };

  const getInitials = (name: string) => {
    if (!name) return 'KA';
    const parts = name.trim().split(' ');
    if (parts.length >= 2) return `${parts[0][0]}${parts[1][0]}`.toUpperCase();
    return name.slice(0, 2).toUpperCase();
  };

  return (
    <header className="admin-topbar">
      <div className="admin-topbar-left">
        <button
          type="button"
          className="admin-hamburger-btn"
          onClick={onToggleMobileMenu}
          aria-label="Toggle Navigation Menu"
          title="Open Menu"
        >
          <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round">
            <line x1="3" y1="6" x2="21" y2="6" />
            <line x1="3" y1="12" x2="21" y2="12" />
            <line x1="3" y1="18" x2="21" y2="18" />
          </svg>
        </button>

        <div className="admin-breadcrumb">
          <span className="admin-breadcrumb-parent">Workspace</span>
          <span className="admin-breadcrumb-sep">/</span>
          <span className="admin-breadcrumb-parent">Overview</span>
          <span className="admin-breadcrumb-sep">/</span>
          <span className="current">{getTabLabel(currentTab)}</span>
        </div>
      </div>

      <div className="admin-topbar-actions">
        {/* Search */}
        <button type="button" className="admin-icon-btn" title="Search operations...">
          <svg width="19" height="19" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
            <circle cx="11" cy="11" r="8" />
            <line x1="21" y1="21" x2="16.65" y2="16.65" />
          </svg>
        </button>

        {/* Notifications */}
        <button type="button" className="admin-icon-btn" title="System alerts and inquiry updates">
          <svg width="19" height="19" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
            <path d="M18 8A6 6 0 0 0 6 8c0 7-3 9-3 9h18s-3-2-3-9" />
            <path d="M13.73 21a2 2 0 0 1-3.46 0" />
          </svg>
          <span className="admin-badge-dot" />
        </button>

        {/* Avatar */}
        <div className="admin-avatar" title={`${currentUser.fullName} (${currentUser.role})`}>
          {getInitials(currentUser.fullName)}
        </div>
      </div>
    </header>
  );
};
