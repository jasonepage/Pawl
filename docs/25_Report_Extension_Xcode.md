# 25. Adding the Screen Time report extension (PawlReport) in Xcode

The files are already in `PawlReport/`. Xcode needs a target that uses them.

1. File, New, Target. Search "Device Activity Report Extension". Next.
2. Product Name: `PawlReport`. Team: yours. Language: Swift. Finish. If Xcode asks to
   activate the scheme, choose Cancel (keep the Pawl scheme).
3. Xcode creates a `PawlReport` folder with its own files. Delete the three template Swift
   files it made (`PawlReport.swift`, `TotalActivityReport.swift`, `TotalActivityView.swift`),
   Move to Trash. Keep mine: `PawlReportExtension.swift`, `PawlReportScenes.swift`,
   `WeekUsageView.swift`. If Xcode made its own `Info.plist`, keep mine (it has the same
   extension point) or either; they match.
4. PawlReport target, Signing & Capabilities: add **Family Controls**. Same team as Pawl.
   Bundle id should be `io.github.jasonepage.Pawl.PawlReport`.
5. PawlReport target, General: Minimum Deployments iOS 18.0, to match the app.
6. Pawl target, General, Frameworks, Libraries and Embedded Content: `PawlReport.appex`
   should be listed (Xcode adds it). If not, press + and add it.
7. Pawl target, Build Settings, search "Marketing Version" and "Current Project Version":
   set PawlReport to the same numbers as the app (2.4 and the current build), or App Store
   Connect rejects the upload.
8. Build to the phone. Home shows the "In the blocked apps" card with seven bars.

The extension has no app group and no network. It cannot talk to the app. That is by
Apple's design and it is the reason the privacy story does not change.
