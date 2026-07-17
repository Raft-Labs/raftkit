# Recipe · in-app auto-update

**Version: v1**

Prompt users onto the latest version of the app, so an old client is never left
running silently against a moved-on backend.

## Applies when

The story asks that users be prompted, nudged, or forced onto a newer version —
an "update available" prompt, a minimum-supported-version gate, or a forced
upgrade.

## Story pattern

> As a user, I want to be told when a newer version is available (and required),
> so that I stay on a supported build without hunting for the update myself.

- **Trigger:** on app launch and on resume from background, check the current
  version against the latest published version.
- **Optional update:** a newer version exists but the current one is still
  supported — show a dismissible prompt inviting the user to update. Do not block.
- **Forced update:** the current version is below the minimum supported version —
  show a blocking prompt that cannot be dismissed until the user updates.
- **Copy is default-only:** the story's exact strings override the recipe's.

## Implementation pattern

The app reads two values — the **latest** version and the **minimum supported**
version — from a version endpoint, and compares them to the running version.

- Compare running vs latest → optional-update path; running vs minimum → forced-update path.
- **Side effect (documented):** the client calls a **version endpoint** to read
  latest + minimum. Fail-open — if the endpoint is unreachable, do not block the
  user; log and let them continue on the current build.
- Respect the resolution order: a Project Profile may override the endpoint,
  thresholds, or optional-vs-forced policy; the story's explicit rules beat this
  recipe on conflict.

### Web variant (React / Next.js)

Latest/minimum served from an app-owned endpoint (or an env-backed value read at
runtime); on a version behind, surface a non-blocking banner for optional and a
blocking modal for forced. A web "update" is a reload onto the newly deployed
build.

### Mobile variant (Expo)

Distinguish two update kinds:
- **JS/content updates** — delivered over-the-air by the Expo update mechanism;
  the recipe's optional/forced prompt drives when the user reloads onto the
  downloaded update.
- **Native/store updates** — require a new binary; the forced-update path deep-links
  the user to the store listing (store *submission* itself is out of scope).

## Acceptance criteria (this recipe's own)

- On launch/resume, the app compares running version to latest and to minimum.
- A supported-but-behind client shows a **dismissible** optional-update prompt.
- A below-minimum client shows a **blocking** forced-update prompt.
- The version endpoint being unreachable does **not** block the user (fail-open).
- Prompt copy defaults are stated but the story's exact strings override them.

## Accessibility baseline

Prompts are dialogs with a clear title and action; focus moves to the dialog;
the update action is a real, labelled control reachable by keyboard (web) and
screen reader (both platforms); a forced prompt traps focus until resolved.
