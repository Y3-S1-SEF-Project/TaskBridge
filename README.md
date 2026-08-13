# TaskBridge

**AI-Powered Service Marketplace**

TaskBridge is a full-stack platform that connects customers with
suitable service providers for real-world service requests.

Customers can submit service requests, while service providers can
discover and accept suitable jobs. TaskBridge uses a multi-agent AI
workflow to analyse requests, identify suitable providers, and validate
recommendations.

## Main Features

-   Customer service requests
-   Service provider profiles and skills
-   AI-powered service analysis and provider matching
-   Provider validation
-   Customer and worker mobile experience
-   Admin/operations web dashboard
-   Job and booking management
-   Notifications and workflow automation
-   Reports and analytics

## Technology Stack

-   **Mobile:** Flutter
-   **Web:** React + TypeScript
-   **Backend:** ASP.NET Core Web API
-   **Database:** PostgreSQL
-   **Agentic AI:** LangGraph
-   **Automation:** n8n

## Agentic AI

TaskBridge uses four specialized agents:

1.  **Workflow Planner** --- creates the workflow plan.
2.  **Service Analyst** --- determines what service the customer needs.
3.  **Provider Matcher** --- finds and ranks suitable service providers.
4.  **Validator** --- validates the proposed provider and checks
    business rules.

Normal requests can proceed automatically, while high-risk or uncertain
cases can be escalated for human review.

## User Roles

### Customer

-   Create service requests
-   Upload photos and provide location/details
-   View AI recommendations
-   Accept or decline providers
-   Track jobs
-   Communicate with providers
-   Rate completed services

### Service Provider

-   Manage profile and skills
-   Set availability
-   View and accept jobs
-   Update job status
-   Communicate with customers
-   Complete assigned services

### Admin / Operations

-   Manage customers and providers
-   Monitor requests and active jobs
-   Monitor AI workflows
-   Handle exceptional cases
-   View conversations
-   Generate reports
-   View platform analytics

## Project Structure

``` text
TaskBridge/
├── backend/        # ASP.NET Core API
├── frontend-web/   # React Web Application
└── mobile/         # Flutter Mobile Application
```

## Project Goal

To provide an intelligent and scalable platform that makes it easier for
customers to find suitable service providers while reducing manual
effort through Agentic AI and workflow automation.

------------------------------------------------------------------------

**TaskBridge --- Connecting People to the Right Skills.**
