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

export interface ProviderItem {
  id: string;
  userId: string;
  name: string;
  category: string;
  phone: string;
  location: string;
  rating: number;
  completedJobs: number;
  kycStatus: 'Verified' | 'Pending Review' | 'Rejected' | string;
  accountStatus: 'Active' | 'Under Review' | 'Suspended' | string;
  bio?: string | null;
  hourlyRate: number;
  skills?: string | null;
  services?: string | null;
  joinedDate: string;
}

export interface ProvidersSummary {
  totalProviders: number;
  verifiedCount: number;
  pendingKycCount: number;
  averageRating: number;
  availableCategories: string[];
  items: ProviderItem[];
}

export interface CustomerItem {
  id: string;
  userId: string;
  name: string;
  email: string;
  phone: string;
  district: string;
  bookingsCount: number;
  totalSpent: number;
  status: 'Active' | 'Inactive' | 'Flagged' | string;
  joinedDate: string;
}

export interface CustomersSummary {
  totalCustomers: number;
  activeRepeatRate: string;
  avgLifetimeValue: string;
  accountHealth: string;
  items: CustomerItem[];
}

export interface ReviewItem {
  id: string;
  reviewGuid: string;
  bookingReference: string;
  customerName: string;
  providerName: string;
  service: string;
  rating: number;
  comment: string;
  sentiment: 'Positive' | 'Neutral' | 'Negative' | string;
  status: 'Approved' | 'Flagged' | 'Pending Review' | string;
  createdAt: string;
}

export interface ReviewsSummary {
  totalReviews: number;
  overallRating: number;
  flaggedCount: number;
  positiveSentimentRate: string;
  items: ReviewItem[];
}

export interface BookingItem {
  id: string;
  bookingReference: string;
  serviceTitle: string;
  category: string;
  customerName: string;
  customerId: string | null;
  providerName: string;
  providerId: string | null;
  scheduledWindow: string;
  location: string;
  price: number;
  rateType: string;
  finalPrice: number | null;
  status: string;
  durationMinutes: number | null;
  notes: string | null;
  createdAt: string;
}

export interface BookingsSummary {
  activeJobsCount: number;
  scheduledTodayCount: number;
  totalWorkFunds: number;
  formattedWorkFunds: string;
  completedJobsCount: number;
  items: BookingItem[];
}

export interface AdminConversation {
  id: string;
  bookingReference: string | null;
  customerId: string;
  customerName: string;
  customerPhone?: string | null;
  customerEmail?: string | null;
  customerRole?: string;
  providerId: string;
  providerName: string;
  lastMessageAt: string;
  lastMessageSnippet: string | null;
  unreadCustomer: number;
  unreadProvider: number;
  createdAt: string;
  isSupportChat: boolean;
}

export interface AdminChatMessage {
  id: string;
  conversationId: string;
  senderId: string;
  senderName: string;
  recipientId: string;
  messageType: 'Text' | 'Image' | string;
  content: string;
  mediaUrl?: string | null;
  isRead: boolean;
  createdAt: string;
  isSupportSender: boolean;
}

export interface AiWorkflowItem {
  id: string;
  name: string;
  agentType: string;
  triggerEvent: string;
  latencyMs: number;
  tokensUsed: number;
  status: string;
  model: string;
  timestamp: string;
  createdAt: string;
}

export interface AiWorkflowTraceStep {
  stepNumber: number;
  title: string;
  description: string;
  durationMs: number;
  status: string;
}

export interface AiWorkflowTrace {
  id: string;
  name: string;
  agentType: string;
  model: string;
  triggerEvent: string;
  status: string;
  latencyMs: number;
  promptTokens: number;
  completionTokens: number;
  totalTokens: number;
  estimatedCostUsd: number;
  guardrailStatus: string;
  inputPayload: string;
  outputPayload: string;
  steps: AiWorkflowTraceStep[];
  createdAt: string;
}

export interface AgentTelemetryItem {
  name: string;
  role: string;
  model: string;
  status: string;
  capacity: string;
  requestsToday: number;
  avgLatencyMs: number;
}

export interface TokenDistributionItem {
  label: string;
  percentage: number;
  color: string;
}

export interface AiMonitoringSummary {
  modelInferenceSuccess: string;
  totalTokensToday: number;
  estimatedCostToday: string;
  p95Latency: string;
  guardrailInterceptions: number;
  agents: AgentTelemetryItem[];
  tokenDistribution: TokenDistributionItem[];
}

export interface AiWorkflowsSummary {
  activeAgents: number;
  executionsToday: number;
  autonomousCompletionRate: string;
  averageLatency: string;
  humanReviewFallbacks: number;
  workflows: AiWorkflowItem[];
}

export interface DisputeRecord {
  id: string;
  disputeReference: string;
  bookingId?: string | null;
  bookingReference: string;
  customerId?: string | null;
  customerName: string;
  customerPhone?: string | null;
  customerEmail?: string | null;
  providerId?: string | null;
  providerName: string;
  serviceTitle: string;
  category: string;
  feeAmount: number;
  reasonCategory: string;
  description: string;
  desiredResolution: string;
  beforePhotoUrls: string[];
  afterPhotoUrls: string[];
  customerEvidencePhotoUrls: string[];
  status: string; // PendingAdminReview, UnderInvestigation, Resolved, Cancelled
  resolutionSummary?: string | null;
  resolutionAction?: string | null;
  resolvedByAdminName?: string | null;
  resolvedAt?: string | null;
  createdAt: string;
  updatedAt?: string | null;
}

export interface DisputesSummary {
  totalDisputes: number;
  pendingCount: number;
  resolvedCount: number;
  disputes: DisputeRecord[];
}


