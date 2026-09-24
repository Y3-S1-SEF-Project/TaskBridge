# TaskBridge authentication

Implemented for the existing .NET 10 API and Flutter application. The API uses PostgreSQL through Npgsql EF Core, ASP.NET's password hasher, database-backed OTP challenges, and revocable opaque bearer sessions. Users have one account; registration does not assign a permanent customer/provider role.

## Local configuration

`appsettings.Local.json` is ignored by Git, has owner-only filesystem permissions, and is loaded only in Development. It contains the supplied Notify user ID/API key and a generated OTP signing key. Do not copy it into Flutter or commit it. Rotate the Notify API key shared in chat, then replace it locally.

Complete these two settings before live delivery:

- `ConnectionStrings:TaskBridge`: actual PostgreSQL host, port, database, username, and password.
- `Notify:SenderId`: your exact **approved** sender ID. It is intentionally blank; `NotifyDEMO` is rejected for OTP delivery.

Notify.lk's documented endpoint sends **SMS**, not email. `contact_email` is contact metadata, not an email recipient. An email provider and email-based account flow would be a separate integration. Reference: https://developer.notify.lk/api-endpoints/

pgAdmin is a client for managing PostgreSQL. In pgAdmin, connect to a PostgreSQL server, create a database named `taskbridge` (or your chosen name), select it, and run `Database/001_auth.sql` in Query Tool. The API does not automatically create databases or apply schema at startup.

Production uses environment variables such as `ConnectionStrings__TaskBridge`, `Notify__UserId`, `Notify__ApiKey`, `Notify__SenderId`, and `Auth__OtpSigningKey`. Keep the signing key stable and secret (at least 32 characters). Use HTTPS and configure trusted proxy forwarding explicitly if deploying behind a proxy; do not trust arbitrary forwarded IP headers.

## Flutter entry and API address

`mobile_app/lib/main.dart` opens `lib/auth/pages/splash_page.dart`. The existing `lib/main_showcase.dart` remains available.

- Android emulator debug default: `http://10.0.2.2:5298`.
- iOS simulator/macOS debug default: `http://localhost:5298`.
- Physical devices: pass `--dart-define=TASKBRIDGE_API_URL=https://YOUR-REACHABLE-API` and use a trusted certificate.
- Release requires an explicit HTTPS URL. Never disable certificate validation.

The backend's existing `http` launch profile uses port 5298. HTTP is allowed only as a local development convenience; production redirects to HTTPS. Flutter Android permits cleartext only in its debug manifest. iOS/macOS allow local networking; secure storage uses platform keychains. Physical Apple devices require normal Xcode signing configuration.

Dependencies have been **declared**, not installed by Codex: Flutter `http`, `flutter_secure_storage`; ASP.NET `Npgsql.EntityFrameworkCore.PostgreSQL`. The prior no-install/no-build/no-analysis instruction was retained. No live SMS has been sent, no schema applied, and runtime behavior has not been verified.

## API contract

| Method / path                    | Body / behavior                                            |
| -------------------------------- | ---------------------------------------------------------- |
| POST `/api/auth/register`        | `fullName`, `phone`, `password` → OTP challenge            |
| POST `/api/auth/login`           | `phone`, `password` → login OTP challenge                  |
| POST `/api/auth/forgot-password` | `phone` → recovery challenge                               |
| POST `/api/auth/verify-otp`      | `challengeId`, `code` → session or reset-only token        |
| POST `/api/auth/resend-otp`      | `challengeId` → replacement code and cooldown              |
| POST `/api/auth/reset-password`  | `challengeId`, `resetToken`, `password` → password changed |
| GET `/api/auth/me`               | Bearer access token → account details                      |
| POST `/api/auth/logout`          | Bearer access token → current session revoked              |

All challenges return `challengeId`, `maskedPhone`, `purpose`, `expiresAt`, `resendAt`, and a generic eligibility message. Verification returns either `session: {accessToken, expiresAt, user}` or `resetToken`. A reset token is never accepted as a bearer session. Passwords, OTPs, credentials, and tokens must not be logged by request-body middleware.

## Security behavior

- Six-digit cryptographically random codes; HMAC hashes bound to challenge and purpose.
- Five-minute OTP expiry, 60-second resend cooldown, five total verification attempts per challenge, at most three sends per challenge, five sends per phone per hour across purposes.
- Forty auth requests per IP per ten minutes; five wrong passwords lock login for fifteen minutes.
- PostgreSQL advisory transaction locks serialize account mutations, including concurrent OTP redemption and password reset.
- Registration creates the account only after OTP verification. Actual prices, roles, and marketplace operations are outside this auth slice.
- Reset grants expire in ten minutes and are single-use. Password reset invalidates every session and outstanding challenge for that account.
- Session tokens expire in twelve hours; Flutter saves only the bearer token in secure storage. Network failures on startup preserve the saved session and offer retry.
- Notify credentials are sent in an HTTPS POST body to the fixed official endpoint. Delivery errors are sanitized and failed delivery challenges cannot be verified.
- Periodically purge expired sessions and old consumed/expired challenges, retaining at least the one-hour rate-limit window. For example, remove challenges older than one day and sessions whose expiry is past.

## Verification before release

Source tests are included but not executed. Backend tests live in `Tests/TaskBridge.Auth.Tests.csproj`; the integration test requires `TASKBRIDGE_TEST_POSTGRES` pointing to a dedicated database whose name ends in `_test`. It applies the auth schema and cleans up only its own generated account. Its fake SMS sender never calls Notify.lk. Flutter tests live in `mobile_app/test/widget_test.dart`. Test against a dedicated PostgreSQL database and approved sender using a phone you control. Verify registration, duplicate-number privacy, wrong/expired OTP, resend cooldown and old-code invalidation, password-plus-OTP login, recovery, wrong/reused reset token, logout, revoked-session rejection, and simultaneous OTP redemption. Confirm physical-device API connectivity and secure storage persistence.

The signed-in page is an authentication handoff with account information and logout, ready for the later marketplace home screen.
