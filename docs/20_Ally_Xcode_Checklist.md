# 20. Ally approvals: Xcode checklist (2.4, step 2)

Do these once, on the **Pawl** app target only. Never on PawlShield, PawlShieldAction or
PawlMonitor: the extensions get no iCloud and no network.

Project navigator, click the blue Pawl project, pick the Pawl target.

## Signing & Capabilities tab

1. Find the **iCloud** box that is already there (it has Key-value storage ticked).
   - Tick **CloudKit**.
   - Under **Containers**, press **+** and type exactly: `iCloud.io.github.jasonepage.PawlAlly`
   - Make sure its checkbox is ticked. Leave Key-value storage ticked.
2. Press **+ Capability** (top left), add **Push Notifications**. There is nothing to fill in.
3. Press **+ Capability**, add **Background Modes**. Tick **Remote notifications** only.

## Info tab

4. Under Custom iOS Target Properties, hover a row and press **+**. Key: `CKSharingSupported`.
   Type: Boolean. Value: YES.

## Then

5. Build to the phone once (Command R). The first run creates the container in your developer
   account. Signing errors here usually mean the container name was typed differently.
6. Later, before the App Store build: CloudKit Dashboard (icloud.developer.apple.com), pick
   the container, **Deploy Schema Changes** to Production. Development data never moves over,
   and that is fine; there is nothing to keep.

## What the entitlements file should end up with

`com.apple.developer.icloud-container-identifiers` lists the container,
`com.apple.developer.icloud-services` has `CloudKit`, and `aps-environment` is `development`
(Xcode switches it to production when you archive).
