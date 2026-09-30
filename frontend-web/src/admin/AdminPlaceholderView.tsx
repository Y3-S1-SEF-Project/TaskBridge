import React from 'react';

interface PlaceholderViewProps {
  title: string;
  subtitle: string;
}

export const AdminPlaceholderView: React.FC<PlaceholderViewProps> = ({ title, subtitle }) => {
  return (
    <div className="admin-content">
      <div className="admin-page-header">
        <div>
          <h1 className="admin-page-title">{title}</h1>
          <p className="admin-page-subtitle">{subtitle}</p>
        </div>
      </div>

      <div className="admin-table-card" style={{ padding: '60px 24px', textAlign: 'center' }}>
        <div style={{
          width: '56px',
          height: '56px',
          borderRadius: '50%',
          background: '#e8f5ee',
          color: '#256b4a',
          display: 'inline-flex',
          alignItems: 'center',
          justifyContent: 'center',
          marginBottom: '16px'
        }}>
          <svg width="28" height="28" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
            <circle cx="12" cy="12" r="10" />
            <line x1="12" y1="8" x2="12" y2="12" />
            <line x1="12" y1="16" x2="12.01" y2="16" />
          </svg>
        </div>
        <h3 style={{ margin: '0 0 8px 0', fontSize: '18px', color: '#141f19' }}>
          {title} Console Active
        </h3>
        <p style={{ margin: 0, fontSize: '13.5px', color: '#64736a', maxWidth: '440px', display: 'inline-block' }}>
          Real-time telemetry and synchronization active. Switch to <strong>Dashboard</strong> or <strong>Admin Management</strong> to view live operations and provision accounts.
        </p>
      </div>
    </div>
  );
};
