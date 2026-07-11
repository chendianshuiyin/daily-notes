# App Update Contract

## Channel

Daily Notes checks the repository's latest public GitHub Release. Drafts, prereleases, tags without releases, and untrusted download hosts are ignored. Version comparison uses the installed package version rather than a remote flag.

## User Experience

- Automatic checks are enabled by default and run at most once every 24 hours.
- Network errors never block launch, capture, editing, export, or sync.
- Settings expose an on/off switch and a manual check command with current status.
- A newer release shows version, publish date, and bounded release notes before any external action.
- Android selects the release APK; Windows and Linux select their platform ZIP. Web and unsupported platforms open the release page.

## Safety

Only HTTPS `github.com` release pages and asset URLs are accepted. Daily Notes never sends note content during a check and never performs silent installation or executable replacement. Confirmed updates are handed to the platform browser/download manager so operating-system signing and installation prompts remain intact.
