# Settings and shortcut checks

- Mac Settings → Help & Privacy exposes setup, guide, support, privacy and official-site links without requiring purchase or a device connection.
- All five destinations responded with HTTP 200 without authentication on 2026-09-09. Links use HTTPS and open in the default browser; no embedded tracker or web view was added.
- Release build and project-settings regression tests passed. Added tests cover automatic shortcut allocation through 25, persistence, and invalid/duplicate shortcut validation.
- Number menus support multiple digits. Exact numbers select immediately only if no longer shortcut shares that prefix; otherwise Return confirms. Backspace edits and Escape closes. Long menus scroll instead of extending offscreen.

## Before submission

Apple guideline 5.1.1(i) also requires the privacy URL in App Store Connect; an in-app link does not fill that metadata field automatically. Use `https://watch-motion-editor-site.vercel.app/privacy` and keep it publicly available.

The website source policy now describes StoreKit purchase verification and persistent device-local Keychain trial history (workspace/recording identifiers and export count), including the distinction between deleting recordings and retaining trial history. Publish that site commit before enabling paid release. This change does not update App Store Connect.

Also verify privacy access in the separately submitted iPhone/Watch experience; this change adds the links to **Mac** Settings. This is a targeted settings check, not a guarantee of overall App Review approval.

Reference: https://developer.apple.com/app-store/review/guidelines/#data-collection-and-storage
