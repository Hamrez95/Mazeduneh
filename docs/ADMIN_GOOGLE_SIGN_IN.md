# Google sign-in for the admin panel

The admin panel supports Google sign-in in addition to email and password. The API validates Google's signed ID token and a short-lived, single-use nonce before creating the same server-backed admin session used by password login.

## Access rules

- The configured store owner can sign in with Google only when the verified Google email exactly matches the owner's configured email.
- An existing active staff account can connect Google after confirming its current password. Existing permissions and multi-factor authentication remain in effect.
- New staff accounts can be created only by accepting a valid admin invitation with the invited Google email, or by setting a password on that invitation.
- There is no public admin self-registration.

## Configure local development

1. Create an OAuth 2.0 **Web application** client in Google Cloud Console and enable Google Identity Services for it. Do not create a client secret for this browser flow.
2. Add the admin panel's browser origin under **Authorized JavaScript origins**. With the default local launcher this is usually `http://127.0.0.1:8080` and/or `http://localhost:8080`. If the launcher chooses another port, add that exact origin too.
3. Set `MAZEDUNEH_GOOGLE_CLIENT_ID` in the PowerShell session before starting the local stack. The value is a public client ID, not a secret:

   ```powershell
   $env:MAZEDUNEH_GOOGLE_CLIENT_ID = 'your-web-client-id.apps.googleusercontent.com'
   .\scripts\local.ps1
   ```

   The launcher passes it to the API as `Google:ClientId`. The ID token is verified by the API; it is never trusted just because the browser received it.
4. If no client ID is configured, the Google button stays inactive and email/password sign-in continues to work.

The same environment variable is read by `scripts/dev.ps1`. Production deployments must provide `Google__ClientId` through the server's secret/configuration manager and register the actual admin web origin with Google. No Google credential or client secret belongs in Git.
