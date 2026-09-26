# Pawl — Extensions & App Group setup (durable timer + block screen)

Goal: make the cooling-off / auto-relock survive the app being force-quit (HC-6) and show
a custom block screen. That needs an **App Group** plus **two app-extension targets**.
I can't create targets from code — these are Xcode clicks. The Swift is already written;
you'll mostly create targets and paste.

Order matters. Do A → B → C → D, then tell me and I'll do step E (flip the app to use it).

---

## A. Add the App Group to the main app

1. Select the **Pawl** target → **Signing & Capabilities** → **+ Capability** → **App Groups**.
2. Click the **+** under App Groups → add a group named exactly:
   ```
   group.io.github.jasonepage.Pawl
   ```
3. Make sure its checkbox is **ticked**.

(This ID must match `AppGroup.id` in `PawlShared.swift` — it already does.)

---

## B. Create the Device Activity Monitor extension (PawlMonitor)

1. **File → New → Target…** → search **Device Activity Monitor Extension** → Next.
2. Product name: **PawlMonitor** → Finish. (If Xcode asks to activate the scheme, click **Activate**.)
3. Select the new **PawlMonitor** target → **Signing & Capabilities**:
   - **+ Capability → App Groups** → tick the same `group.io.github.jasonepage.Pawl`.
   - **+ Capability → Family Controls** (the extension uses ManagedSettings, so it needs this).
4. Xcode generated a file in the PawlMonitor folder (e.g. `DeviceActivityMonitorExtension.swift`).
   Open it and **replace its entire contents** with the code from
   `PawlMonitor/DeviceActivityMonitorExtension.swift` in the repo.
   - If Xcode named the class differently than `DeviceActivityMonitorExtension`, either rename
     the class to match Xcode's, or keep Xcode's name and paste just the two `override` methods in.
5. **Share the common code with this target:** in the Project navigator click `PawlShared.swift`
   → open the **File inspector** (right panel) → under **Target Membership**, tick **PawlMonitor**
   (leave **Pawl** ticked too).

---

## C. Create the Shield Configuration extension (PawlShield)

1. **File → New → Target…** → search **Shield Configuration Extension** → Next.
2. Product name: **PawlShield** → Finish → Activate if asked.
3. Select **PawlShield** target → **Signing & Capabilities**:
   - **+ Capability → App Groups** → tick `group.io.github.jasonepage.Pawl`.
   - **+ Capability → Family Controls**.
4. Open Xcode's generated file in the PawlShield folder (e.g. `ShieldConfigurationExtension.swift`)
   and **replace its contents** with the code from
   `PawlShield/ShieldConfigurationExtension.swift` in the repo (match the class name as in step B4).

(This extension doesn't need `PawlShared.swift` — it only draws the screen.)

---

## D. Sanity build

1. Select the **Pawl** app scheme (top bar) and build (⌘B). It should compile.
2. If you see "cannot find 'SharedShield' / 'SharedState' / '.pawlUnlock' in scope" while building
   **PawlMonitor**, that's step B5 — `PawlShared.swift` isn't a member of the PawlMonitor target yet.

---

## E. Tell me — I flip the app to the durable timer

Once A–D are done and it builds, message me. I'll make one small edit to `UnlockViewModel`
so a valid key tap schedules the OS-owned `DeviceActivity` window (via `UnlockScheduler`)
instead of the in-app countdown. Then we test the real thing:

- Pair key → unlock → **force-quit Pawl** during the wait → the shield should still lift on time
  and re-lock on its own. That's the proof it can't be cheated.
- Open a shielded app → you should see the green **"Locked by Pawl"** screen with no unlock button.

## Notes / gotchas (we'll iterate on device)
- DeviceActivity windows have a ~15-minute minimum; our default grace window is 30 min (≥ the minimum), so we're fine.
- The OS can fire interval callbacks a little late (seconds–a couple minutes); acceptable for a
  cooling-off timer.
- All three targets must share the **same** App Group ID and have **Family Controls** where they
  touch ManagedSettings (app, PawlMonitor, PawlShield).
