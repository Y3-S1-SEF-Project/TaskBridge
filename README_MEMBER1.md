# TaskBridge — Service Request Management & AI Planning Agent (Member 1)

## Overview
This document summarizes the architecture, database schema, REST APIs, AI agent logic, unit tests, and Flutter mobile integration implemented for **Member 1: Service Request Management & AI Planning Agent**.

---

## 1. Database Layer (PostgreSQL / Entity Framework Core)

### **`backend.Api/Data/ServiceRequestEntity.cs`** *(New)*
- Defines the `ServiceRequestEntity` representing customer service requests before assignment.
- **Key Fields:**
  - `Id` (UUID, Primary Key)
  - `CustomerId` (Customer identifier)
  - `Title` (Trade / service name)
  - `Category` (e.g., Plumbing, Electrical, HVAC, Carpentry, Cleaning)
  - `Description` (Full user prompt / problem description)
  - `Location` (Parsed or provided location)
  - `EstimatedBudget` (Estimated cost / budget range)
  - `ScheduledDate` & `ScheduledTime` (Requested appointment schedule)
  - `Status` (Default: `Pending`, transitions to `Assigned`, `Completed`, `Cancelled`)
  - `MediaUrlsJson` (JSON array of attached image/video URLs)
  - `AiPlanJson` (Structured AI plan: Acceptance Checklist, tools, safety risks)
  - `CancellationReason` (Captured reason when a request is cancelled)
  - `CreatedAt` & `UpdatedAt` (Timestamps)

### **`backend.Api/Data/AuthDbContext.cs`** *(Modified)*
- Registered `DbSet<ServiceRequestEntity> ServiceRequests`.
- Added schema creation logic in `EnsureSchemaAsync` to ensure the table and indexes exist on database startup.

---

## 2. Backend REST APIs & DTOs

### **`backend.Api/Requests/ServiceRequestsController.cs`** *(New)*
Exposes 7 REST endpoints for service request lifecycle and planning:
| Method | Endpoint | Description |
| :--- | :--- | :--- |
| `POST` | `/api/requests` | Creates a new service request and stores the AI plan. |
| `GET` | `/api/requests/my` | Retrieves all service requests submitted by the current user. |
| `GET` | `/api/requests/{id}` | Retrieves a single service request by ID. |
| `GET` | `/api/requests/all` | Lists all active requests (used for service matching). |
| `POST` | `/api/requests/{id}/clarify` | Adds clarification details/answers to an existing request. |
| `PUT` | `/api/requests/{id}/cancel` | Cancels a request with a user-supplied cancellation reason. |
| `POST` | `/api/agent/planning/analyze` | Executes the AI planning agent pipeline on user input. |

### **`backend.Api/Requests/ServiceRequestDTOs.cs`** *(New)*
- `CreateServiceRequestDto`: Payload schema for submitting a new request.
- `ClarifyServiceRequestDto`: Payload schema for adding clarification details.
- `CancelServiceRequestDto`: Payload schema containing the cancellation reason.
- `ServiceRequestResponseDto`: Response schema returned to client applications.

---

## 3. AI Planning Agent Engine

### **`backend.Api/AI/Planning/PlanningAgentService.cs`** *(Modified)*
- **Natural Language Parsing:** Extracts trade category, service type, location, schedule, and budget constraints from natural language descriptions.
- **Missing Fields Detection:** Identifies missing parameters to prompt the user during intake.
- **AI Acceptance Checklist Generation:** Automatically generates ≥ 3 actionable acceptance milestones, required tools/materials, and safety precautions.

### **`backend.Api/AI/Planning/PlanningModels.cs`** *(Modified)*
- Updated `PlanningAnalyzeRequest` model to support `ScheduledDate`, `ScheduledTime`, and `Budget` context passed from the client.

---

## 4. Automated Testing (xUnit)

### **`backend.Api/Tests/PlanningTests.cs`** *(New)*
- **9 automated unit tests** verifying:
  - Trade category and service title detection.
  - Schedule and location extraction.
  - Acceptance checklist generation (≥ 3 milestones, tools, risks).
  - Budget range estimation.
  - In-memory database persistence, status transitions, and cancellation flows.

### **`backend.Api/Tests/TaskBridge.Auth.Tests.csproj`** *(Modified)*
- Added `Microsoft.EntityFrameworkCore.InMemory` package reference to enable fast, isolated unit test execution for database queries.

---

## 5. Flutter Mobile Client Integration

### **`mobile_app/lib/ai/services/service_requests_api.dart`** *(New)*
- Dedicated Dart HTTP service handling communication with `/api/requests` endpoints (create request, fetch user requests, cancel request).

### **`mobile_app/lib/ai/pages/planning_progress_page.dart`** *(Modified)*
- Integrated `_autoSaveServiceRequest()` to automatically persist the service request and its AI plan to PostgreSQL when the intake planning process finishes.

---

## Summary of File Paths

```text
TaskBridge/
├── backend.Api/
│   ├── AI/
│   │   └── Planning/
│   │       ├── PlanningAgentService.cs      (Modified - AI planning & checklist logic)
│   │       └── PlanningModels.cs            (Modified - Request models)
│   ├── Data/
│   │   ├── AuthDbContext.cs                 (Modified - Registered DbSet & schema)
│   │   └── ServiceRequestEntity.cs          (New - Database entity)
│   ├── Requests/
│   │   ├── ServiceRequestDTOs.cs            (New - Request/response DTOs)
│   │   └── ServiceRequestsController.cs     (New - 7 REST endpoints)
│   └── Tests/
│       ├── PlanningTests.cs                 (New - 9 xUnit unit tests)
│       └── TaskBridge.Auth.Tests.csproj     (Modified - InMemory EF package)
└── mobile_app/
    └── lib/
        └── ai/
            ├── pages/
            │   └── planning_progress_page.dart (Modified - Auto-save integration)
            └── services/
                └── service_requests_api.dart   (New - Flutter API client)
```
