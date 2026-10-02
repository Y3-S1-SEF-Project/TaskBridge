export interface AdminUser {
  id: string;
  fullName: string;
  email: string;
  role: 'SuperAdmin' | 'Admin' | string;
  isEmailVerified?: boolean;
  isActive: boolean;
  createdAt: string;
}

export interface DayActivity {
  day: string;
  requests: number;
  bookings: number;
  providerActive: number;
}

export interface InquiryItem {
  inquiryNumber: string;
  customer: string;
  issue: string;
  provider: string;
  priority: 'High' | 'Normal' | 'Low' | string;
  status: 'Open' | 'In Progress' | 'Waiting for Provider' | 'Under Review' | 'Resolved' | string;
  createdAt: string;
}

export interface DashboardStats {
  totalRequests: number;
  requestsChange: string;
  activeJobs: number;
  jobsStartingToday: number;
  completedJobs: number;
  completionRate: string;
  openInquiries: number;
  inquiriesNeedingResponse: number;
  aiWorkflows: number;
  aiSuccessRate: string;
  humanReviews: number;
  failedWorkflows: number;
  completionIssues: number;
  serviceRequestsChart: DayActivity[];
  providerActivityChart: DayActivity[];
  recentInquiries: InquiryItem[];
}

export interface CreatedAdminCredentials {
  id: string;
  fullName: string;
  email: string;
  role: string;
  temporaryPassword: string;
  loginUrl: string;
  message: string;
}

export interface ServiceRequestItem {
  id: string;
  reference: string;
  customerName: string;
  customerId?: string | null;
  providerName: string;
  providerId?: string | null;
  serviceTitle: string;
  category: string;
  location: string;
  preferredSchedule: string;
  price: number;
  rateType: string;
  status: string;
  urgency: 'Immediate' | 'Scheduled' | 'Flexible' | string;
  notes?: string | null;
  createdAt: string;
  linkedBookingReference?: string | null;
}

export interface ServiceRequestsSummary {
  totalRequests: number;
  pendingCount: number;
  acceptedCount: number;
  completedCount: number;
  cancelledCount: number;
  availableCategories: string[];
  items: ServiceRequestItem[];
}

