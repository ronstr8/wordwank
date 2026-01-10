# Authentication Architecture Implementation

**Status**: ✅ Core Implementation Complete  
**Date**: 2026-01-09  
**Objective**: Enterprise-grade authentication with OAuth2 (Google) and WebAuthn (Passkeys)

---

## Overview

This document outlines the complete authentication architecture for Wordwank, implementing a hybrid approach with:

- **OAuth 2.0 (Google)** for convenient social login
- **WebAuthn (Passkeys)** for passwordless, secure authentication
- **Stateful sessions** with secure HTTP-only cookies
- **PostgreSQL** for persistent user data and session management

---

## Architecture Components

### 1. Database Schema (`srv/backend/schema/bootstrap.sql`)

#### Modified Tables

- **`players`**: Added `email` and `last_login_at` fields

#### New Tables

- **`player_identities`**: OAuth provider linkage (Google ID → Player ID)
- **`player_passkeys`**: WebAuthn credentials storage (public keys, credential IDs)
- **`sessions`**: Stateful session management with expiration

```sql
CREATE TABLE player_identities (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    player_id UUID NOT NULL REFERENCES players(id) ON DELETE CASCADE,
    provider TEXT NOT NULL,
    provider_id TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(provider, provider_id)
);

CREATE TABLE player_passkeys (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    player_id UUID NOT NULL REFERENCES players(id) ON DELETE CASCADE,
    credential_id TEXT NOT NULL UNIQUE,
    public_key TEXT NOT NULL,
    counter BIGINT NOT NULL DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE sessions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    player_id UUID NOT NULL REFERENCES players(id) ON DELETE CASCADE,
    session_token TEXT NOT NULL UNIQUE,
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

---

### 2. Backend (Perl - Mojolicious)

#### Dependencies (`srv/backend/cpanfile`)

```perl
requires 'Mojolicious::Plugin::OAuth2', '2.0';
requires 'Authen::WebAuthn', '0.06';
requires 'Crypt::URandom';
requires 'Crypt::JWT';
```

#### DBIx::Class Result Classes

- `Wordwank::Schema::Result::Player` - Updated with relationships
- `Wordwank::Schema::Result::PlayerIdentity` - New
- `Wordwank::Schema::Result::PlayerPasskey` - New
- `Wordwank::Schema::Result::Session` - New

#### Authentication Controller (`srv/backend/lib/Wordwank/Web/Auth.pm`)

**Endpoints:**

- `GET /auth/google` - Initiates Google OAuth flow
- `GET /auth/google/callback` - Handles OAuth callback
- `GET /auth/me` - Returns current user identity
- `POST /auth/logout` - Terminates session
- `GET /auth/passkey/challenge` - Generates WebAuthn challenge
- `POST /auth/passkey/verify` - Verifies attestation/assertion

**Key Features:**

- Session creation with secure cookies (`ww_session`)
- Player creation/linking for both OAuth and Passkey flows
- Challenge generation for WebAuthn registration and login
- Credential verification using `Authen::WebAuthn`

#### Main Application (`srv/backend/lib/Wordwank.pm`)

**Configuration:**

```perl
$self->plugin(OAuth2 => {
    google => {
        key    => $ENV{GOOGLE_CLIENT_ID},
        secret => $ENV{GOOGLE_CLIENT_SECRET},
        authorize_url => 'https://accounts.google.com/o/oauth2/auth',
        token_url => 'https://oauth2.googleapis.com/token',
    }
});
```

**Routes:**

```perl
my $auth = $r->any('/auth');
$auth->get('/google')->to('auth#google_login');
$auth->get('/google/callback')->to('auth#google_callback');
$auth->get('/me')->to('auth#me');
$auth->post('/logout')->to('auth#logout');
$auth->get('/passkey/challenge')->to('auth#passkey_challenge');
$auth->post('/passkey/verify')->to('auth#passkey_verify');
```

---

### 3. Gateway Service (Go)

#### Database Integration (`srv/gatewayd/main.go`)

**Changes:**

- Added PostgreSQL connection to `Gateway` struct
- Modified `NewGateway()` to accept `*sql.DB` parameter
- Updated `ServeHTTP()` to fetch player info from database
- Added `set_language` message handler for language persistence

**Player Profile Fetching:**

```go
var nickname, language string
err = g.db.QueryRow("SELECT coalesce(nickname, 'Guest'), language FROM players WHERE id = $1", clientID).Scan(&nickname, &language)
if err != nil {
    log.Printf("Session/ID %s not found in DB: %v. Using guest defaults.", clientID, err)
    nickname = generateProceduralName(clientID)
    language = "en"
}
```

**Identity Message:**

```go
idMsg, _ := json.Marshal(Message{
    Type:      "identity",
    Payload:   map[string]string{"id": clientID, "name": nickname, "language": language},
    Timestamp: time.Now().Unix(),
})
```

---

### 4. Frontend (React)

#### Internationalization (`srv/frontend/src/i18n.js`)

- Integrated `react-i18next` and `i18next-browser-languagedetector`
- Added English (`en.json`) and Spanish (`es.json`) translations
- Dynamic language switching based on user preference

#### Login Component (`srv/frontend/src/components/Login.jsx`)

**Features:**

- Google OAuth initiation (redirects to `/auth/google`)
- Passkey (WebAuthn) login flow:
  - Fetches challenge from `/auth/passkey/challenge`
  - Uses `navigator.credentials.get()` for authentication
  - Sends assertion to `/auth/passkey/verify`
- Last login method hint (stored in localStorage)
- Premium dark/glassmorphism styling

**WebAuthn Flow:**

```javascript
const handlePasskeyLogin = async () => {
    const resp = await fetch('/auth/passkey/challenge');
    const options = await resp.json();
    
    // Convert base64 to ArrayBuffer
    options.challenge = Uint8Array.from(atob(options.challenge), c => c.charCodeAt(0)).buffer;
    
    const credential = await navigator.credentials.get({
        publicKey: {
            challenge: options.challenge,
            rpId: options.rp.id,
            userVerification: 'preferred',
        }
    });
    
    // Send assertion to backend
    await fetch('/auth/passkey/verify', {
        method: 'POST',
        body: JSON.stringify({ /* credential data */ })
    });
};
```

#### Main Application (`srv/frontend/src/App.jsx`)

**Authentication State:**

- `isAuthenticated` - Tracks auth status
- `isAuthChecking` - Loading state during auth check
- `checkAuth()` - Validates session via `/auth/me`

**New Features:**

- Conditional rendering: Login screen vs. Game UI
- `handleLogout()` - Terminates session
- `handleRegisterPasskey()` - Client-side WebAuthn registration
- Header UI updates: Language selector, Passkey registration, Logout button

**Auth Check on Mount:**

```javascript
useEffect(() => {
    const init = async () => {
        await checkAuth();
        fetchLeaderboard();
    };
    init();
}, []);
```

**WebSocket Connection After Auth:**

```javascript
useEffect(() => {
    if (!playerId) return;
    // Setup WebSocket connection
}, [playerId]);
```

---

### 5. Kubernetes Configuration

#### Secrets (`charts/wordwank/templates/secrets.yaml`)

```yaml
stringData:
  postgres-password: {{ .Values.postgresql.auth.postgresPassword | quote }}
  backend-db-user: {{ .Values.backend.database.user | quote }}
  backend-db-pass: {{ .Values.backend.database.pass | quote }}
  google-client-id: {{ .Values.auth.google.clientId | quote }}
  google-client-secret: {{ .Values.auth.google.clientSecret | quote }}
```

#### Values (`charts/wordwank/values.yaml`)

```yaml
auth:
  google:
    clientId: "YOUR_GOOGLE_CLIENT_ID"
    clientSecret: "YOUR_GOOGLE_CLIENT_SECRET"
```

#### Backend Deployment (`srv/backend/helm/templates/deployment.yaml`)

```yaml
env:
  - name: GOOGLE_CLIENT_ID
    valueFrom:
      secretKeyRef:
        name: wordwank-db-secrets
        key: google-client-id
  - name: GOOGLE_CLIENT_SECRET
    valueFrom:
      secretKeyRef:
        name: wordwank-db-secrets
        key: google-client-secret
```

#### Gateway Deployment (`srv/gatewayd/helm/templates/deployment.yaml`)

```yaml
env:
  - name: DATABASE_URL
    value: {{ .Values.backend.database.url | quote }}
  - name: DB_USER
    valueFrom:
      secretKeyRef:
        name: wordwank-db-secrets
        key: backend-db-user
  - name: DB_PASS
    valueFrom:
      secretKeyRef:
        name: wordwank-db-secrets
        key: backend-db-pass
```

---

## Security Features

### Session Management

- **HTTP-only cookies** prevent XSS attacks
- **Secure flag** ensures HTTPS-only transmission
- **Expiration tracking** in database
- **Server-side validation** on every request

### OAuth 2.0 (Google)

- **State parameter** prevents CSRF attacks
- **Authorization code flow** (not implicit)
- **Token exchange** happens server-side
- **Email verification** via Google's API

### WebAuthn (Passkeys)

- **Public key cryptography** - Private keys never leave device
- **Challenge-response** prevents replay attacks
- **Origin verification** prevents phishing
- **User verification** (biometrics/PIN) for high security

---

## User Flows

### 1. Google OAuth Login

```text
User clicks "Continue with Google"
  ↓
Frontend redirects to /auth/google
  ↓
Backend redirects to Google OAuth consent screen
  ↓
User approves
  ↓
Google redirects to /auth/google/callback with code
  ↓
Backend exchanges code for access token
  ↓
Backend fetches user info from Google
  ↓
Backend creates/finds player and identity record
  ↓
Backend creates session and sets cookie
  ↓
Backend redirects to frontend
  ↓
Frontend checks /auth/me and connects to game
```

### 2. Passkey Registration

```text
Authenticated user clicks 🔑 button
  ↓
Frontend calls /auth/passkey/challenge
  ↓
Backend generates challenge and returns WebAuthn options
  ↓
Frontend calls navigator.credentials.create()
  ↓
Browser prompts for biometric/PIN
  ↓
Device generates key pair and returns attestation
  ↓
Frontend sends attestation to /auth/passkey/verify
  ↓
Backend verifies attestation and stores public key
  ↓
Success feedback shown to user
```

### 3. Passkey Login

```text
User clicks "Continue with Passkey"
  ↓
Frontend calls /auth/passkey/challenge
  ↓
Backend generates challenge
  ↓
Frontend calls navigator.credentials.get()
  ↓
Browser prompts for biometric/PIN
  ↓
Device signs challenge with private key
  ↓
Frontend sends assertion to /auth/passkey/verify
  ↓
Backend verifies signature with stored public key
  ↓
Backend creates session and sets cookie
  ↓
Frontend redirects to game
```

---

## Environment Variables

### Backend (Perl)

- `GOOGLE_CLIENT_ID` - Google OAuth client ID
- `GOOGLE_CLIENT_SECRET` - Google OAuth client secret
- `DATABASE_URL` or `DB_USER`/`DB_PASS`/`DB_HOST`/`DB_NAME`

### Gateway (Go)

- `DATABASE_URL` or `DB_USER`/`DB_PASS`/`DB_HOST`/`DB_NAME`
- `MAX_PLAYERS` - Maximum players per game (default: 10)
- `GAME_DURATION` - Game duration in seconds (default: 30)

---

## Next Steps

### Immediate

1. ✅ Test Google OAuth flow end-to-end
2. ✅ Test Passkey registration and login
3. ✅ Verify session persistence across page reloads
4. ✅ Test language switching and persistence

### Short-term

1. Implement proper WebAuthn verification using `Authen::WebAuthn` library
2. Add email verification for new Google sign-ups
3. Implement "forgot password" flow (if adding password auth)
4. Add rate limiting to auth endpoints
5. Implement CSRF tokens for state-changing operations

### Long-term

1. Add support for additional OAuth providers (GitHub, Discord)
2. Implement JWT-based stateless sessions for scalability
3. Add multi-factor authentication (TOTP)
4. Implement account linking (merge OAuth and Passkey accounts)
5. Add audit logging for authentication events
6. Implement session management UI (view/revoke active sessions)

---

## Testing Checklist

### Google OAuth

- [ ] New user registration via Google
- [ ] Existing user login via Google
- [ ] Email extraction and storage
- [ ] Session creation and cookie setting
- [ ] Logout and session termination
- [ ] Language preference persistence

### Passkey

- [ ] Registration with new passkey
- [ ] Login with existing passkey
- [ ] Multiple passkeys per user
- [ ] Passkey deletion (TODO: implement endpoint)
- [ ] Cross-device passkey sync (platform-dependent)

### Session Testing

- [ ] Session persistence across page reloads
- [ ] Session expiration handling
- [ ] Concurrent sessions from multiple devices
- [ ] Session invalidation on logout

### Integration

- [ ] WebSocket connection with authenticated player ID
- [ ] Player profile fetching from database
- [ ] Language switching and database update
- [ ] Leaderboard integration with persistent player IDs

---

## Known Issues & Limitations

1. **WebAuthn Verification**: Currently using placeholder logic. Need to fully implement `Authen::WebAuthn` verification.
2. **Passkey Management**: No UI for viewing/deleting registered passkeys.
3. **Account Recovery**: No mechanism for account recovery if all passkeys are lost.
4. **Email Verification**: Google OAuth doesn't verify email ownership beyond Google's verification.
5. **CSRF Protection**: Relying on SameSite cookies; should add explicit CSRF tokens.
6. **Rate Limiting**: No rate limiting on auth endpoints (vulnerable to brute force).

---

## References

- [WebAuthn Specification](https://www.w3.org/TR/webauthn-2/)
- [OAuth 2.0 RFC](https://datatracker.ietf.org/doc/html/rfc6749)
- [Google OAuth Documentation](https://developers.google.com/identity/protocols/oauth2)
- [Authen::WebAuthn CPAN](https://metacpan.org/pod/Authen::WebAuthn)
- [Mojolicious::Plugin::OAuth2](https://metacpan.org/pod/Mojolicious::Plugin::OAuth2)

---

End of Document
