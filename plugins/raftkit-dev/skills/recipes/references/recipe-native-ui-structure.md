# Recipe · platform-native UI structure

**Version: v1**

Build mobile screens on the platform's own structural conventions, so the app
feels native on each platform instead of a ported web page.

## Applies when

A **mobile** story builds screens. This recipe governs **structure** —
navigation, back behaviour, control styles — not brand: the project's design
tokens still style the UI.

## Story pattern

> As a mobile user, I want the app to navigate and behave the way my platform
> does, so that it feels native and predictable.

- **Navigation:** use the platform-native navigation structure (stacks, tabs,
  modals) rather than re-inventing web-style routing on mobile.
- **Back behaviour:** honour each platform's convention — Android's hardware/gesture
  back and up-affordance; iOS's swipe-back and nav-bar back. Back never strands the
  user or loses expected state.
- **Control styles:** use platform-native controls and their expected behaviour
  (pickers, switches, action sheets/menus, form sheets) rather than custom
  look-alikes.

## Implementation pattern

Applied via the mobile stack (Expo). Prefer the platform's real UI structure and
navigation primitives; let the design tokens theme them.

- Navigation with the Expo/React Native navigation stack, using native stacks and
  native tabs so transitions, headers, and back gestures are the platform's own.
- Reach for native controls (e.g. the platform picker, switch, action sheet, form
  sheet) instead of bespoke re-implementations.
- Respect the resolution order: a Project Profile may override a structural default;
  the story's explicit UI requirements beat this recipe on conflict.

### Mobile variant (Expo) — primary

This recipe is mobile-first: the above **is** the Expo variant.

### Web variant (React / Next.js)

On web the platform-native concept maps to web-native structure — real routing,
browser back/forward honoured, semantic HTML controls over custom widgets. Full
mobile-platform conventions (hardware back, action sheets) are **N/A on web**.

## Acceptance criteria (this recipe's own)

- Mobile screens use platform-native navigation structure.
- Back behaviour follows each platform's convention and never strands the user.
- Controls are platform-native in style and behaviour.
- Structure is applied without dictating brand — design tokens style it.

## Accessibility baseline

Native controls inherit the platform's built-in accessibility; preserve it — do
not replace an accessible native control with a custom one that drops screen-reader
support, focus order, or minimum tap-target size.
