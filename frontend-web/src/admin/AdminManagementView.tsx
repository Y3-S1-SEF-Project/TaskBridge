import React, { useState, useEffect } from 'react';
import type { AdminUser, CreatedAdminCredentials } from './types';
import { fetchAdmins, createAdminAccount, deleteAdminAccount } from './api';

interface AdminManagementViewProps {
  currentUser: AdminUser;
}

export const AdminManagementView: React.FC<AdminManagementViewProps> = ({ currentUser }) => {
  const [admins, setAdmins] = useState<AdminUser[]>([]);
  const [loading, setLoading] = useState(true);
  const [showModal, setShowModal] = useState(false);
  const [submitting, setSubmitting] = useState(false);
  const [errorMsg, setErrorMsg] = useState('');

  // Form fields
  const [fullName, setFullName] = useState('');
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [role, setRole] = useState('Admin');

  // Credentials card state after creation
  const [createdCreds, setCreatedCreds] = useState<CreatedAdminCredentials | null>(null);
  const [copied, setCopied] = useState(false);

  useEffect(() => {
    loadAdmins();
  }, []);

  const loadAdmins = async () => {
    setLoading(true);
    try {
      const data = await fetchAdmins();
      setAdmins(data);
    } catch (err: any) {
      setErrorMsg(err.message || 'Failed to load administrators.');
    } finally {
      setLoading(false);
    }
  };

  const handleGeneratePassword = () => {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnpqrstuvwxyz23456789!@#$%';
    let result = '';
    for (let i = 0; i < 10; i++) {
      result += chars.charAt(Math.floor(Math.random() * chars.length));
    }
    setPassword(result);
  };

  const handleCreate = async (e: React.FormEvent) => {
    e.preventDefault();
    setErrorMsg('');
    if (!fullName.trim() || !email.trim() || !password.trim()) {
      setErrorMsg('Please complete all fields.');
      return;
    }

    setSubmitting(true);
    try {
      const creds = await createAdminAccount({
        fullName: fullName.trim(),
        email: email.trim(),
        password: password.trim(),
        role,
      });

      // Update local state with login URL if not provided by backend
      const loginUrl = window.location.origin;
      const formattedCreds: CreatedAdminCredentials = {
        ...creds,
        loginUrl: creds.loginUrl || loginUrl,
      };

      setCreatedCreds(formattedCreds);
      await loadAdmins();
      // Clear form inputs
      setFullName('');
      setEmail('');
      setPassword('');
    } catch (err: any) {
      setErrorMsg(err.message || 'Failed to provision admin account.');
    } finally {
      setSubmitting(false);
    }
  };

  const handleDelete = async (id: string, name: string) => {
    if (!window.confirm(`Are you sure you want to revoke access for administrator "${name}"?`)) {
      return;
    }

    try {
      await deleteAdminAccount(id);
      await loadAdmins();
    } catch (err: any) {
      alert(err.message || 'Failed to remove admin.');
    }
  };

  const handleCopyCredentials = () => {
    if (!createdCreds) return;
    const text = `TaskBridge Operations Console Access:\nLogin Portal: ${createdCreds.loginUrl}\nEmail/Username: ${createdCreds.email}\nTemporary Password: ${createdCreds.temporaryPassword}\nRole: ${createdCreds.role}\n\nPlease keep these credentials secure.`;
    navigator.clipboard.writeText(text);
    setCopied(true);
    setTimeout(() => setCopied(false), 2500);
  };

  return (
    <div className="admin-content">
      {/* Header */}
      <div className="admin-page-header">
        <div>
          <h1 className="admin-page-title">Admin Management</h1>
          <p className="admin-page-subtitle">
            Provision, review, and manage administrator access for TaskBridge Operations.
          </p>
        </div>
        {currentUser.role === 'SuperAdmin' && (
          <button
            type="button"
            className="admin-btn admin-btn-primary"
            onClick={() => {
              setCreatedCreds(null);
              setErrorMsg('');
              setShowModal(true);
            }}
          >
            + Provision New Admin
          </button>
        )}
      </div>

      {/* Info notice */}
      <div style={{
        background: '#eef6f1',
        border: '1px solid #bce1ce',
        borderRadius: '12px',
        padding: '14px 18px',
        fontSize: '13.5px',
        color: '#174832',
        display: 'flex',
        alignItems: 'center',
        gap: '12px'
      }}>
        <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
          <circle cx="12" cy="12" r="10" />
          <line x1="12" y1="16" x2="12" y2="12" />
          <line x1="12" y1="8" x2="12.01" y2="8" />
        </svg>
        <span>
          <strong>Super Admin Security Rule:</strong> Only Super Administrators can provision staff accounts. Once created, a shareable credential card with the Login URL, username, and temporary password will be provided.
        </span>
      </div>

      {/* Admins Table */}
      <div className="admin-table-card">
        <h3 className="admin-table-title">System Administrators ({admins.length})</h3>
        <div className="admin-table-container">
          <table className="admin-table">
            <thead>
              <tr>
                <th>Administrator</th>
                <th>Email / Identifier</th>
                <th>Role</th>
                <th>Status</th>
                <th>Registered</th>
                <th style={{ textAlign: 'right' }}>Actions</th>
              </tr>
            </thead>
            <tbody>
              {loading ? (
                <tr>
                  <td colSpan={6} style={{ textAlign: 'center', padding: '32px' }}>
                    Loading administrators...
                  </td>
                </tr>
              ) : admins.map((admin) => (
                <tr key={admin.id}>
                  <td>
                    <strong>{admin.fullName}</strong>
                  </td>
                  <td>{admin.email}</td>
                  <td>
                    <span className={`admin-badge ${admin.role === 'SuperAdmin' ? 'priority-high' : 'priority-normal'}`}>
                      {admin.role}
                    </span>
                  </td>
                  <td>
                    <span className="admin-badge status-resolved">
                      Active
                    </span>
                  </td>
                  <td>{new Date(admin.createdAt).toLocaleDateString()}</td>
                  <td style={{ textAlign: 'right' }}>
                    {currentUser.role === 'SuperAdmin' && admin.role !== 'SuperAdmin' && (
                      <button
                        type="button"
                        className="admin-btn admin-btn-secondary"
                        style={{ padding: '4px 10px', fontSize: '12px', color: '#c81e1e' }}
                        onClick={() => handleDelete(admin.id, admin.fullName)}
                      >
                        Revoke Access
                      </button>
                    )}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>

      {/* Provision Admin Modal */}
      {showModal && (
        <div className="admin-modal-backdrop" onClick={() => setShowModal(false)}>
          <div className="admin-modal" onClick={(e) => e.stopPropagation()}>
            <div className="admin-modal-header">
              <h2 className="admin-modal-title">
                {createdCreds ? 'Administrator Created' : 'Provision New Administrator'}
              </h2>
              <button
                type="button"
                className="admin-icon-btn"
                onClick={() => setShowModal(false)}
              >
                ✕
              </button>
            </div>

            {createdCreds ? (
              // Step 2: Show credentials card with copy button
              <div className="admin-modal-body">
                <div style={{ textAlign: 'center', padding: '10px 0' }}>
                  <div style={{
                    width: '48px',
                    height: '48px',
                    borderRadius: '50%',
                    background: '#dcfce7',
                    color: '#15803d',
                    display: 'inline-flex',
                    alignItems: 'center',
                    justifyContent: 'center',
                    fontSize: '24px',
                    marginBottom: '12px'
                  }}>
                    ✓
                  </div>
                  <h3 style={{ margin: 0, fontSize: '18px', color: '#141f19' }}>
                    Admin Account Provisioned!
                  </h3>
                  <p style={{ margin: '4px 0 0', fontSize: '13px', color: '#64736a' }}>
                    Copy these credentials and securely provide them to the administrator.
                  </p>
                </div>

                <div className="admin-cred-box">
                  <div className="admin-cred-row">
                    <span className="admin-cred-label">Login Portal:</span>
                    <span className="admin-cred-value">{createdCreds.loginUrl}</span>
                  </div>
                  <div className="admin-cred-row">
                    <span className="admin-cred-label">Email / User:</span>
                    <span className="admin-cred-value">{createdCreds.email}</span>
                  </div>
                  <div className="admin-cred-row">
                    <span className="admin-cred-label">Temporary Password:</span>
                    <span className="admin-cred-value">{createdCreds.temporaryPassword}</span>
                  </div>
                  <div className="admin-cred-row">
                    <span className="admin-cred-label">Assigned Role:</span>
                    <span className="admin-cred-value">{createdCreds.role}</span>
                  </div>
                </div>

                <button
                  type="button"
                  className="admin-btn admin-btn-primary"
                  style={{ width: '100%', padding: '12px', marginTop: '6px' }}
                  onClick={handleCopyCredentials}
                >
                  {copied ? '✓ Credentials Copied to Clipboard!' : '📋 Copy All Login Credentials'}
                </button>
              </div>
            ) : (
              // Step 1: Input form
              <form onSubmit={handleCreate}>
                <div className="admin-modal-body">
                  {errorMsg && (
                    <div className="admin-login-error">{errorMsg}</div>
                  )}

                  <div className="admin-form-group">
                    <label className="admin-form-label">Full Name</label>
                    <input
                      type="text"
                      className="admin-form-input"
                      placeholder="e.g., Nimal Perera"
                      value={fullName}
                      onChange={(e) => setFullName(e.target.value)}
                      required
                    />
                  </div>

                  <div className="admin-form-group">
                    <label className="admin-form-label">Email Address (Login ID)</label>
                    <input
                      type="email"
                      className="admin-form-input"
                      placeholder="e.g., nimal@taskbridge.com"
                      value={email}
                      onChange={(e) => setEmail(e.target.value)}
                      required
                    />
                  </div>

                  <div className="admin-form-group">
                    <label className="admin-form-label">Role</label>
                    <select
                      className="admin-form-select"
                      value={role}
                      onChange={(e) => setRole(e.target.value)}
                    >
                      <option value="Admin">Administrator (Operations & Inquiries)</option>
                      <option value="DisputeAdmin">Dispute Resolution Specialist</option>
                      <option value="SupportAdmin">Support & Moderation</option>
                    </select>
                  </div>

                  <div className="admin-form-group">
                    <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                      <label className="admin-form-label">Temporary Password</label>
                      <button
                        type="button"
                        style={{
                          background: 'none',
                          border: 'none',
                          color: '#256b4a',
                          fontSize: '12px',
                          fontWeight: 600,
                          cursor: 'pointer'
                        }}
                        onClick={handleGeneratePassword}
                      >
                        Auto-generate
                      </button>
                    </div>
                    <input
                      type="text"
                      className="admin-form-input"
                      placeholder="Enter or generate temporary password"
                      value={password}
                      onChange={(e) => setPassword(e.target.value)}
                      required
                    />
                  </div>
                </div>

                <div className="admin-modal-footer">
                  <button
                    type="button"
                    className="admin-btn admin-btn-secondary"
                    onClick={() => setShowModal(false)}
                  >
                    Cancel
                  </button>
                  <button
                    type="submit"
                    className="admin-btn admin-btn-primary"
                    disabled={submitting}
                  >
                    {submitting ? 'Provisioning...' : 'Create & Generate Credentials'}
                  </button>
                </div>
              </form>
            )}
          </div>
        </div>
      )}
    </div>
  );
};
