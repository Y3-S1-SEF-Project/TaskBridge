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
