# Server-Side SSO Configuration for Rayka

This document explains what needs to be configured on the homeserver (`core.zino-co.com`) to make SSO work properly with the Flutter app.

## Current Issue

The homeserver is redirecting to its own OIDC callback endpoint instead of back to the Flutter app. This needs to be fixed in the server configuration.

## Required Synapse Configuration

Add the following configuration to your `homeserver.yaml`:

```yaml
# OIDC Provider Configuration
oidc_providers:
  - idp_id: keycloak
    idp_name: "Keycloak SSO"
    issuer: "https://guardsi.zino-co.com/realms/sahab"
    client_id: "chatsi"
    client_secret: "your-client-secret-here"
    scopes: ["openid", "profile", "email"]
    user_mapping_provider:
      config:
        subject_claim: "sub"
        localpart_template: "{{ user.preferred_username }}"
        display_name_template: "{{ user.name }}"
        email_template: "{{ user.email }}"

# SSO Configuration - CRITICAL FOR FLUTTER APP
sso:
  client_whitelist:
    # Flutter app deep link URLs
    - "im.fluffychat://login"
    - "im.fluffychat://"
    # Web fallback URLs
    - "http://localhost:3001//login"
    - "http://localhost:3001/"
    # Add your web domain if applicable
    - "https://your-web-domain.com/auth.html"
    - "https://your-web-domain.com/"

# Optional: Disable password login if you want SSO only
# enable_registration: false
# password_config:
#   enabled: false
```

## Keycloak Configuration

In your Keycloak realm (`sahab`), ensure the client `chatsi` has:

1. **Valid Redirect URIs**:
   ```
   https://core.zino-co.com/_synapse/client/oidc/callback
   im.fluffychat://login
   im.fluffychat://
   http://localhost:3001//login
   http://localhost:3001/
   ```

2. **Client Protocol**: `openid-connect`

3. **Access Type**: `confidential`

4. **Standard Flow Enabled**: `ON`

5. **Direct Access Grants Enabled**: `OFF`

## Flow Explanation

### Current (Broken) Flow:
1. Flutter App → `https://core.zino-co.com/_matrix/client/v3/login/sso/redirect?redirectUrl=im.fluffychat://login`
2. Homeserver → `https://guardsi.zino-co.com/realms/sahab/protocol/openid-connect/auth?...&redirect_uri=https://core.zino-co.com/_synapse/client/oidc/callback`
3. Keycloak → User authenticates
4. Keycloak → `https://core.zino-co.com/_synapse/client/oidc/callback` (with auth code)
5. Homeserver → Processes OIDC callback
6. **PROBLEM**: Homeserver doesn't redirect back to Flutter app

### Fixed Flow:
1. Flutter App → `https://core.zino-co.com/_matrix/client/v3/login/sso/redirect?redirectUrl=im.fluffychat://login`
2. Homeserver → `https://guardsi.zino-co.com/realms/sahab/protocol/openid-connect/auth?...&redirect_uri=https://core.zino-co.com/_synapse/client/oidc/callback`
3. Keycloak → User authenticates
4. Keycloak → `https://core.zino-co.com/_synapse/client/oidc/callback` (with auth code)
5. Homeserver → Processes OIDC callback
6. **FIXED**: Homeserver redirects to `im.fluffychat://login?loginToken=abc123`
7. Flutter App → Receives loginToken and completes login

## Testing the Configuration

After updating the server configuration:

1. **Restart Synapse**:
   ```bash
   sudo systemctl restart matrix-synapse
   ```

2. **Check Synapse logs**:
   ```bash
   sudo journalctl -u matrix-synapse -f
   ```

3. **Test the SSO flow** in the Flutter app

## Debug Information

The Flutter app now includes debug logging. Check the console output for:
- SSO Redirect URL
- Expected callback URL
- Authentication result
- Login token presence

## Common Issues

1. **"No login token received"**: Server not configured to redirect back to app
2. **"SSO login failed"**: Check server logs for OIDC errors
3. **Redirect loop**: Incorrect redirect URLs in configuration

## Verification Commands

Test the SSO endpoint directly:
```bash
curl "https://core.zino-co.com/_matrix/client/v3/login/sso/redirect?redirectUrl=im.fluffychat://login"
```

This should redirect to Keycloak, not return an error. 