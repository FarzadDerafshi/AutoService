// Simple compile-time on/off switches for temporarily hiding a feature
// without ripping out the underlying implementation. Flip back to `true`
// (or delete the flag once a feature is permanent) rather than deleting
// the code it guards.

/// Whether new shops can self-register. Turned off during the public
/// usability test (Farzad's request) so nobody can create a real shop
/// account while testing is in progress — until he says otherwise. Blocks
/// both the "Create account" link on the login screen and direct
/// navigation to `/register` (see `app.dart`'s router `redirect`).
const kRegistrationOpen = false;
