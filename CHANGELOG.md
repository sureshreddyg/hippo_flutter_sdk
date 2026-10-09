# Changelog

## 0.4.0

Unread counts and notifications, as advised by the Hippo team.

* **Unread counts.** Messages and announcements are now separate:
  * `getUnreadCountStream()` carries messages only. Before, announcements arrived on the same stream and overwrote the
    message count.
  * The new `getUnreadAnnouncementCountStream()` and `getUnreadAnnouncementCount()` carry announcements.
  * `getUnreadCount()` asks Hippo for the count. It used to return 0 on Android.
  * Android sets Hippo's `UnreadCount` listener when Hippo starts, not only once Dart listens. Before, Hippo dropped the
    counts from pushes that arrived first.
  * iOS uses `updateUnreadCount` and `getUnreadAnnouncementCount`. The announcement count arrives through
    `hippoAnnouncementCustomerUnreadCount`, because Hippo doesn't call that completion.
* **Notifications.**
  * The new `isHippoNotification` and `handleHippoNotification` work on both platforms. On Android, Hippo shows the
    notification and updates the counts.
  * iOS gives Hippo the APNs token, updates the counts when a Hippo push arrives, and opens the chat when one is
    tapped. Before, Hippo had no token for iOS devices.
* **Debug logging** on Android, iOS and Dart (tag `HippoFlutterSdk`).
  * It covers calls, counts, notifications and the chat screens. On Android, Hippo's API requests and responses are
    logged too.
  * It's on in debug builds; `"debug"` in the init config overrides it.
* **iOS compatibility.**
  * Needs Hippo 2.1.66 or later and iOS 15.1. It compiles against Hippo 2.1.66–2.1.72, which the previous version
    didn't.
  * Passes `userIdentificationSecret` and `selectedlanguage`.
* **Android.** Builds against Hippo 3.0.21.37. Calls made before `initHippo` or without an activity return an error
  instead of crashing.
* **CI.** Pull requests are analyzed and tested, and the example app is built on Android and iOS.

## 0.1.0

* Initial release of the Hippo Flutter SDK.
* Includes support for initializing Hippo, showing conversations, clearing user data, and peer-to-peer chat.
