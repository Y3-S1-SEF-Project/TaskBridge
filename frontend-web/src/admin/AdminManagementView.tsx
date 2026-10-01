import React, { useState, useEffect } from 'react';
import type { AdminUser, CreatedAdminCredentials } from './types';
import { fetchAdmins, createAdminAccount, deleteAdminAccount, updateAdminAccount, toggleAdminStatus } from './api';

interface AdminManagementViewProps {
  currentUser: AdminUser;
}

export const AdminManagementView: React.FC<AdminManagementViewProps> = ({ currentUser }) => {
  const [admins, setAdmins] = useState<AdminUser[]>([]);
  const [loading, setLoading] = useState(true);
  const [showCreateModal, setShowCreateModal] = useState(false);
  const [submitting, setSubmitting] = useState(false);
  const [errorMsg, setErrorMsg] = useState('');

  // Create form fields
  const [fullName, setFullName] = useState('');
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [role, setRole] = useState('Admin');

  // Edit modal fields
  const [editingAdmin, setEditingAdmin] = useState<AdminUser | null>(null);
  const [editFullName, setEditFullName] = useState('');
  const [editRole, setEditRole] = useState('Admin');
  const [editIsActive, setEditIsActive] = useState(true);
  const [editNewPassword, setEditNewPassword] = useState('');
  const [editSubmitting, setEditSubmitting] = useState(false);
  const [editErrorMsg, setEditErrorMsg] = useState('');

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
      setErrorMsg('Please complete all required fields.');
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

      const loginUrl = window.location.origin;
      const formattedCreds: CreatedAdminCredentials = {
        ...creds,
        loginUrl: creds.loginUrl || loginUrl,
      };

      setCreatedCreds(formattedCreds);
      await loadAdmins();
      setFullName('');
      setEmail('');
      setPassword('');
    } catch (err: any) {
      setErrorMsg(err.message || 'Failed to provision admin account.');
    } finally {
      setSubmitting(false);
    }
  };

  const handleOpenEdit = (admin: AdminUser) => {
    setEditingAdmin(admin);
    setEditFullName(admin.fullName);
    setEditRole(admin.role);
    setEditIsActive(admin.isActive !== false);
    setEditNewPassword('');
    setEditErrorMsg('');
  };

  const handleUpdate = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!editingAdmin) return;
    setEditErrorMsg('');

    if (!editFullName.trim()) {
      setEditErrorMsg('Full name cannot be empty.');
      return;
    }

    setEditSubmitting(true);
    try {
      await updateAdminAccount(editingAdmin.id, {
        fullName: editFullName.trim(),
        role: editRole,
        isActive: editIsActive,
        newPassword: editNewPassword.trim() || undefined,
      });

      setEditingAdmin(null);
      await loadAdmins();
    } catch (err: any) {
      setEditErrorMsg(err.message || 'Failed to update administrator access.');
    } finally {
      setEditSubmitting(false);
    }
  };

  const handleToggleStatus = async (admin: AdminUser) => {
    const action = admin.isActive !== false ? 'suspend' : 'activate';
    if (!window.confirm(`Are you sure you want to ${action} access for administrator "${admin.fullName}"?`)) {
      return;
    }

    try {
      await toggleAdminStatus(admin.id);
      await loadAdmins();
    } catch (err: any) {
      alert(err.message || `Failed to ${action} administrator.`);
    }
  };

  const handleDelete = async (id: string, name: string) => {
    if (!window.confirm(`Are you sure you want to permanently revoke access for administrator "${name}"?`)) {
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
        <button
          type="button"
          className="admin-btn admin-btn-primary"
          onClick={() => {
            setCreatedCreds(null);
            setErrorMsg('');
            setShowCreateModal(true);
          }}
        >
          + Provision New Admin
        </button>
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
          <strong>Super Admin Security Rule:</strong> Only Super Administrators can view this section, provision staff accounts, and update or revoke permissions.
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
              ) : admins.map((admin) => {
                const isActive = admin.isActive !== false;
                const isSuper = admin.role === 'SuperAdmin';
                const isSelf = admin.id === currentUser.id;

                return (
                  <tr key={admin.id}>
                    <td>
                      <strong>{admin.fullName}</strong>
                      {isSelf && (
                        <span style={{ marginLeft: '6px', fontSize: '11px', color: '#256b4a', fontWeight: 600 }}>
                          (You)
                        </span>
                      )}
                    </td>
                    <td>{admin.email}</td>
                    <td>
                      <span className={`admin-badge ${isSuper ? 'priority-high' : 'priority-normal'}`}>
                        {admin.role}
                      </span>
                    </td>
                    <td>
                      <span className={`admin-badge ${isActive ? 'status-resolved' : 'priority-high'}`}>
                        {isActive ? 'Active' : 'Suspended'}
                      </span>
                    </td>
                    <td>{new Date(admin.createdAt).toLocaleDateString()}</td>
                    <td style={{ textAlign: 'right' }}>
                      {!isSuper && (
                        <div style={{ display: 'inline-flex', gap: '8px' }}>
                          <button
                            type="button"
                            className="admin-btn admin-btn-secondary"
                            style={{ padding: '4px 10px', fontSize: '12px' }}
                            onClick={() => handleOpenEdit(admin)}
                          >
                            Edit Access
                          </button>

                          <button
                            type="button"
                            className="admin-btn admin-btn-secondary"
                            style={{
                              padding: '4px 10px',
                              fontSize: '12px',
                              color: isActive ? '#92400e' : '#15803d',
                              borderColor: isActive ? '#fef3c7' : '#bbf7d0',
                            }}
                            onClick={() => handleToggleStatus(admin)}
                          >
                            {isActive ? 'Suspend' : 'Activate'}
                          </button>

                          <button
                            type="button"
                            className="admin-btn admin-btn-secondary"
                            style={{ padding: '4px 10px', fontSize: '12px', color: '#c81e1e', borderColor: '#fecaca' }}
                            onClick={() => handleDelete(admin.id, admin.fullName)}
                          >
                            Revoke
                          </button>
                        </div>
                      )}
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
      </div>

      {/* Provision Admin Modal */}
      {showCreateModal && (
        <div className="admin-modal-backdrop" onClick={() => setShowCreateModal(false)}>
          <div className="admin-modal" onClick={(e) => e.stopPropagation()}>
            <div className="admin-modal-header">
              <h2 className="admin-modal-title">
                {createdCreds ? 'Administrator Created' : 'Provision New Administrator'}
              </h2>
              <button
                type="button"
                className="admin-icon-btn"
                onClick={() => setShowCreateModal(false)}
              >
                ✕
              </button>
            </div>

            {createdCreds ? (
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
                      <option value="Admin">Administrator (General Operations)</option>
                      <option value="DisputeAdmin">Dispute Resolution Specialist</option>
                      <option value="SupportAdmin">Support & Verification</option>
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
                    onClick={() => setShowCreateModal(false)}
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

      {/* Edit / Update Admin Modal */}
      {editingAdmin && (
        <div className="admin-modal-backdrop" onClick={() => setEditingAdmin(null)}>
          <div className="admin-modal" onClick={(e) => e.stopPropagation()}>
            <div className="admin-modal-header">
              <h2 className="admin-modal-title">Update Administrator Access</h2>
              <button
                type="button"
                className="admin-icon-btn"
                onClick={() => setEditingAdmin(null)}
              >
                ✕
              </button>
            </div>

            <form onSubmit={handleUpdate}>
              <div className="admin-modal-body">
                {editErrorMsg && (
                  <div className="admin-login-error">{editErrorMsg}</div>
                )}

                <div className="admin-form-group">
                  <label className="admin-form-label">Administrator Email (Immutable)</label>
                  <input
                    type="email"
                    className="admin-form-input"
                    value={editingAdmin.email}
                    disabled
                    style={{ background: '#f3f4f6', cursor: 'not-allowed' }}
                  />
                </div>

                <div className="admin-form-group">
                  <label className="admin-form-label">Full Name</label>
                  <input
                    type="text"
                    className="admin-form-input"
                    value={editFullName}
                    onChange={(e) => setEditFullName(e.target.value)}
                    required
                  />
                </div>

                <div className="admin-form-group">
                  <label className="admin-form-label">Assigned Role</label>
                  <select
                    className="admin-form-select"
                    value={editRole}
                    onChange={(e) => setEditRole(e.target.value)}
                  >
                    <option value="Admin">Administrator (General Operations)</option>
                    <option value="DisputeAdmin">Dispute Resolution Specialist</option>
                    <option value="SupportAdmin">Support & Verification</option>
                  </select>
                </div>

                <div className="admin-form-group">
                  <label className="admin-form-label">Access Status</label>
                  <select
                    className="admin-form-select"
                    value={editIsActive ? 'active' : 'suspended'}
                    onChange={(e) => setEditIsActive(e.target.value === 'active')}
                  >
                    <option value="active">Active (Access Allowed)</option>
                    <option value="suspended">Suspended (Access Revoked)</option>
                  </select>
                </div>

                <div className="admin-form-group">
                  <label className="admin-form-label">
                    Reset Password (Optional)
                  </label>
                  <input
                    type="text"
                    className="admin-form-input"
                    placeholder="Leave blank to keep existing password"
                    value={editNewPassword}
                    onChange={(e) => setEditNewPassword(e.target.value)}
                  />
                </div>
              </div>

              <div className="admin-modal-footer">
                <button
                  type="button"
                  className="admin-btn admin-btn-secondary"
                  onClick={() => setEditingAdmin(null)}
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  className="admin-btn admin-btn-primary"
                  disabled={editSubmitting}
                >
                  {editSubmitting ? 'Updating...' : 'Save Changes'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
};
