# 🔐 JWT Authentication Implementation Guide
## Aletheia Platform - Deterministic Auth Flow

---

## Overview

This implementation solves the redirect loop issue by:

1. **Single Source of Truth** - AuthContext manages all auth state
2. **Synchronized Initialization** - Token read happens before any auth requests  
3. **Comprehensive Logging** - Every auth step is logged to console
4. **Clean 401 Handling** - Unauthorized responses trigger logout, not loops

---

## Architecture

### AuthContext (`src/context/AuthContext.jsx`)

**Provides:**
- `token` - JWT access token
- `corporateId` - Institution user ID
- `userProfile` - User data from `/auth/profile`
- `isApproved` - Account approval status
- `isInitialized` - App startup complete
- `isAuthenticated` - User is logged in (token exists)

**Actions:**
- `setToken(token, corporateId)` - Save token (called by LoginPage)
- `logout()` - Clear all auth state
- `fetchProfile()` - Load user profile from backend
- `logAuthEvent(action, details)` - Log auth action

### Authentication Flow

```
1. App mounts → AuthProvider initializes
   └─ Reads localStorage for existing token
   └─ Sets isInitialized = true (gates all other logic)

2. User on LoginPage submits credentials
   └─ logs: LOGIN-ATTEMPT
   └─ Backend returns: { access_token, corporate_id, ...}
   └─ LoginPage calls: auth.setToken(token, corporateId)
   
3. auth.setToken() executes
   └─ Saves to localStorage (persistent)
   └─ Updates React state (immediate)
   └─ logs: TOKEN-SET, TOKEN-SAVED-LOCAL, TOKEN-SAVED-STATE

4. App.jsx receives isAuthenticated = true
   └─ Skips LoginPage rendering (Gate 1)
   └─ useEffect triggers → fetchProfile()

5. fetchProfile() → GET /auth/profile with Bearer token
   └─ logs: FETCH-PROFILE-START
   └─ If 401: logs FETCH-PROFILE-401 → calls logout()
   └─ If success: saves profile, sets isApproved

6. App renders main UI (Engine, Vault, etc.)
   └─ User can now interact with app
   └─ All subsequent API calls include Bearer token
```

---

## Console Logging Reference

Every auth event logs with `[🔐 AUTH-ACTION]` prefix.

### Login Flow
```javascript
[🔐 AUTH-LOGIN-ATTEMPT] {
  endpoint: "/auth/login",
  username: "admin"
}

[🔐 AUTH-LOGIN-RESPONSE] {
  endpoint: "/auth/login",
  status: 200,
  hasToken: true
}

[🔐 AUTH-LOGIN-SUCCESS] {
  username: "admin",
  corporateId: "admin",
  isApproved: true
}

[🔐 AUTH-TOKEN-SET] {
  token: "eyJhbGciOi...",
  corporateId: "admin",
  message: "Saving token to localStorage and auth state"
}

[🔐 AUTH-TOKEN-SAVED-LOCAL] {
  message: "Token persisted to localStorage"
}

[🔐 AUTH-TOKEN-SAVED-STATE] {
  message: "Auth state synchronized"
}

[🔐 AUTH-FETCH-PROFILE-START] {
  token: "eyJhbGciOi..."
}

[🔐 AUTH-FETCH-PROFILE-SUCCESS] {
  username: "admin",
  institution: "Aletheia Global",
  isApproved: true
}
```

### 401 Unauthorized (Expired Token)
```javascript
[🔐 AUTH-FETCH-PROFILE-401] {
  message: "Unauthorized - token invalid or expired"
}

[🔐 AUTH-LOGOUT] {
  message: "Clearing session and localStorage"
}

[🔐 AUTH-LOGOUT-COMPLETE] {
  message: "Session cleared"
}

// Browser redirects to / → shows LoginPage
```

### API Request/Response Logging
```javascript
[🔐 API-REQUEST] GET /auth/profile {
  hasToken: true,
  tokenPrefix: "eyJhbGciOi..."
}

[🔐 API-RESPONSE] GET /auth/profile → 200

[🔐 API-401] Unauthorized response from /auth/profile
[🔐 API-401] Clearing authentication tokens...
[🔐 API-401] Auth cleared - will redirect to login
```

---

## Testing Checklist

### ✅ Test 1: Fresh Login
1. Clear localStorage: `localStorage.clear()`
2. Refresh the page
3. You should see LoginPage
4. Open DevTools Console
5. Enter credentials and submit
6. Verify logs show entire flow
7. ✅ Should see HomePage (not LoginPage)

**Expected Console Output:**
```
[🔐 AUTH-INIT-START]
[🔐 AUTH-TOKEN-MISSING]
[🔐 AUTH-LOGIN-ATTEMPT]
[🔐 AUTH-LOGIN-RESPONSE] status: 200
[🔐 AUTH-LOGIN-SUCCESS]
[🔐 AUTH-TOKEN-SET]
[🔐 AUTH-TOKEN-SAVED-LOCAL]
[🔐 AUTH-TOKEN-SAVED-STATE]
[🔐 AUTH-FETCH-PROFILE-START]
[🔐 API-REQUEST] GET /auth/profile
[🔐 API-RESPONSE] GET /auth/profile → 200
[🔐 AUTH-FETCH-PROFILE-SUCCESS]
```

**In localStorage after login:**
```javascript
localStorage.getItem('alethia_token')    // JWT string
localStorage.getItem('corporate_id')     // "admin"
```

---

### ✅ Test 2: Page Refresh with Valid Token
1. Login successfully
2. Refresh the page (F5)
3. Open DevTools Console
4. ✅ Should NOT see LoginPage
5. Should see HomePage immediately

**Expected Console Output:**
```
[🔐 AUTH-INIT-START]
[🔐 AUTH-TOKEN-FOUND] token: "eyJhbGciOi...", corporateId: "admin"
[🔐 APP-INIT] Auth state changed: 
  { isInitialized: true, isAuthenticated: true, hasProfile: false }
[🔐 APP-TRIGGER] Fetching profile...
[🔐 AUTH-FETCH-PROFILE-START]
[🔐 API-REQUEST] GET /auth/profile
[🔐 API-RESPONSE] GET /auth/profile → 200
[🔐 AUTH-FETCH-PROFILE-SUCCESS]
```

---

### ✅ Test 3: Expired Token (401 Response)
1. Login successfully
2. Go to your browser's Application tab
3. Manually delete the token in localStorage
   - OR: Manually corrupt it with a few random chars at the end
4. Try to navigate somewhere that triggers API call
5. ✅ Should see 401 error in console
6. ✅ Should be redirected to LoginPage

**Expected Console Output:**
```
[🔐 API-REQUEST] GET /...
[🔐 API-RESPONSE] GET /... → 401
[🔐 API-401] Unauthorized response from /...
[🔐 API-401] Clearing authentication tokens...
[🔐 AUTH-LOGOUT] message: "Clearing session and localStorage"
[🔐 AUTH-LOGOUT-COMPLETE] message: "Session cleared"
[🔐 API-401] Auth cleared - will redirect to login
```

---

### ✅ Test 4: Manual Logout
1. While logged in, navigate to any page
2. Click the "Logout" button (in TopNav)
3. ✅ Should immediately show LoginPage
4. localStorage should be empty

**Expected Console Output:**
```
[🔐 AUTH-LOGOUT] message: "Clearing session and localStorage"
[🔐 AUTH-LOGOUT-COMPLETE] message: "Session cleared"
```

---

### ✅ Test 5: No Redirect Loop
1. Login successfully
2. Manually set token in localStorage to an invalid JWT:  
   ```javascript
   localStorage.setItem('alethia_token', 'invalid.jwt.token')
   ```
3. Refresh the page
4. ✅ Should NOT see infinite redirect loop
5. Should see 401 log once, then redirect to LoginPage

---

## Debugging Notes

### If you see multiple 401s in a row (possible loop):
1. Check the API log timestamps
2. Ensure ProfileFetch is only called once on auth state change
3. Check that `isInitialized` is used to gate imports

### If login doesn't redirect:
1. Check localStorage was updated: `localStorage.getItem('alethia_token')`
2. Check auth context received the token: Log should show `TOKEN-SET`
3. Check App.jsx is reading from context, not old state

### If profile fetch returns 401 but doesn't logout:
1. Check API 401 handler is being called
2. Verify `window.location.href = '/'` is executing
3. Check browser console for any errors

---

## Code Changes Summary

### Files Modified:

1. **`src/context/AuthContext.jsx`** (NEW)
   - Centralized auth state management
   - Synchronized initialization
   - Comprehensive logging

2. **`src/main.jsx`**
   - Wrapped App with `<AuthProvider>`

3. **`src/App.jsx`**
   - Removed local session state
   - Uses `useAuth()` hook instead
   - Proper gate ordering: init → auth → approved → UI

4. **`src/pages/LoginPage.jsx`**
   - Removed `onLoginSuccess` callback prop
   - Calls `auth.setToken()` instead of localStorage
   - Uses `auth.logAuthEvent()` for logging

5. **`src/utils/api.js`**
   - Enhanced 401 handler with logging
   - Added request/response logging
   - Dispatches custom auth:logout event

---

## Security Notes

✅ **What's secure:**
- Token only stored in localStorage (no cookies set by frontend)
- Backend validates JWT signature on every request
- 401 immediately clears session
- No token passed in URL params
- CORS properly configured

⚠️ **What remains your responsibility:**
- Set `HttpOnly` cookies on backend if using cookies
- Implement token refresh flow if tokens expire quickly
- Use HTTPS in production (localStorage vulnerable to XSS)
- Validate token expiration time periodically
- Monitor for suspicious login patterns

---

## Troubleshooting

### "useAuth() must be used inside <AuthProvider>"
- Ensure `AuthProvider` wraps the entire app in `main.jsx`
- Check no component is importing from a separate bundle

### States not syncing between tabs
- localStorage is inherently single-machine only
- For multi-tab sync, listen to `storage` events
- Or use `window.addEventListener('storage', ...)`

### Network errors during profile fetch
- Check backend `/auth/profile` endpoint
- Verify token is in Bearer header format
- Check CORS headers from backend

---

## Next Steps

### Optional Enhancements:

1. **Token Refresh** - Implement refresh token rotation
   ```javascript
   // In AuthContext.fetchProfile():
   if (response.status === 401 && canRefreshToken) {
     await refreshToken();
     return fetchProfile(); // Retry
   }
   ```

2. **Multi-Tab Sync** - Listen for logout in other tabs
   ```javascript
   useEffect(() => {
     const handleStorageChange = (e) => {
       if (e.key === 'alethia_token' && !e.newValue) {
         logout(); // Another tab logged out
       }
     };
     window.addEventListener('storage', handleStorageChange);
   }, []);
   ```

3. **Auth State Persistence** - Save to IndexedDB
   ```javascript
   const saveAuthState = () => {
     db.auth.put({ token, profile, timestamp: Date.now() });
   };
   ```

4. **Biometric Login** - WebAuthn integration
5. **Audit Trail** - Client-side auth event tracking

---

## FAQ

**Q: Why not use cookies?**
A: Cookies are handled by browsers automatically, but this makes CSRF possible. JWT in localStorage requires explicit header management but gives more control. Choose based on your security model.

**Q: Why log every API call?**
A: Auth debugging is hard. Logging makes it easy to trace the exact point failures occur, reducing debug time from hours to minutes.

**Q: Can I use this with a different backend?**
A: Yes, this pattern works with any backend that returns JWT and validates Bearer headers. Just adjust `/auth/login` response format in `LoginPage.jsx`.

**Q: What if user has multiple browser tabs?**
A: Each tab has its own React instance, so they don't share state naturally. Implement `storage` event listener to sync logout across tabs.

---

Generated: 2026-02-06
Version: 2.0.0 (Deterministic Auth Flow)
