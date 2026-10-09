import React, { useState, useEffect } from 'react';
import type { AdminUser, DashboardStats } from './types';
import { getStoredAdminUser, clearAdminSession, fetchDashboardStats } from './api';
import { AdminLogin } from './AdminLogin';
import { AdminSidebar } from './AdminSidebar';
import { AdminHeader } from './AdminHeader';

// Dedicated views from each navbar item's own separate folder
import { DashboardView } from './dashboard';
import { ServiceRequestsView } from './service-requests';
import { BookingsView } from './bookings';
import { InquiriesView } from './inquiries';
import { ComplaintsView } from './complaints';
import { ProvidersView } from './providers';
import { CustomersView } from './customers';
import { ReviewsView } from './reviews';
import { AiWorkflowsView } from './ai-workflows';
import { AiMonitoringView } from './ai-monitoring';
import { HumanReviewsView } from './human-reviews';
import { ChatsView } from './chats';
import { ReportsView } from './reports';
import { AdminManagementView } from './admin-management';
import { AuditLogsView } from './audit-logs';
import { SettingsView } from './settings';

import './admin.css';

const VALID_ADMIN_TABS = [
  'dashboard',
  'service-requests',
  'bookings',
  'inquiries',
  'complaints',
  'providers',
  'customers',
  'reviews',
  'ai-workflows',
  'ai-monitoring',
  'human-reviews',
  'chats',
  'reports',
  'admin-management',
  'audit-logs',
  'settings',
];

const getInitialTab = (): string => {
  const hash = window.location.hash.replace(/^#\/?/, '').trim();
  if (hash && VALID_ADMIN_TABS.includes(hash)) {
    return hash;
  }
  const saved = localStorage.getItem('taskbridge_admin_tab');
  if (saved && VALID_ADMIN_TABS.includes(saved)) {
    return saved;
  }
  return 'dashboard';
};

export const AdminApp: React.FC = () => {
  const [currentUser, setCurrentUser] = useState<AdminUser | null>(() => getStoredAdminUser());
  const [currentTab, setCurrentTab] = useState<string>(getInitialTab);
  const [stats, setStats] = useState<DashboardStats | null>(null);
  const [mobileMenuOpen, setMobileMenuOpen] = useState(false);

  // Sync tab with URL hash and localStorage so refreshing returns to current view
  useEffect(() => {
    if (currentTab) {
      localStorage.setItem('taskbridge_admin_tab', currentTab);
      if (window.location.hash.replace(/^#\/?/, '') !== currentTab) {
        window.location.hash = currentTab;
      }
    }
  }, [currentTab]);

  // Handle browser back/forward buttons
  useEffect(() => {
    const handleHashChange = () => {
      const hash = window.location.hash.replace(/^#\/?/, '').trim();
      if (hash && VALID_ADMIN_TABS.includes(hash) && hash !== currentTab) {
        setCurrentTab(hash);
      }
    };
    window.addEventListener('hashchange', handleHashChange);
    return () => window.removeEventListener('hashchange', handleHashChange);
  }, [currentTab]);

  useEffect(() => {
    if (currentUser) {
      loadStats();
    }
  }, [currentUser]);

  const loadStats = async () => {
    try {
      const data = await fetchDashboardStats();
      setStats(data);
    } catch (err) {
      console.error('Error fetching dashboard stats', err);
    }
  };

  const handleLogout = () => {
    clearAdminSession();
    localStorage.removeItem('taskbridge_admin_tab');
    window.location.hash = '';
    setCurrentUser(null);
    setCurrentTab('dashboard');
  };

  // If not authenticated, display login screen
  if (!currentUser) {
    return <AdminLogin onLoginSuccess={(u) => setCurrentUser(u)} />;
  }

  const renderContent = () => {
    switch (currentTab) {
      case 'dashboard':
        return stats ? (
          <DashboardView stats={stats} onRefresh={loadStats} />
        ) : (
          <div className="admin-content" style={{ textAlign: 'center', padding: '100px 0' }}>
            <p style={{ color: '#64736a' }}>Loading Operations Console...</p>
          </div>
        );

      case 'service-requests':
        return <ServiceRequestsView />;

      case 'bookings':
        return <BookingsView />;

      case 'inquiries':
        return <InquiriesView />;

      case 'complaints':
        return <ComplaintsView />;

      case 'providers':
        return <ProvidersView />;

      case 'customers':
        return <CustomersView />;

      case 'reviews':
        return <ReviewsView />;

      case 'ai-workflows':
        return <AiWorkflowsView />;

      case 'ai-monitoring':
        return <AiMonitoringView />;

      case 'human-reviews':
        return <HumanReviewsView />;

      case 'chats':
        return <ChatsView />;

      case 'reports':
        return <ReportsView />;

      case 'admin-management':
        if (currentUser.role !== 'SuperAdmin') {
          return (
            <div className="admin-content">
              <div className="admin-table-card" style={{ padding: '60px 24px', textAlign: 'center' }}>
                <h3 style={{ color: '#c81e1e', margin: '0 0 8px 0' }}>Access Restricted</h3>
                <p style={{ color: '#64736a', margin: 0 }}>
                  Only Super Administrators are authorized to access administrator directory and permissions.
                </p>
              </div>
            </div>
          );
        }
        return <AdminManagementView currentUser={currentUser} />;

      case 'audit-logs':
        return <AuditLogsView />;

      case 'settings':
        return <SettingsView />;

      default:
        return stats ? <DashboardView stats={stats} /> : null;
    }
  };

  return (
    <div className="admin-shell">
      <AdminSidebar
        currentTab={currentTab}
        onSelectTab={(tab) => {
          setCurrentTab(tab);
          setMobileMenuOpen(false);
        }}
        currentUser={currentUser}
        onLogout={handleLogout}
        isOpen={mobileMenuOpen}
        onClose={() => setMobileMenuOpen(false)}
      />
      <div className="admin-main">
        <AdminHeader
          currentTab={currentTab}
          currentUser={currentUser}
          onToggleMobileMenu={() => setMobileMenuOpen((prev) => !prev)}
        />
        {renderContent()}
      </div>
    </div>
  );
};
