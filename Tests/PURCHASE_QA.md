# Mac Full Unlock

## App Store Connect setup (required before selling)

- Mac app: `com.Jeonster.WatchMotionEditor.mac`. Keep the app download free.
- Create a **Non-Consumable** named **WatchMotion Editor Full Unlock**.
- Product ID: `com.Jeonster.WatchMotionEditor.mac.full-unlock`.
- Set US price **$19.99**, and a separate South Korea price **₩29,000**. Do not rely on automatic currency conversion to produce the Korean price.
- Complete paid-app agreements, tax/banking details, product localization and review screenshot. Submit the first IAP with the Mac app version.
- iPhone and Watch remain free. No subscription or introductory discount is configured.

The app displays StoreKit's `Product.displayPrice`; unavailable products disable purchasing instead of showing an unverified price. This repository does not configure production store prices.

## Trial rules

One workspace, up to three distinct recordings admitted for editing, and one successful CSV **or** Create ML dataset export. Existing admitted recordings remain editable afterward. Receiving, previewing, and project backup remain available. Project labels count toward the same workspace; backing up preserves its identity. Canceling/failed/empty exports do not consume the export allowance. Partially successful exports with data do consume it.

Trial history is device-local Keychain data, not an account-level/server-enforced trial. Deleting recordings does not recover slots. A different Mac can have its own trial. A verified StoreKit entitlement, never a preferences flag, grants unlimited access.

## Local checks

Verified during implementation: unsigned Mac Debug and Release builds; trial-policy smoke test; project/archive regression test; release UI smoke test. The running Debug app opened Full Unlock from Settings, displayed unavailable product pricing with the purchase button disabled, and closed with Not Now. Purchase/restore/refund transactions have **not** been exercised yet.

Run `bash Tests/run-editor-trial-smoke.sh` and `bash Tests/run-project-settings-smoke.sh`.

For StoreKit integration testing, open `Configuration/WatchMotionEditor.storekit` in Xcode and select it under a **local duplicate** of the Mac scheme → Run → Options → StoreKit Configuration. The shared release scheme intentionally has no local StoreKit override. Local test transactions do not charge money. The fixture uses US pricing; verify Korea pricing against the actual sandbox storefront after Connect setup.

Before release, run these scenarios in Xcode Transaction Manager and again in sandbox/TestFlight:

- Product loading: US and Korean localized price; offline/unavailable price disables purchase, retry recovers.
- Successful purchase: unlimited editing/export; close/reopen app retains entitlement, including offline.
- Cancel: no unlock or error presented as success. Pending/Ask to Buy: no unlock until approval arrives.
- Restore on another Mac: verified purchase restores; no purchase and network failure show distinct messages.
- Refund/revoke: entitlement removed on transaction update or next launch; original trial limits apply again.
- Fourth recording and second workspace: preview remains available, editing opens Full Unlock.
- CSV and Create ML share one free export; cancel/error leave allowance intact; successful export consumes it across relaunch.
- Open project/detail/settings windows: purchase opens from each, and entitlement refreshes already-open views.

Actual App Store purchases, sandbox approval/refund flows and regional prices require the external configuration above; a successful build/policy test does not certify them.

References: [Apple StoreKit testing setup](https://developer.apple.com/documentation/xcode/setting-up-storekit-testing-in-xcode/), [Apple Product](https://developer.apple.com/documentation/storekit/product).
