# Changelog

## 0.5.0

The unread count of one peer chat, for a badge per chat. `getUnreadCount()` totals every chat the user ever had, so
one old unread chat kept it above 0 and lit every badge.

* **New: `getChatUnreadCount(peerChatData)`** answers one chat's unread count. It takes the JSON `openPeerChat` opens
  the chat with. **`getChatUnreadCountStream()`** sends each chat's count, with its `transactionId`, whenever Hippo
  reports one: when asked, when a message arrives in the chat, and when it's opened (0).
* **Android:** Hippo's `fetchUnreadCountForRequest` and its `UnreadCountFor` callback. Hippo counts a chat's later
  messages from the pushes handed to `handleHippoNotification`.
* **iOS:** `fetchUnreadCountFor` finds the chat the first time; after that the count comes from Hippo's server by the
  chat's channel (`fetchChatUnreadCount`). `fetchUnreadCountFor` answers a chat it knows from memory, which misses
  messages that arrived while the app was in the background. The plugin learns each chat's channel from Hippo's answers
  and pushes, and from Notification Centre for a chat whose first message came while the app was closed.
* A request Hippo doesn't answer gets the chat's last count known (or `null`) after 8 seconds. Android's Hippo never
  answers for a chat it couldn't find, and iOS's answers through its delegate only for a chat it knows.
* **iOS needs Hippo 2.1.72 or later** (it was 2.1.66): `fetchChatUnreadCount` is new in 2.1.72.

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
