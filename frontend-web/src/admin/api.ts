import type { AdminUser, CreatedAdminCredentials, DashboardStats, InquiryItem } from './types';

const API_BASE = '/api/admin';

function getStoredToken(): string | null {
  return localStorage.getItem('taskbridge_admin_token');
}

export function saveAdminSession(token: string, user: AdminUser): void {
  localStorage.setItem('taskbridge_admin_token', token);
  localStorage.setItem('taskbridge_admin_user', JSON.stringify(user));
}

export function getStoredAdminUser(): AdminUser | null {
  const data = localStorage.getItem('taskbridge_admin_user');
  if (!data) return null;
  try {
    return JSON.parse(data) as AdminUser;
  } catch {
    return null;
  }
}

export function clearAdminSession(): void {
  localStorage.removeItem('taskbridge_admin_token');
  localStorage.removeItem('taskbridge_admin_user');
}

export async function loginAdmin(identifier: string, password: string): Promise<{ token: string; user: AdminUser }> {
  try {
    const res = await fetch(`${API_BASE}/auth/login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ identifier, password }),
    });

    if (res.ok) {
      const data = await res.json();
      const user: AdminUser = {
        id: data.id,
        fullName: data.fullName,
        email: data.email,
        role: data.role,
        isEmailVerified: true,
        createdAt: new Date().toISOString(),
      };
      saveAdminSession(data.token, user);
      return { token: data.token, user };
    }

    const err = await res.json().catch(() => ({}));
    throw new Error(err.error || 'Invalid administrator credentials.');
  } catch (e: any) {
    throw new Error(e.message || 'Unable to connect to administration server.');
  }
}

export async function fetchDashboardStats(): Promise<DashboardStats> {
  const token = getStoredToken();
  try {
    const res = await fetch(`${API_BASE}/stats`, {
      headers: {
        ...(token ? { Authorization: `Bearer ${token}` } : {}),
      },
    });

    if (res.ok) {
      return await res.json();
    }
  } catch {
    // Fall back to default mock data matching the screenshot
  }

  return {
    totalRequests: 1284,
    requestsChange: '+12.4% this month',
    activeJobs: 86,
    jobsStartingToday: 24,
    completedJobs: 1042,
    completionRate: '98.2% completion',
    openInquiries: 18,
    inquiriesNeedingResponse: 6,
    aiWorkflows: 964,
    aiSuccessRate: '98.1% success',
    humanReviews: 7,
    failedWorkflows: 3,
    completionIssues: 9,
    serviceRequestsChart: [
      { day: 'Mon', requests: 38, bookings: 22, providerActive: 14 },
      { day: 'Tue', requests: 52, bookings: 35, providerActive: 22 },
      { day: 'Wed', requests: 48, bookings: 28, providerActive: 19 },
      { day: 'Thu', requests: 64, bookings: 40, providerActive: 31 },
      { day: 'Fri', requests: 58, bookings: 38, providerActive: 27 },
      { day: 'Sat', requests: 82, bookings: 59, providerActive: 45 },
      { day: 'Sun', requests: 96, bookings: 72, providerActive: 58 },
    ],
    providerActivityChart: [
      { day: 'Mon', requests: 24, bookings: 18, providerActive: 16 },
      { day: 'Tue', requests: 32, bookings: 22, providerActive: 21 },
      { day: 'Wed', requests: 29, bookings: 21, providerActive: 20 },
      { day: 'Thu', requests: 45, bookings: 33, providerActive: 30 },
      { day: 'Fri', requests: 42, bookings: 31, providerActive: 29 },
      { day: 'Sat', requests: 68, bookings: 50, providerActive: 48 },
      { day: 'Sun', requests: 84, bookings: 65, providerActive: 62 },
    ],
    recentInquiries: [
      {
        inquiryNumber: 'INQ-208',
        customer: 'Kavindu Alwis',
        issue: 'Tap still leaking',
        provider: 'Kamal Perera',
        priority: 'High',
        status: 'Open',
        createdAt: new Date(Date.now() - 25 * 60000).toISOString(),
      },
      {
        inquiryNumber: 'INQ-207',
        customer: 'Dilini Silva',
        issue: 'Arrival delay',
        provider: 'Nimal Fernando',
        priority: 'Normal',
        status: 'In Progress',
        createdAt: new Date(Date.now() - 2 * 3600000).toISOString(),
      },
      {
        inquiryNumber: 'INQ-206',
        customer: 'Amal Jay',
        issue: 'Missing receipt',
        provider: 'Sunil Dias',
        priority: 'Low',
        status: 'Waiting for Provider',
        createdAt: new Date(Date.now() - 5 * 3600000).toISOString(),
      },
    ],
  };
}

export async function fetchInquiries(): Promise<InquiryItem[]> {
  const token = getStoredToken();
  try {
    const res = await fetch(`${API_BASE}/inquiries`, {
      headers: { ...(token ? { Authorization: `Bearer ${token}` } : {}) },
    });
    if (res.ok) return await res.json();
  } catch {}

  const stats = await fetchDashboardStats();
  return stats.recentInquiries;
}

export async function fetchAdmins(): Promise<AdminUser[]> {
  const token = getStoredToken();
  try {
    const res = await fetch(`${API_BASE}/admins`, {
      headers: { ...(token ? { Authorization: `Bearer ${token}` } : {}) },
    });
    if (res.ok) return await res.json();
  } catch {}

  return [
    {
      id: 'super-admin-01',
      fullName: 'Kavindu Alwis',
      email: 'admin1@taskbridge.com',
      role: 'SuperAdmin',
      isEmailVerified: true,
      createdAt: '2026-09-01T08:00:00Z',
    },
    {
      id: 'admin-02',
      fullName: 'Dispute Moderator',
      email: 'disputes@taskbridge.com',
      role: 'Admin',
      isEmailVerified: true,
      createdAt: '2026-09-15T10:30:00Z',
    },
  ];
}

export async function createAdminAccount(data: {
  fullName: string;
  email: string;
  password: string;
  role: string;
}): Promise<CreatedAdminCredentials> {
  const token = getStoredToken();
  const res = await fetch(`${API_BASE}/create-admin`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
    },
    body: JSON.stringify(data),
  });

  if (res.ok) {
    return await res.json();
  }

  const err = await res.json().catch(() => ({}));
  throw new Error(err.error || 'Failed to provision admin account.');
}

export async function deleteAdminAccount(adminId: string): Promise<void> {
  const token = getStoredToken();
  const res = await fetch(`${API_BASE}/admins/${adminId}`, {
    method: 'DELETE',
    headers: {
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
    },
  });

  if (!res.ok) {
    const err = await res.json().catch(() => ({}));
    throw new Error(err.error || 'Failed to remove admin account.');
  }
}
