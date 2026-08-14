# Running refind on a real iPhone

Written for the free-Apple-ID path: a Mac with Xcode, an iPhone on a cable, no
paid Developer Program membership. Everything below is a one-time setup except
the 7-day re-signing in the last section.

## What you need

| | |
|---|---|
| Mac | macOS able to run Xcode 16.2 or newer (the project is `objectVersion = 77`, which older Xcode cannot open) |
| iPhone | **iOS 18.2 or newer** — that is `IPHONEOS_DEPLOYMENT_TARGET`, and an older phone will not appear as a run destination |
| Cable | USB-to-Lightning or USB-C. Wireless works later, but pair over cable first |
| Apple ID | Any Apple ID. No purchase, no Developer Program |

The app needs no network: it runs entirely against `MockRefindRepository`, so it
works in airplane mode.

## First run

**1. Open the project**

```bash
open refind.xcodeproj
```

**2. Set the signing team**

Select the `refind` project in the navigator → target `refind` → **Signing &
Capabilities**.

*Automatically manage signing* is already on. The **Team** dropdown holds
`4C24793SVA`, which is the team the project was created with. If your Xcode is
signed into that account, leave it. Otherwise pick your own from the dropdown —
if the list is empty, add your Apple ID under Xcode → Settings → Accounts first,
then come back and choose the entry ending in *(Personal Team)*.

Do this for the `refindTests` and `refindUITests` targets too, or Xcode will
refuse to build the scheme. (You can also just not run tests on device.)

**3. If Xcode rejects the bundle identifier**

The bundle ID is `planary.refind`. Apple requires it to be globally unique, and
a personal team registers it to you on first build. If you get *"The app
identifier cannot be registered to your development team"*, someone already has
it — change **Bundle Identifier** to something of your own, e.g.
`ch.pantelei.refind`. Nothing in the code reads the bundle ID, so it is safe to
change.

**4. Plug in the phone and trust the Mac**

Unlock the phone. Tap **Trust** on the "Trust This Computer?" prompt and enter
your passcode. The device now appears in Xcode's run-destination menu at the top
of the window — select it there instead of a simulator.

**5. Enable Developer Mode on the phone**

iOS 16 and later require this, and the toggle **only appears after you have
tried to install a development build at least once**. So:

- Press ⌘R. The install will fail with a Developer Mode message. That is expected.
- On the phone: **Settings → Privacy & Security → Developer Mode** → on → restart the phone when asked → unlock and confirm.

**6. Trust the certificate**

Press ⌘R again. This time it installs, then fails to launch with
*"Could not launch refind ... process launch failed: Security"*, or the icon
appears greyed on the Home Screen. Your certificate is untrusted until you say
so:

**Settings → General → VPN & Device Management → Developer App →** your Apple ID
**→ Trust**.

**7. Press ⌘R once more**

It launches. Splash → onboarding → the tab shell.

## Free-account limits

These are Apple's rules for signing without the paid programme, not something
the project can work around:

- **The app stops working after 7 days.** A personal-team provisioning profile is valid for one week. When it expires the app refuses to launch ("the app could not be verified"). Fix: plug in and press ⌘R again — it re-signs and the week restarts. Nothing is lost; the app's data lives in `@AppStorage` and the in-memory mock, and reinstalling resets it anyway.
- **Three apps at a time** per device signed this way.
- **No push notifications.** `aps-environment` is a paid-only entitlement. The permission prompt in onboarding step 3 still appears and still works, but `registerForRemoteNotifications()` then fails and `AppDelegate.didFailToRegisterForRemoteNotificationsWithError` swallows it — deliberately, since push is a nicety here and there is no server to send from anyway. Everything else behaves normally.

If you later join the Developer Program, re-add the capability in **Signing &
Capabilities → + Capability → Push Notifications**; that regenerates the
entitlements file this project intentionally no longer ships.

## After the first time

Once paired, **Settings → General → AirPlay & Continuity → ...** is not
involved — wireless debugging is set in Xcode: **Window → Devices and Simulators
→** select the phone → **Connect via network**. After that you can build to the
phone with the cable unplugged, as long as both are on the same Wi-Fi.

To run without Xcode attached, just launch it from the Home Screen. The build
Xcode installs is a Debug build, so the `RF_SCREEN` debug hatch and
`FontLoader`'s assertion are both live — that is fine on device, but if you want
the app to behave exactly as a shipped one would, switch the scheme to Release
(**Product → Scheme → Edit Scheme → Run → Build Configuration → Release**).

## Troubleshooting

| Error | Cause | Fix |
|---|---|---|
| Phone missing from the destination list | iOS older than 18.2, or the phone is locked | Check the iOS version; unlock and re-trust |
| *"Signing for 'refind' requires a development team"* | No team selected on one of the three targets | Step 2, on each target |
| *"Failed to register bundle identifier"* | `planary.refind` is taken by another account | Step 3 |
| *"Unable to install ... Developer Mode disabled"* | Step 5 not done | Step 5 |
| *"process launch failed: Security"* | Certificate not trusted yet | Step 6 |
| *"The app could not be verified"* after a few days | 7-day profile expired | Re-run from Xcode |
| Fonts look like the system font, app trips an assertion at launch | The TTFs did not make it into the bundle | Check the four files in `refind/Resources/Fonts` are present and that their names match `UIAppFonts` in `Config/Info.plist` |
| *"provisioning profile does not include the com.apple.security.\* entitlement"* | You are on a build from before the entitlements file was removed | Pull this branch; the file is gone and `CODE_SIGN_ENTITLEMENTS` is unset |

## What changed to make this work

The project was generated from Xcode's multiplatform template and still carried
Mac and Vision Pro settings that a real device build trips over:

- `refind/refind.entitlements` declared `com.apple.security.app-sandbox` and `com.apple.security.files.user-selected.read-only`. Both are macOS entitlements. An iOS provisioning profile never contains them, so codesign rejected the device build — while the simulator, which does not check entitlements against a profile, kept working. The file is deleted and `CODE_SIGN_ENTITLEMENTS` is unset; nothing in the app needs an entitlement.
- `SUPPORTED_PLATFORMS` listed `macosx xros xrsimulator` and `SDKROOT` was `auto`, for platforms the app has no code for. Now `iphoneos iphonesimulator` and `iphoneos`.
- `TARGETED_DEVICE_FAMILY` was `1,2,7` — the `7` is visionOS. Now `1,2` (iPhone and iPad).
- The `MACOSX_DEPLOYMENT_TARGET`, `XROS_DEPLOYMENT_TARGET` and macOS `LD_RUNPATH_SEARCH_PATHS` settings went with them.
