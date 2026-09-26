# 🛠️ TaskBridge

<div align="center">

### **Intelligent AI-Powered Service Marketplace**

_Connecting Customers to Verified Specialists with Autonomous Multi-Agent AI Workflows_

[![.NET 10](https://img.shields.io/badge/.NET-10.0-512BD4?logo=dotnet&logoColor=white)](https://dotnet.microsoft.com/)
[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter&logoColor=white)](https://flutter.dev/)
[![React](https://img.shields.io/badge/React-19.x-61DAFB?logo=react&logoColor=black)](https://react.dev/)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-16+-4169E1?logo=postgresql&logoColor=white)](https://www.postgresql.org/)
[![Cloudflare R2](https://img.shields.io/badge/Storage-Cloudflare_R2-F38020?logo=cloudflare&logoColor=white)](https://www.cloudflare.com/products/r2/)
[![OpenAI](https://img.shields.io/badge/Agentic_AI-GPT--4o_Mini-412991?logo=openai&logoColor=white)](https://openai.com/)

</div>

---

## 📌 Table of Contents

- [About TaskBridge](#-about-taskbridge)
- [System Architecture & Business Components](#-system-architecture--business-components)
  - [1. Service Request Management — Planning Agent](#1-service-request-management--planning-agent)
  - [2. Service Provider Management — Matching Agent](#2-service-provider-management--matching-agent)
  - [3. Negotiation & Booking Management — Coordination Agent](#3-negotiation--booking-management--coordination-agent)
  - [4. Operations, Review & Support Management — Review Agent](#4-operations-review--support-management--review-agent)
- [Cross-Cutting Platform Features](#-cross-cutting-platform-features)
  - [Real-Time Encrypted Chat](#real-time-encrypted-chat)
  - [Enterprise Authentication & Security](#enterprise-authentication--security)
  - [Dual Customer / Provider Mode](#dual-customer--provider-mode)
  - [Geospatial Distance Calculation](#geospatial-distance-calculation)
- [Technology Stack](#-technology-stack)
- [Project Directory Structure](#-project-directory-structure)
- [API Endpoints Overview](#-api-endpoints-overview)
- [Getting Started](#-getting-started)
  - [Prerequisites](#prerequisites)
  - [Backend Setup (.NET 10 Web API)](#1-backend-setup-net-10-web-api)
  - [Mobile App Setup (Flutter)](#2-mobile-app-setup-flutter)
  - [Web Frontend Setup (React + Vite)](#3-web-frontend-setup-react--vite)
- [Environment Configuration](#-environment-configuration)
- [Team Responsibility & Grading Matrix](#-team-responsibility--grading-matrix)

---

## 📖 About TaskBridge

**TaskBridge** is an enterprise-grade, full-stack service marketplace that connects everyday customers with qualified service providers (electricians, plumbers, carpenters, painters, HVAC specialists, and technicians).

Traditional platforms suffer from friction: vague customer descriptions, manual scheduling delays, price disputes, and lack of accountability upon job completion. TaskBridge eliminates this by coupling **four core business components** with **four specialized, autonomous AI agents** that plan, match, coordinate, and review every stage of the service lifecycle.

---

## 🏗️ System Architecture & Business Components

TaskBridge is engineered into four discrete business subsystems, each paired with an autonomous Agentic AI service:

```
┌────────────────────────────────────────────────────────────────────────────────────────┐
│                                   TASKBRIDGE PLATFORM                                  │
└────────────────────────────────────────────────────────────────────────────────────────┘
         │                                                            │
         ▼                                                            ▼
┌───────────────────────────────────────────┐    ┌───────────────────────────────────────────┐
│ 1. Service Request Management             │    │ 2. Service Provider Management            │
│ Main User: Customer                       │    │ Main User: Provider                       │
│ 🤖 Planning Agent                         │    │ 🤖 Matching Agent                         │
│ • Service request creation & intake       │    │ • Provider onboarding & profiles          │
│ • Photo uploads & AI analysis             │    │ • Category, skills, & certifications      │
│ • Checklist & subtask decomposition       │    │ • Haversine geodesic distance scoring     │
│ • Dynamic clarification / missing info    │    │ • Availability scheduling & quotations    │
└───────────────────────────────────────────┘    └───────────────────────────────────────────┘
         │                                                            │
         └─────────────────────────────┬──────────────────────────────┘
                                       │
                                       ▼
┌────────────────────────────────────────────────────────────────────────────────────────┐
│ 3. Negotiation & Booking Management                                                    │
│ Main Users: Customer + Provider                                                        │
│ 🤖 Coordination Agent                                                                  │
│ • AI match recommendation & quotation comparison                                      │
│ • Bid / counter-proposal negotiation engine (hourly vs. fixed pricing)                 │
│ • Mutually agreed schedule, price confirmation, & booking lifecycle                    │
│ • Real-time booking states (Requested -> Upcoming -> Active -> Completed)              │
└────────────────────────────────────────────────────────────────────────────────────────┘
                                       │
                                       ▼
┌────────────────────────────────────────────────────────────────────────────────────────┐
│ 4. Operations, Review & Support Management                                             │
│ Main Users: Admin + Customer + Provider                                                │
│ 🤖 Review Agent                                                                        │
│ • Multimodal Vision AI verification of "Before" vs. "After" photos                     │
│ • Task completion audit against the agreed job checklist                               │
│ • Automated duration tracking, overtime detection, & final bill calculation            │
│ • Customer sign-off, star ratings, dispute escalation, & admin audit logs              │
└────────────────────────────────────────────────────────────────────────────────────────┘
```

---

### 1. Service Request Management — Planning Agent

- **Main User:** Customer
- **Agent Folder:** `backend.Api/AI/Planning/`
- **Core Responsibilities:**
  - **Intake & Multi-Modal Input:** Customers submit service requests with natural-language problem descriptions, photo uploads, preferred dates/times, location, and estimated budgets.
  - **Intelligent Job Plan Generation:** The Planning Agent parses the customer's input and breaks the job down into structured subtasks, required tools/materials, safety risk assessments, and an execution checklist.
  - **Dynamic Clarification Engine:** When a request is ambiguous (e.g., _"my sink is leaking"_), the agent identifies missing details and presents follow-up clarification questions to the customer before dispatching providers.

### 2. Service Provider Management — Matching Agent

- **Main User:** Service Provider
- **Agent Folder:** `backend.Api/AI/Matching/`
- **Core Responsibilities:**
  - **Provider Onboarding & Profile Verification:** Providers manage categories, individual trade skills, certifications, hourly rates, service areas, and availability schedules.
  - **Intelligent Matching & Scoring:** The Matching Agent evaluates active customer requests against verified providers using a multi-factor ranking algorithm:
    - **Geodesic Distance:** Haversine formula calculation using exact Sri Lankan geographical coordinates.
    - **Skill & Category Relevance:** Keyword and semantic similarity between requested tasks and provider skills.
    - **Performance Metrics:** Real customer ratings and completed job history.
    - **Availability Match:** Alignment between customer preferred schedule and provider working hours.

### 3. Negotiation & Booking Management — Coordination Agent

- **Main User:** Customer + Service Provider
- **Agent Folder:** `backend.Api/AI/Coordination/`
- **Core Responsibilities:**
  - **Quotation & Proposal Dispatch:** Matched providers receive job opportunities and submit structured quotations.
  - **Bidding & Counter-Proposal Arbitration:** Supports multi-round negotiation between customer and provider on price (Hourly vs. Fixed) and time slots.
  - **Coordination AI Recommendations:** The agent analyzes competing quotations and recommends the best-value provider with transparent reasoning.
  - **Booking Lifecycle Management:** Manages transition through states (`Requested` → `Upcoming` → `Active` → `Completed` → `Cancelled`) backed by `BookingEntity` and `ProposalEntity`.

### 4. Operations, Review & Support Management — Review Agent

- **Main User:** Admin + Customer + Service Provider
- **Agent Folder:** `backend.Api/AI/Review/`
- **Core Responsibilities:**
  - **Proof of Work Uploads:** When a provider starts and finishes a job, they capture "Before" and "After" photos directly via the mobile app.
  - **Multimodal AI Vision Inspection:** The Review Agent uses vision AI to compare before and after photos against the checklist established by the Planning Agent, generating a confidence score, verification status, and checklist compliance report.
  - **Automated Duration & Pricing:** Tracks actual elapsed time, applies agreed hourly rates, and generates final invoice breakdowns.
  - **Human Approval & Dispute Resolution:** If AI confidence is low or discrepancies are detected, the job is flagged for human review/customer dispute handling.
  - **Customer Feedback:** Customers submit star ratings and detailed reviews, which update provider reputation metrics in real time.

---

## ⚡ Cross-Cutting Platform Features

### Real-Time Encrypted Chat

- **SignalR WebSockets:** Instant bidirectional messaging between customers and providers.
- **End-to-End Encryption:** Messages are encrypted with AES-256-GCM before storage; plaintext never touches database tables in unencrypted form.
- **Rich Media Attachments:** Upload image attachments stored securely on Cloudflare R2.
- **Admin Audit Trails:** Designated administrators can review flagged conversations with compulsory reason logging (`ChatAuditLog`).

### Enterprise Authentication & Security

- **Password Hashing:** ASP.NET Core `PasswordHasher<AppUser>` configured with **210,000 PBKDF2 iterations**.
- **Two-Factor Email OTP:** OTP codes with expiration timestamps sent via automated email services.
- **Rate Limiting:** IP-based partition rate limiter protecting auth routes against credential stuffing and brute-force attacks (HTTP 429).
- **Session Management:** Secure token-based session authentication with locked-out account safeguards.
- **Cache Immunity:** Automatic `Cache-Control: no-store` headers applied to sensitive authentication routes.

### Dual Customer / Provider Mode

- The mobile application supports seamless switching between **Customer Mode** (searching, booking, tracking) and **Provider Mode** (accepting jobs, counter-bidding, uploading proof of completion, tracking earnings) using a single account.

### Geospatial Distance Calculation

- Native Haversine formula calculation mapped against a comprehensive database of Sri Lankan cities and coordinates (Colombo, Boralesgamuwa, Maharagama, Kandy, Galle, etc.) to compute real travel distances.

---

## 💻 Technology Stack

| Layer                | Technologies                                                                     |
| :------------------- | :------------------------------------------------------------------------------- |
| **Backend API**      | ASP.NET Core Web API (.NET 10.0), C# 13, Entity Framework Core                   |
| **Database**         | PostgreSQL 16+ (Npgsql EF Core Provider), raw SQL schema bootstrap               |
| **Mobile Client**    | Flutter 3.x (Dart), Riverpod/Stateful architecture, Material 3 Design            |
| **Web Frontend**     | React 19, TypeScript, Vite, Vanilla CSS Design System                            |
| **AI & LLM**         | OpenAI GPT-4o-mini (structured planning, coordination, multimodal vision review) |
| **Real-Time Engine** | ASP.NET Core SignalR WebSockets                                                  |
| **Cloud Storage**    | Cloudflare R2 Object Storage (S3-compatible API), Cloudinary                     |
| **Security**         | PBKDF2 (210k iterations), AES-256-GCM message encryption, ASP.NET RateLimiter    |

---

## 📁 Project Directory Structure

```text
TaskBridge/
├── backend.Api/                       # ASP.NET Core 10 Web API Backend
│   ├── AI/                            # Multi-Agent AI Subsystems
│   │   ├── Planning/                  # Component 1: Service Request & Planning Agent
│   │   │   ├── PlanningAgentController.cs
│   │   │   ├── PlanningAgentService.cs
│   │   │   └── PlanningModels.cs
│   │   ├── Matching/                  # Component 2: Service Provider & Matching Agent
│   │   │   ├── MatchingAgentController.cs
│   │   │   ├── MatchingAgentService.cs
│   │   │   └── MatchingModels.cs
│   │   ├── Coordination/              # Component 3: Negotiation & Coordination Agent
│   │   │   ├── CoordinationAgentController.cs
│   │   │   ├── CoordinationAgentService.cs
│   │   │   ├── CoordinationModels.cs
│   │   │   ├── BookingEntity.cs       # Booking database entity
│   │   │   └── ProposalEntity.cs      # Proposal database entity
│   │   └── Review/                    # Component 4: Operations & Review Agent
│   │       ├── ReviewAgentController.cs
│   │       ├── ReviewAgentService.cs
│   │       ├── ReviewModels.cs
│   │       └── ProofUploadController.cs
│   ├── Auth/                          # Modular Authentication Subsystem
│   │   ├── Controllers/               # AuthController.cs
│   │   ├── DTOs/                      # Request & Response Data Contracts
│   │   │   ├── Requests/              # Login, Register, OTP, Profile DTOs
│   │   │   └── Responses/             # AuthResponse, UserResponse, Challenge
│   │   ├── Entities/                  # AppUser.cs, ProviderProfile.cs
│   │   └── Services/                  # AuthService, Crypto, Email, SMS, R2 Storage
│   ├── Chat/                          # SignalR Hub, Controllers, E2E Encryption
│   ├── Data/                          # AuthDbContext.cs & ChatEntities.cs
│   ├── Database/                      # Database scripts & initial SQL
│   ├── Providers/                     # ProvidersController.cs & Haversine search
│   └── Program.cs                     # DI Registrations, Middleware, Pipeline
│
├── frontend-web/                      # React + TypeScript Operations Portal
│   ├── src/
│   │   ├── design-system/             # Design System Components & Theme Showcase
│   │   ├── App.tsx
│   │   └── index.css
│   └── package.json
│
└── mobile_app/                        # Flutter Mobile Application
    └── lib/
        ├── ai/                        # AI Screens: Planning, Progress, Matching, Quotes
        ├── auth/                      # Login, Registration, OTP verification
        ├── chat/                      # Customer & Provider Real-Time Chat Screens
        ├── home/                      # Customer Dashboard, Booking Flow, Specialist Finder
        ├── provider/                  # Provider Dashboard, Bidding, Proof Upload
        └── main.dart                  # App bootstrap & Theme configuration
```

---

## 🔌 API Endpoints Overview

| Category            | Method | Endpoint                               | Description                                      |
| :------------------ | :----- | :------------------------------------- | :----------------------------------------------- |
| **Auth**            | `POST` | `/api/auth/register`                   | Register new account & trigger email OTP         |
|                     | `POST` | `/api/auth/verify-otp`                 | Verify OTP code and issue session token          |
|                     | `POST` | `/api/auth/login`                      | Email/phone and password authentication          |
|                     | `GET`  | `/api/auth/me`                         | Fetch authenticated user profile                 |
|                     | `POST` | `/api/auth/profile`                    | Update profile information and preferences       |
|                     | `POST` | `/api/auth/profile/photo`              | Upload profile photo to Cloudflare R2            |
| **Providers**       | `GET`  | `/api/providers`                       | Query providers by category, text, & location    |
|                     | `GET`  | `/api/providers/{id}`                  | Get detailed provider profile by ID              |
| **Planning AI**     | `POST` | `/api/ai/planning/plan`                | Generate subtasks, checklist, and requirements   |
|                     | `POST` | `/api/ai/planning/clarify`             | Generate follow-up questions for missing details |
| **Matching AI**     | `POST` | `/api/ai/matching/match`               | Score and rank candidate providers for a job     |
| **Coordination AI** | `POST` | `/api/ai/coordination/evaluate`        | Compare bids and recommend best-value provider   |
|                     | `POST` | `/api/ai/coordination/proposal`        | Provider creates formal job proposal/quote       |
|                     | `POST` | `/api/ai/coordination/proposal/accept` | Customer accepts proposal and confirms booking   |
|                     | `POST` | `/api/ai/coordination/counter-bid`     | Submit counter-offer on price or schedule        |
|                     | `GET`  | `/api/ai/coordination/bookings`        | List user bookings by customer/provider ID       |
| **Review AI**       | `POST` | `/api/proofs/upload`                   | Upload before/after proof images                 |
|                     | `POST` | `/api/ai/review/submit`                | Submit job completion proof & start AI review    |
|                     | `POST` | `/api/ai/review/analyze`               | AI vision analysis of before/after photos        |
|                     | `POST` | `/api/ai/review/customer-approve`      | Customer final sign-off & completion             |
|                     | `POST` | `/api/ai/review/feedback`              | Submit star rating and written review            |
| **Chat**            | `GET`  | `/api/chat/conversations`              | Get active chat conversations                    |
|                     | `POST` | `/api/chat/messages`                   | Send encrypted chat message                      |
|                     | `WS`   | `/hubs/chat`                           | SignalR WebSocket connection for live events     |

---

## 🚀 Getting Started

### Prerequisites

- [.NET 10.0 SDK](https://dotnet.microsoft.com/download/dotnet/10.0)
- [Flutter SDK 3.x](https://docs.flutter.dev/get-started/install)
- [Node.js 20+ & npm](https://nodejs.org/)
- [PostgreSQL 15+](https://www.postgresql.org/)

---

### 1. Backend Setup (.NET 10 Web API)

1. Navigate to the backend directory:
   ```bash
   cd backend.Api
   ```
2. Configure your local database connection and API keys in `appsettings.Local.json` (or set environment variables):
   ```json
   {
     "ConnectionStrings": {
       "TaskBridge": "Host=localhost;Database=taskbridge;Username=postgres;Password=your_password"
     },
     "OpenAI": {
       "ApiKey": "sk-your-openai-api-key"
     },
     "CloudflareR2": {
       "AccountId": "your_account_id",
       "AccessKeyId": "your_access_key",
       "SecretAccessKey": "your_secret_key",
       "BucketName": "taskbridge-media",
       "PublicUrl": "https://pub-your-bucket.r2.dev"
     }
   }
   ```
3. Restore packages and build:
   ```bash
   dotnet restore
   dotnet build
   ```
4. Run the API:
   ```bash
   dotnet run
   ```
   _The backend will automatically initialize the database schema on launch and listen on `http://localhost:5000` / `https://localhost:5001`._

---

### 2. Mobile App Setup (Flutter)

1. Navigate to the mobile application directory:
   ```bash
   cd mobile_app
   ```
2. Install dependencies:
   ```bash
   flutter pub get
   ```
3. Run on an emulator or connected device:
   ```bash
   flutter run
   ```

---

### 3. Web Frontend Setup (React + Vite)

1. Navigate to the web frontend directory:
   ```bash
   cd frontend-web
   ```
2. Install dependencies:
   ```bash
   npm install
   ```
3. Start development server:
   ```bash
   npm run dev
   ```
   _Access the web app at `http://localhost:5173`._

---

## 🔒 Environment Configuration

Key configuration parameters used across the system:

| Key                            | Description                                                                 |
| :----------------------------- | :-------------------------------------------------------------------------- |
| `ConnectionStrings:TaskBridge` | PostgreSQL connection string                                                |
| `OpenAI:ApiKey`                | API key for GPT-4o-mini planning, matching, coordination, and vision review |
| `CloudflareR2:BucketName`      | Cloudflare R2 bucket for profile photos and job completion proof photos     |
| `EmailOtp:SmtpHost`            | SMTP host for sending verification OTPs                                     |
| `Chat:EncryptionKey`           | Master key for AES-256 chat payload encryption                              |

---

## 👥 Team Responsibility & Grading Matrix

This project is divided among four team members, mapping each core business component to its corresponding agentic AI subsystem:

| Group Member | Business Component Assigned                 | AI Agent Assigned      | Primary Folders & Modules                                                                                                                                                     |
| :----------- | :------------------------------------------ | :--------------------- | :---------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Member 1** | **Service Request Management**              | **Planning Agent**     | `backend.Api/AI/Planning/`<br>`mobile_app/lib/ai/pages/planning_*`<br>`mobile_app/lib/home/pages/book_specialist*`                                                            |
| **Member 2** | **Service Provider Management**             | **Matching Agent**     | `backend.Api/AI/Matching/`<br>`backend.Api/Providers/`<br>`mobile_app/lib/provider/pages/provider_setup*`<br>`mobile_app/lib/ai/pages/matched_providers*`                     |
| **Member 3** | **Negotiation & Booking Management**        | **Coordination Agent** | `backend.Api/AI/Coordination/`<br>`BookingEntity.cs` & `ProposalEntity.cs`<br>`mobile_app/lib/ai/pages/quotation_proposal*`<br>`mobile_app/lib/home/pages/customer_bookings*` |
| **Member 4** | **Operations, Review & Support Management** | **Review Agent**       | `backend.Api/AI/Review/`<br>`ProofUploadController.cs`<br>`mobile_app/lib/provider/pages/job_completion_proof*`<br>`mobile_app/lib/home/pages/customer_completion_review*`    |

---

<div align="center">

**TaskBridge** — _Connecting People to the Right Skills Through Intelligent Agentic Workflows._

</div>
