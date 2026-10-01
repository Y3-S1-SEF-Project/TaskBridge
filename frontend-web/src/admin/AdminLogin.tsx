import React, { useState } from 'react';
import type { AdminUser } from './types';
import { loginAdmin } from './api';

interface AdminLoginProps {
  onLoginSuccess: (user: AdminUser) => void;
}

export const AdminLogin: React.FC<AdminLoginProps> = ({ onLoginSuccess }) => {
  const [identifier, setIdentifier] = useState('');
  const [password, setPassword] = useState('');
  const [showPassword, setShowPassword] = useState(false);
  const [loading, setLoading] = useState(false);
  const [errorMsg, setErrorMsg] = useState('');

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setErrorMsg('');

    if (!identifier.trim() || !password.trim()) {
      setErrorMsg('Please enter your administrator username and password.');
      return;
    }

    setLoading(true);
    try {
      const { user } = await loginAdmin(identifier.trim(), password.trim());
      onLoginSuccess(user);
    } catch (err: any) {
      setErrorMsg(err.message || 'Invalid administrator credentials.');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="admin-login-screen">
      <div className="admin-login-card">
        {/* Brand */}
        <div className="admin-login-brand">
          <h1 className="admin-login-logo">TASKBRIDGE</h1>
          <div className="admin-login-tagline">Operations Console</div>
        </div>

        {errorMsg && (
          <div className="admin-login-error">
            {errorMsg}
          </div>
        )}

        {/* Login Form */}
        <form onSubmit={handleSubmit} style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
          <div className="admin-form-group">
            <label className="admin-form-label">Username or Admin Email</label>
            <input
              type="text"
              className="admin-form-input"
              placeholder="Enter your username or email"
              value={identifier}
              onChange={(e) => setIdentifier(e.target.value)}
              required
              autoFocus
            />
          </div>

          <div className="admin-form-group">
            <label className="admin-form-label">Password</label>
            <div style={{ position: 'relative' }}>
              <input
                type={showPassword ? 'text' : 'password'}
                className="admin-form-input"
                style={{ width: '100%', boxSizing: 'border-box', paddingRight: '40px' }}
                placeholder="Enter your password"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                required
              />
              <button
                type="button"
                onClick={() => setShowPassword(!showPassword)}
                style={{
                  position: 'absolute',
                  right: '10px',
                  top: '50%',
                  transform: 'translateY(-50%)',
                  background: 'none',
                  border: 'none',
                  cursor: 'pointer',
                  color: '#64736a',
                  fontSize: '12px'
                }}
              >
                {showPassword ? 'Hide' : 'Show'}
              </button>
            </div>
          </div>

          <button
            type="submit"
            className="admin-btn admin-btn-primary"
            style={{ width: '100%', padding: '12px', marginTop: '10px', fontSize: '14.5px' }}
            disabled={loading}
          >
            {loading ? 'Authenticating...' : 'Sign In to Operations Console'}
          </button>
        </form>

        <p style={{
          marginTop: '24px',
          textAlign: 'center',
          fontSize: '11.5px',
          color: '#8a9990',
          lineHeight: '1.4'
        }}>
          Protected internal console. All administrative access events are cryptographically audited and monitored.
        </p>
      </div>
    </div>
  );
};
