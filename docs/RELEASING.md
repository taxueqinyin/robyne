# Releasing

For maintainers, and for anyone who forks this and wants to publish their
own builds.

## Cutting a release

```bash
git tag v1.0.0 && git push origin v1.0.0
```

The release workflow builds Windows and Android and publishes both to
GitHub Releases, and also publishes a macOS build — but see the macOS
section below: that one is untested and unsigned.

## macOS

`macos/` exists and CI compiles it on every push, but no one has actually
run Robyne on a Mac. A green build proves the platform folders and
dependencies line up — not that playback, the tray, or plugins work.

The release workflow nevertheless publishes a `robyne-macos-unsigned-*.zip`.
It is there so someone with a Mac can try it without building from source,
and the release notes say plainly that it is untested and unsigned.

### What users hit when they open it

The bundle carries neither a signature nor a notarization ticket, so macOS
refuses to launch it. Two distinct failures, in the order users hit them:

1. **"Apple could not verify…"** — System Settings → Privacy & Security →
   Security, then **Open Anyway**. On macOS 13 Ventura and later this is the
   working route. Right-click → Open still exists on older versions but is
   no longer dependable, so do not document it as the primary path.
2. **"…is damaged and can't be opened. You should move it to the Trash."** —
   this is the quarantine attribute, not damaged contents, and it offers no
   Open Anyway button. The user has to clear it by hand:

   ```bash
   xattr -cr /Applications/robyne.app
   ```

   This is the one that makes an unsigned build feel broken, and it is the
   strongest argument for notarization: notarized bundles never reach it.

It is packaged with `ditto`, not `zip`: a `.app` bundle relies on symlinks
in its `Frameworks/Versions` layout, and a plain zip dereferences them into
duplicated files, after which the bundle cannot load its embedded Flutter
framework.

Turning it into a supported platform takes two things:

1. Someone with a Mac actually using it and reporting what works.
2. An Apple Developer Program membership (paid, yearly) for a Developer
   ID certificate and notarization. Without it every user has to work
   through the two steps above, including a Terminal command — which is
   not something to hand to users.

The Release entitlements already allow network access and user-selected
file read/write, which the plugins and the local library import need.

## Android signing

Android signing is self-signed. Nothing needs to be applied for, nobody
validates who you are, and it costs nothing — you generate a key and use
it.

```bash
keytool -genkeypair -v -keystore robyne.jks -storetype PKCS12 \
  -keyalg RSA -keysize 2048 -validity 10000 -alias robyne
```

### Why the key matters more than any other file here

**Lose it and you can never ship an update again.** Android only allows
an APK to replace an installed one when both carry the same signature.
With the key gone, every existing user has to uninstall before they can
install the next version, and their local data goes with it.

It is also a credential: anyone holding it can publish an APK that phones
accept as a legitimate update to your app.

Keep at least two copies, and make sure one survives losing this disk — a
password manager that holds file attachments (1Password, Bitwarden,
KeePass) covers both the lost-machine and the forgotten-password case at
once. Never commit it; `.gitignore` excludes `*.jks`.

### Wiring it into CI

The workflow reads the key from repository secrets, never from a file in
the tree:

```powershell
$b64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes('robyne.jks'))
gh secret set ANDROID_KEYSTORE_BASE64     -b $b64
gh secret set ANDROID_KEYSTORE_PASSWORD   < robyne-keystore-password.txt
gh secret set ANDROID_KEY_ALIAS           -b 'robyne'
gh secret set ANDROID_KEY_PASSWORD        < robyne-keystore-password.txt
gh variable set SIGN_ANDROID -b 'true'
```

Without these, `build.gradle.kts` falls back to the debug key and the
build warns loudly. That APK installs and works, but it is not a
distributable release: Play rejects it, and it cannot upgrade an existing
install.

`SIGN_ANDROID` is a variable rather than a secret because it is a switch,
not a credential. It exists so a fork can build a release before it has a
keystore at all.
