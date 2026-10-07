# Keep `pubspec.lock` on the default pub host

`pubspec.lock` records the URL each package was fetched from. Running
`flutter pub get` with `PUB_HOSTED_URL` pointed at a mirror rewrites every
entry to that mirror, and the lock file is committed — so one local
session behind a mirror turns the next commit into a 142-line diff that
has nothing to do with the change being made. Worse, everyone outside
that mirror's region rewrites it straight back.

A mirror is a local network setting, not a property of the project. Keep
it out of the repository:

```powershell
# Unset for the commands that touch the lock file.
$env:PUB_HOSTED_URL = $null
$env:FLUTTER_STORAGE_BASE_URL = $null
flutter pub get
```

CI rejects a lock file containing a mirror host, so this fails loudly
instead of quietly producing noise for everyone else.

If you are in a region where the default host is slow, set the mirror for
day-to-day work but unset it before committing, and check
`git diff pubspec.lock` is empty.
