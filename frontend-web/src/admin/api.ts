import type {
  AdminUser,
  CreatedAdminCredentials,
  DashboardStats,
  InquiryItem,
  ServiceRequestsSummary,
  ProvidersSummary,
  CustomersSummary,
  ReviewsSummary,
  BookingsSummary,
  AdminConversation,
  AdminChatMessage,
  AiWorkflowsSummary,
  AiWorkflowTrace,
  AiMonitoringSummary,
} from './types';

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
        isActive: true,
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
    // API failure fallback
  }

  return {
    totalRequests: 0,
    requestsChange: '0%',
    activeJobs: 0,
    jobsStartingToday: 0,
    completedJobs: 0,
    completionRate: '0%',
    openInquiries: 0,
    inquiriesNeedingResponse: 0,
    aiWorkflows: 0,
    aiSuccessRate: '0%',
    humanReviews: 0,
    failedWorkflows: 0,
    completionIssues: 0,
    serviceRequestsChart: [],
    providerActivityChart: [],
    recentInquiries: [],
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

  return [];
}

export async function fetchAdmins(): Promise<AdminUser[]> {
  const token = getStoredToken();
  try {
    const res = await fetch(`${API_BASE}/admins`, {
      headers: { ...(token ? { Authorization: `Bearer ${token}` } : {}) },
    });
    if (res.ok) return await res.json();
  } catch {}

  return [];
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

export async function updateAdminAccount(
  adminId: string,
  data: { fullName: string; role: string; isActive: boolean; newPassword?: string }
): Promise<AdminUser> {
  const token = getStoredToken();
  const res = await fetch(`${API_BASE}/admins/${adminId}`, {
    method: 'PUT',
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
  throw new Error(err.error || 'Failed to update administrator access.');
}

export async function toggleAdminStatus(adminId: string): Promise<{ id: string; isActive: boolean }> {
  const token = getStoredToken();
  const res = await fetch(`${API_BASE}/admins/${adminId}/status`, {
    method: 'PATCH',
    headers: {
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
    },
  });

  if (res.ok) {
    return await res.json();
  }

  const err = await res.json().catch(() => ({}));
  throw new Error(err.error || 'Failed to toggle administrator status.');
}

export async function fetchServiceRequests(params?: {
  search?: string;
  searchBy?: string;
  category?: string;
  status?: string;
  urgency?: string;
}): Promise<ServiceRequestsSummary> {
  const token = getStoredToken();
  const searchParams = new URLSearchParams();
  if (params?.search) searchParams.set('search', params.search);
  if (params?.searchBy) searchParams.set('searchBy', params.searchBy);
  if (params?.category && params.category !== 'All') searchParams.set('category', params.category);
  if (params?.status && params.status !== 'All') searchParams.set('status', params.status);
  if (params?.urgency && params.urgency !== 'All') searchParams.set('urgency', params.urgency);

  const qs = searchParams.toString();
  const url = `${API_BASE}/service-requests${qs ? `?${qs}` : ''}`;

  const res = await fetch(url, {
    headers: {
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
    },
  });

  if (res.ok) {
    return await res.json();
  }

  const err = await res.json().catch(() => ({}));
  throw new Error(err.message || 'Failed to fetch service requests.');
}

export async function fetchProviders(params?: {
  search?: string;
  category?: string;
  status?: string;
}): Promise<ProvidersSummary> {
  const token = getStoredToken();
  const searchParams = new URLSearchParams();
  if (params?.search) searchParams.set('search', params.search);
  if (params?.category && params.category !== 'All') searchParams.set('category', params.category);
  if (params?.status && params.status !== 'All') searchParams.set('status', params.status);

  const qs = searchParams.toString();
  const res = await fetch(`${API_BASE}/providers${qs ? `?${qs}` : ''}`, {
    headers: { ...(token ? { Authorization: `Bearer ${token}` } : {}) },
  });

  if (res.ok) return await res.json();
  const err = await res.json().catch(() => ({}));
  throw new Error(err.message || 'Failed to fetch providers.');
}

export async function toggleProviderStatus(id: string): Promise<{ id: string; isActive: boolean }> {
  const token = getStoredToken();
  const res = await fetch(`${API_BASE}/providers/${id}/status`, {
    method: 'PATCH',
    headers: { ...(token ? { Authorization: `Bearer ${token}` } : {}) },
  });
  if (res.ok) return await res.json();
  const err = await res.json().catch(() => ({}));
  throw new Error(err.message || 'Failed to toggle provider status.');
}

export async function fetchCustomers(params?: {
  search?: string;
  status?: string;
}): Promise<CustomersSummary> {
  const token = getStoredToken();
  const searchParams = new URLSearchParams();
  if (params?.search) searchParams.set('search', params.search);
  if (params?.status && params.status !== 'All') searchParams.set('status', params.status);

  const qs = searchParams.toString();
  const res = await fetch(`${API_BASE}/customers${qs ? `?${qs}` : ''}`, {
    headers: { ...(token ? { Authorization: `Bearer ${token}` } : {}) },
  });

  if (res.ok) return await res.json();
  const err = await res.json().catch(() => ({}));
  throw new Error(err.message || 'Failed to fetch customers.');
}

export async function fetchReviews(params?: {
  search?: string;
  status?: string;
}): Promise<ReviewsSummary> {
  const token = getStoredToken();
  const searchParams = new URLSearchParams();
  if (params?.search) searchParams.set('search', params.search);
  if (params?.status && params.status !== 'All') searchParams.set('status', params.status);

  const qs = searchParams.toString();
  const res = await fetch(`${API_BASE}/reviews${qs ? `?${qs}` : ''}`, {
    headers: { ...(token ? { Authorization: `Bearer ${token}` } : {}) },
  });

  if (res.ok) return await res.json();
  const err = await res.json().catch(() => ({}));
  throw new Error(err.message || 'Failed to fetch reviews.');
}

export async function updateReviewStatus(
  id: string,
  status: string
): Promise<{ id: string; status: string }> {
  const token = getStoredToken();
  const res = await fetch(`${API_BASE}/reviews/${id}/status`, {
    method: 'PATCH',
    headers: {
      'Content-Type': 'application/json',
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
    },
    body: JSON.stringify({ status }),
  });

  if (res.ok) return await res.json();
  const err = await res.json().catch(() => ({}));
  throw new Error(err.message || 'Failed to update review status.');
}

export async function fetchBookings(params?: {
  search?: string;
  status?: string;
}): Promise<BookingsSummary> {
  const token = getStoredToken();
  const searchParams = new URLSearchParams();
  if (params?.search) searchParams.set('search', params.search);
  if (params?.status && params.status !== 'All') searchParams.set('status', params.status);

  const qs = searchParams.toString();
  const res = await fetch(`${API_BASE}/bookings${qs ? `?${qs}` : ''}`, {
    headers: { ...(token ? { Authorization: `Bearer ${token}` } : {}) },
  });

  if (res.ok) return await res.json();
  const err = await res.json().catch(() => ({}));
  throw new Error(err.message || 'Failed to fetch bookings.');
}

export async function fetchAdminConversations(): Promise<AdminConversation[]> {
  const token = getStoredToken();
  const res = await fetch('/api/chat/admin/conversations', {
    headers: { ...(token ? { Authorization: `Bearer ${token}` } : {}) },
  });

  if (res.ok) return await res.json();
  const err = await res.json().catch(() => ({}));
  throw new Error(err.message || 'Failed to fetch conversations.');
}

export async function fetchAdminMessages(conversationId: string): Promise<AdminChatMessage[]> {
  const token = getStoredToken();
  const res = await fetch(`/api/chat/admin/conversations/${conversationId}/messages`, {
    headers: { ...(token ? { Authorization: `Bearer ${token}` } : {}) },
  });

  if (res.ok) return await res.json();
  const err = await res.json().catch(() => ({}));
  throw new Error(err.message || 'Failed to fetch messages.');
}

export async function sendAdminMessage(
  conversationId: string,
  content: string,
  messageType = 'Text',
  mediaUrl?: string | null
): Promise<AdminChatMessage> {
  const token = getStoredToken();
  const res = await fetch('/api/chat/admin/send-message', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
    },
    body: JSON.stringify({
      conversationId,
      content,
      messageType,
      mediaUrl: mediaUrl || null,
    }),
  });

  if (res.ok) return await res.json();
  const err = await res.json().catch(() => ({}));
  throw new Error(err.message || 'Failed to send message.');
}

export async function deleteAdminMessage(messageId: string): Promise<void> {
  const token = getStoredToken();
  const res = await fetch(`/api/chat/admin/messages/${messageId}`, {
    method: 'DELETE',
    headers: { ...(token ? { Authorization: `Bearer ${token}` } : {}) },
  });

  if (res.ok) return;
  const err = await res.json().catch(() => ({}));
  throw new Error(err.message || 'Failed to delete message.');
}

export async function fetchAiWorkflows(params?: {
  agentType?: string;
  status?: string;
  search?: string;
}): Promise<AiWorkflowsSummary> {
  const token = getStoredToken();
  const searchParams = new URLSearchParams();
  if (params?.search) searchParams.set('search', params.search);
  if (params?.agentType && params.agentType !== 'All') searchParams.set('agentType', params.agentType);
  if (params?.status && params.status !== 'All') searchParams.set('status', params.status);

  const qs = searchParams.toString();
  const res = await fetch(`${API_BASE}/ai/workflows${qs ? `?${qs}` : ''}`, {
    headers: { ...(token ? { Authorization: `Bearer ${token}` } : {}) },
  });

  if (res.ok) return await res.json();
  const err = await res.json().catch(() => ({}));
  throw new Error(err.message || 'Failed to fetch AI workflows telemetry.');
}

export async function fetchAiWorkflowTrace(id: string): Promise<AiWorkflowTrace> {
  const token = getStoredToken();
  const res = await fetch(`${API_BASE}/ai/workflows/${encodeURIComponent(id)}/trace`, {
    headers: { ...(token ? { Authorization: `Bearer ${token}` } : {}) },
  });

  if (res.ok) return await res.json();
  const err = await res.json().catch(() => ({}));
  throw new Error(err.message || `Failed to fetch trace for workflow ${id}.`);
}

export async function fetchAiMonitoring(): Promise<AiMonitoringSummary> {
  const token = getStoredToken();
  const res = await fetch(`${API_BASE}/ai/monitoring`, {
    headers: { ...(token ? { Authorization: `Bearer ${token}` } : {}) },
  });

  if (res.ok) return await res.json();
  const err = await res.json().catch(() => ({}));
  throw new Error(err.message || 'Failed to fetch AI monitoring telemetry.');
}
