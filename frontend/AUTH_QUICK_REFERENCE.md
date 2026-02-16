# 🚀 JWT Auth Quick Reference
## Copy-paste debugging & common tasks

---

## Console Debugging

### View all auth events
```javascript
// In browser console, auth events log automatically
// Look for logs starting with [🔐 AUTH-
// View filter: Ctrl+Shift+K → type "AUTH" → Enter
```

### Check current auth state
```javascript
// In browser console:
localStorage.getItem('alethia_token')    // JWT token or null
localStorage.getItem('corporate_id')     // User ID or null

// In React component:
const auth = useAuth();
console.log(auth.isAuthenticated, auth.token, auth.userProfile);
```

### Manually test token expiration
```javascript
// Corrupt token to trigger 401:
const badToken = localStorage.getItem('alethia_token') + 'xxx';
localStorage.setItem('alethia_token', badToken);
// Refresh page - should logout and show LoginPage

// Clear all auth:
localStorage.removeItem('alethia_token');
localStorage.removeItem('corporate_id');
// Refresh page - shows LoginPage
```

---

## Common Issues & Fixes

### Issue: Still seeing LoginPage after login
**Check:**
```javascript
// 1. Token saved?
localStorage.getItem('alethia_token') // should not be null

// 2. Look for this log:
// [🔐 AUTH-TOKEN-SET] ✅
// [🔐 AUTH-LOGIN-SUCCESS] ✅

// 3. Check App.jsx is reading from useAuth()
// NOT from old state
```

**Fix:**
- Hard refresh: Ctrl+Shift+R
- Clear localStorage and try login again
- Check backend is returning `access_token` (not `token`)

---

### Issue: Infinite redirect loop
**This should NOT happen anymore.** If you see it:
```javascript
// Check console for repeated 401 logs
// Look at timestamps - if multiple happen at once, it's a loop

// Check isInitialized gate is in App.jsx:
// if (!auth.isInitialized) return <LoadingScreen />
```

**Fix:**
- Verify AuthProvider wraps App in main.jsx
- Verify App.jsx has the initialization gate
- Clear cache: Hard refresh (Ctrl+Shift+R)

---

### Issue: 401 but no logout
**Check console:**
```javascript
// Should see: [🔐 API-401] Unauthorized response from /...
// Should see: [🔐 AUTH-LOGOUT]

// If not appearing:
// 1. Check api.js handle401() is being called
// 2. Verify endpoint is being hit
```

**Fix:**
- Restart dev server
- Verify api.js was updated correctly
- Check no other API helpers are bypassing handle401

---

## How to Add Logging to New API Calls

### In components, use the api helper (auto-logs):
```javascript
import { api } from '../utils/api';

// This will auto-log request & response:
const response = await api.get('/some/endpoint');
const data = await response.json();
```

### Or manually in fetch calls:
```javascript
const auth = useAuth();

auth.logAuthEvent('MY-ACTION-START', { data: 'something' });
const response = await fetch(...);
auth.logAuthEvent('MY-ACTION-RESPONSE', { status: response.status });
```

---

## How to Access Auth in Any Component

### Option 1: Use the useAuth hook (functions only)
```javascript
import { useAuth } from '../context/AuthContext';

function MyComponent() {
  const auth = useAuth();
  
  return <div>{auth.isAuthenticated ? 'Logged in' : 'Not logged in'}</div>;
}
```

### Option 2: Read directly from context
```javascript
import { AuthContext } from '../context/AuthContext';

<AuthContext.Consumer>
  {(auth) => <div>{auth.token}</div>}
</AuthContext.Consumer>
```

### Option 3: Wrap with AuthContext
```javascript
import { useAuth, AuthContext } from '../context/AuthContext';

function MyComponent() {
  return (
    <AuthContext.Consumer>
      {(auth) => <YourUI auth={auth} />}
    </AuthContext.Consumer>
  );
}
```

---

## Token Structure

### Payload (decode at jwt.io):
```json
{
  "sub": "admin",          // Subject = username
  "iat": 1707266000,       // Issued at
  "exp": 1707352400        // Expires at
}
```

### Response from login:
```json
{
  "access_token": "eyJhbGciOi...",
  "token_type": "bearer",
  "is_approved": true,
  "corporate_id": "admin"
}
```

### Usage in headers:
```
Authorization: Bearer eyJhbGciOi...
```

---

## Testing Checklist (Copy-paste into DevTools)

### Step 1: Clear and login
```javascript
localStorage.clear();
location.href = '/';
// Then login via UI
```

### Step 2: Verify token saved
```javascript
console.log('Token:', localStorage.getItem('alethia_token'));
console.log('Corp ID:', localStorage.getItem('corporate_id'));
```

### Step 3: Test refresh
```javascript
location.reload();
// Should not show LoginPage
```

### Step 4: Test logout via 401
```javascript
// Corrupt token:
localStorage.setItem('alethia_token', 'invalid');
location.reload();
// Should show LoginPage, no loop
```

### Step 5: Check logs
```javascript
// Filter console to "AUTH" - should see the flow
console.log('Events:', [
  'AUTH-INIT-START',
  'AUTH-TOKEN-SET',
  'AUTH-FETCH-PROFILE-START',
  'AUTH-FETCH-PROFILE-SUCCESS'
]);
```

---

## Environment Variables (if needed)

### In `.env`:
```
VITE_API_BASE=http://localhost:8001
```

### Backend should provide:
```
JWT_SECRET_KEY=your-secret
JWT_ALGORITHM=HS256
JWT_TOKEN_LIFETIME_HOURS=24
```

---

## File Locations

| What | Where |
|------|-------|
| Auth context | `src/context/AuthContext.jsx` |
| API helpers | `src/utils/api.js` |
| Login page | `src/pages/LoginPage.jsx` |
| App wrapper | `src/App.jsx` |
| Setup guide | `AuthProvider` in `src/main.jsx` |
| Full docs | `frontend/AUTH_IMPLEMENTATION.md` |

---

## Quick Commands

### Kill dev server & restart
```bash
# Terminal
Ctrl+C
npm run dev
```

### Check for JS errors
```javascript
// Browser console
// Look for red error boxes
// Filter: "Error"
```

### Reset auth state without code
```javascript
// Browser console
localStorage.clear();
location.href = '/';
```

### Monitor all localStorage changes
```javascript
window.addEventListener('storage', (e) => {
  console.log('🔐 Storage changed:', e.key, '=', e.newValue);
});
```

---

## One-Line Diagnostics

### Is auth initialized?
```javascript
// Should be true after page load
JSON.parse(sessionStorage.getItem('AUTH_INIT') || 'false')
```

### Is user authenticated?
```javascript
// Should be truthy if logged in
!!localStorage.getItem('alethia_token')
```

### What's the approval status?
```javascript
// Check component state or backend /auth/profile
fetch('http://localhost:8001/auth/profile', {
  headers: { Authorization: `Bearer ${localStorage.getItem('alethia_token')}` }
}).then(r => r.json()).then(g => console.log('Approved:', g.is_approved))
```

---

## Getting Help

**If stuck:**
1. Check browser console for [🔐 errors
2. Check backend response: F12 → Network tab → click request
3. Verify token format: paste token at jwt.io
4. Read AUTH_IMPLEMENTATION.md Testing Checklist section
5. Restart: Close browser, clear cache, restart dev server

---

Version: 2.0.0 | Last Updated: 2026-02-06
