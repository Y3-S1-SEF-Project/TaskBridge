import React, { useState, useEffect } from 'react';
import type { AdminUser, DashboardStats } from './types';
import { getStoredAdminUser, clearAdminSession, fetchDashboardStats } from './api';
import { AdminLogin } from './AdminLogin';
import { AdminSidebar } from './AdminSidebar';
import { AdminHeader } from './AdminHeader';
import { DashboardView } from './DashboardView';
import { AdminManagementView } from './AdminManagementView';
import { AdminPlaceholderView } from './AdminPlaceholderView';
import './admin.css';

export const AdminApp: React.FC = () => {
  const [currentUser, setCurrentUser] = useState<AdminUser | null>(() => getStoredAdminUser());
  const [currentTab, setCurrentTab] = useState<string>('dashboard');
  const [stats, setStats] = useState<DashboardStats | null>(null);

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

      case 'admin-management':
        if (currentUser.role !== 'SuperAdmin') {
          return (
            <AdminPlaceholderView
              title="Access Restricted"
              subtitle="Only Super Administrators are authorized to access administrator directory and permissions."
            />
          );
        }
        return <AdminManagementView currentUser={currentUser} />;

      case 'service-requests':
        return (
          <AdminPlaceholderView
            title="Service Requests"
            subtitle="Customer work requests, quotes, and active provider bids."
          />
        );

      case 'bookings':
        return (
          <AdminPlaceholderView
            title="Bookings & Jobs"
            subtitle="Scheduled, active, and completed marketplace jobs."
          />
        );

      case 'inquiries':
      case 'complaints':
        return (
          <AdminPlaceholderView
            title={currentTab === 'inquiries' ? 'Dispute Inquiries' : 'Customer Complaints'}
            subtitle="Escalations and dispute resolution records requiring administrative action."
          />
        );

      case 'providers':
        return (
          <AdminPlaceholderView
            title="Verified Providers"
            subtitle="Service provider credentials, certifications, and active verification status."
          />
        );

      case 'customers':
        return (
          <AdminPlaceholderView
            title="Marketplace Customers"
            subtitle="Registered customer accounts, activity histories, and preferences."
          />
        );

      case 'reviews':
        return (
          <AdminPlaceholderView
            title="Feedback & Reviews"
            subtitle="Moderation of customer reviews and provider ratings."
          />
        );

      case 'ai-workflows':
      case 'ai-monitoring':
      case 'human-reviews':
        return (
          <AdminPlaceholderView
            title="AI Orchestration & Monitoring"
            subtitle="Real-time multi-agent workflows (Planning, Matching, Coordination, Review)."
          />
        );

      case 'chats':
        return (
          <AdminPlaceholderView
            title="Audited Communications"
            subtitle="Admin inquiry access for customer/provider dispute resolution."
          />
        );

      case 'reports':
        return (
          <AdminPlaceholderView
            title="Financial & Operational Reports"
            subtitle="Revenue, provider payouts, completed hours, and platform analytics."
          />
        );

      case 'audit-logs':
        return (
          <AdminPlaceholderView
            title="Security & System Audit Logs"
            subtitle="Tamper-evident logs of all administrative inquiries and permission actions."
          />
        );

      case 'settings':
        return (
          <AdminPlaceholderView
            title="System Settings"
            subtitle="Platform operational parameters, commission rates, and AI model configurations."
          />
        );

      default:
        return stats ? <DashboardView stats={stats} /> : null;
    }
  };

  return (
    <div className="admin-shell">
      <AdminSidebar
        currentTab={currentTab}
        onSelectTab={(tab) => setCurrentTab(tab)}
        currentUser={currentUser}
        onLogout={handleLogout}
      />
      <div className="admin-main">
        <AdminHeader currentTab={currentTab} currentUser={currentUser} />
        {renderContent()}
      </div>
    </div>
  );
};
