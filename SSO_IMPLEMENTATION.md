# SSO Implementation with Keycloak

This document explains the SSO (Single Sign-On) implementation with Keycloak for the Rayka Flutter app.

## Overview

The app now supports SSO login using Keycloak as the identity provider. Users can choose between:
1. Password login (traditional username/password)
2. Phone login (SMS-based authentication)
3. SSO login (Keycloak-based authentication)

## Configuration

### Homeserver Configuration

The app is configured to use `https://core.zino-co.com` as the default homeserver. This server should have Keycloak SSO configured with the following setup:

1. **OIDC Provider Configuration**: The homeserver should have Keycloak configured as an OIDC provider
2. **Client Registration**: A Matrix client should be registered in Keycloak
3. **Redirect URLs**: The homeserver should be configured to handle SSO redirects

### App Configuration

The app configuration is stored in `config.rayka.json`:

```json
{
  "application_name": "Rayka",
  "default_homeserver": "https://core.zino-co.com",
  "login_banner_path": "assets/rayka_login_banner.png"
}
```

## Implementation Details

### Login Flow

1. **User Selection**: User selects "SSO Login" from the dropdown
2. **SSO Redirect**: App redirects to the homeserver's SSO endpoint
3. **Keycloak Authentication**: User authenticates with Keycloak
4. **Token Exchange**: Homeserver exchanges the OIDC token for a Matrix login token
5. **App Login**: App uses the login token to authenticate with the Matrix server

### Code Structure

#### Login Controller (`lib/pages/login/login.dart`)

- Added `LoginMethod.sso` enum value
- Implemented `ssoLogin()` method that handles the SSO flow
- Uses `FlutterWebAuth2` for web authentication

#### Login View (`lib/pages/login/login_view.dart`)

- Added SSO option to the login method dropdown
- Added SSO description box when SSO is selected
- Updated login button text for SSO

#### Dependencies

The implementation uses:
- `flutter_web_auth_2`: For handling web authentication flows
- `universal_html`: For web platform support

## Usage

### For Users

1. Open the Rayka app
2. On the login screen, select "SSO Login" from the dropdown
3. Click "Login with SSO"
4. You will be redirected to your organization's Keycloak login page
5. Enter your credentials
6. You will be redirected back to the app and logged in

### For Administrators

To configure SSO on the homeserver side:

1. **Configure Keycloak**:
   - Set up a new realm for your organization
   - Create a client for the Matrix homeserver
   - Configure redirect URIs

2. **Configure Synapse**:
   - Add OIDC provider configuration to `homeserver.yaml`
   - Configure user mapping
   - Set up client whitelist for SSO

Example Synapse configuration:

```yaml
oidc_providers:
  - idp_id: keycloak
    idp_name: "Keycloak SSO"
    issuer: "https://your-keycloak-server/auth/realms/your-realm"
    client_id: "your-matrix-client-id"
    client_secret: "your-client-secret"
    scopes: ["openid", "profile", "email"]
    user_mapping_provider:
      config:
        subject_claim: "sub"
        localpart_template: "{{ user.preferred_username }}"
        display_name_template: "{{ user.name }}"
        email_template: "{{ user.email }}"
```

## Security Considerations

1. **HTTPS Only**: All communications should use HTTPS
2. **Token Validation**: The homeserver validates OIDC tokens
3. **Redirect URL Validation**: Only whitelisted redirect URLs are allowed
4. **Client Secret**: Keep client secrets secure and rotate them regularly

## Troubleshooting

### Common Issues

1. **Redirect Loop**: Check that redirect URLs are correctly configured
2. **Token Validation Errors**: Verify OIDC provider configuration
3. **User Mapping Issues**: Check user mapping templates in Synapse config

### Debug Information

Enable debug logging in the app to see detailed SSO flow information.

## Future Enhancements

1. **Multiple SSO Providers**: Support for multiple identity providers
2. **Custom Branding**: Customizable SSO login pages
3. **Advanced User Mapping**: More sophisticated user attribute mapping
4. **SSO Logout**: Implement SSO logout functionality 