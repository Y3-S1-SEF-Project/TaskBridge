-- Run this script in the TaskBridge database using pgAdmin's Query Tool.
BEGIN;

-- Drop old multi-table auth structure if present
DROP TABLE IF EXISTS auth_sessions CASCADE;
DROP TABLE IF EXISTS auth_challenges CASCADE;
DROP TABLE IF EXISTS auth_users CASCADE;

-- Single unified Users table
CREATE TABLE IF NOT EXISTS users (
    "Id" uuid PRIMARY KEY,
    "FullName" varchar(100) NOT NULL,
    "Email" varchar(255) NOT NULL UNIQUE,
    "Phone" varchar(24) NOT NULL,
    "PasswordHash" text NOT NULL,
    "Address" text NULL,
    "Location" text NULL,
    "Preferences" text NULL,
    "ProfilePhotoUrl" text NULL,
    "EmailOtp" varchar(10) NULL,
    "EmailOtpExpiresAt" timestamptz NULL,
    "IsEmailVerified" boolean NOT NULL DEFAULT false,
    "SessionToken" text NULL,
    "FailedLogins" integer NOT NULL DEFAULT 0,
    "LockedUntil" timestamptz NULL,
    "CreatedAt" timestamptz NOT NULL DEFAULT now(),
    "UpdatedAt" timestamptz NULL
);

CREATE UNIQUE INDEX IF NOT EXISTS ix_users_email ON users ("Email");
CREATE INDEX IF NOT EXISTS ix_users_phone ON users ("Phone");
CREATE INDEX IF NOT EXISTS ix_users_session_token ON users ("SessionToken");

COMMIT;

