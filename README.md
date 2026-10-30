# Hippo Flutter SDK

[![pub version](https://img.shields.io/pub/v/hippo_flutter_sdk.svg)](https://pub.dev/packages/hippo_flutter_sdk)
[![license](https://img.shields.io/badge/license-MIT-blue.svg)](https://opensource.org/licenses/MIT)

A Flutter plugin for integrating the Hippo customer support platform into your mobile applications. Hippo provides a complete suite of tools for live chat, in-app messaging, and customer engagement.

## Features

- Initialize the Hippo SDK with your application credentials.
- Display the chat conversations view, or open a peer-to-peer chat.
- Unread **message** and **announcement** counts, as streams and on request.
- The unread message count of **one peer chat**, for a badge per chat.
- Hippo push notifications: shown by Hippo on Android, handled through APNs on iOS; tapping one opens the chat.
- Debug logging on Android, iOS and Dart.
- Clear all user data upon logout.

## Getting Started

```yaml
dependencies:
  hippo_flutter_sdk: ^0.5.0
```

Then run `flutter pub get`.

## Android Setup

The plugin compiles against Hippo's Android SDK but doesn't bundle it: add it to your app's `android/app/build.gradle`,
with the `Java-WebSocket` library Hippo needs:

```groovy
dependencies {
    implementation 'io.hippochat:hippo:3.0.21.37'
    implementation 'org.java-websocket:Java-WebSocket:1.5.1'
}
```

Hippo's AAR ships no R8 rules: if your release build shrinks code, keep `com.hippo.**`.

Hippo 4.0.0.x works with the plugin except `getUnreadAnnouncementCount()`, which that version can't refresh on request
(it answers with the last count Hippo reported). It also depends on a pre-AndroidX support library, so it needs
Jetifier; 3.0.21.37 is the version the plugin is built and tested with.

## iOS Setup

The plugin needs Hippo **2.1.72 or later** (iOS **15.1** or later). Hippo's releases after 2.1.58 are only on GitHub, not
on CocoaPods trunk, so pin one in your `ios/Podfile`:

```ruby
platform :ios, '15.1'

target 'Runner' do
  use_frameworks!
  pod 'Hippo', :git => 'https://github.com/Jungle-Works/Hippo-iOS-SDK.git', :tag => '2.1.72'
  # ...
end
```

Then `pod update Hippo`. Pin a tag rather than `:branch => 'master'`, so a Hippo change can't reach your build unseen.

Nothing else is needed on iOS: the plugin gives Hippo the APNs token and handles Hippo's notifications through the app
delegate. If your `AppDelegate` overrides `didRegisterForRemoteNotificationsWithDeviceToken` or the
`UNUserNotificationCenter` methods, call `super` so Flutter passes them on to plugins.

## Usage

```dart
import 'dart:convert';
import 'package:hippo_flutter_sdk/hippo_flutter_sdk.dart';

final hippo = HippoFlutterSdk();

Future<void> initHippo() async {
  await hippo.initHippo(jsonEncode({
    "appKey": "YOUR_APP_KEY",
    "appType": "1",
    "provider": "com.example.app.provider", // Android file provider authority
    "deviceToken": fcmToken, // Android: the FCM token, so Hippo can push to this device
    "userData": {
      "userUniqueKey": "UNIQUE_USER_ID",
      "fullName": "John Doe",
      "email": "john@example.com",
      "phoneNumber": "+1234567890",
      // "userIdentificationSecret": "...", // when your Hippo business verifies users
    },
  }));
}

hippo.showConversations();
```

### Unread counts

Messages and announcements are counted separately:

```dart
hippo.getUnreadCountStream().listen((count) => print('unread messages: $count'));
hippo.getUnreadAnnouncementCountStream().listen((count) => print('unread announcements: $count'));

final messages = await hippo.getUnreadCount(); // asks Hippo now
final announcements = await hippo.getUnreadAnnouncementCount();
```

A new listener first gets the last count known. Both counts go back to 0 on `clearHippoData()`.

### Unread messages in one chat

`getUnreadCount()` totals every chat the user ever had, so one old unread chat keeps it above 0. To show a badge per
peer chat (say, one per order), ask for that chat's count with the same JSON that `openPeerChat` opens it with:

```dart
final chat = jsonEncode({
  "transactionId": "AK806", // the chat's transaction id
  "userUniqueKey": "UNIQUE_USER_ID",
  "otherUserUniqueKeys": ["driver42"],
  "channelName": "#AK806",
});

final count = await hippo.getChatUnreadCount(chat); // null when Hippo can't tell yet

hippo.getChatUnreadCountStream().listen((chatCount) {
  print('${chatCount.transactionId}: ${chatCount.count} unread');
});
```

Only chats asked about are counted. Their counts come on the stream whenever Hippo reports one: when you ask, when a
message arrives in the chat, and when the chat is opened (0). Ask again when the app comes back to the foreground: on
iOS the answer then comes fresh from Hippo's server, which also counts messages that arrived while the app was in the
background. On Android, Hippo counts those from the pushes you hand to `handleHippoNotification`. All chat counts go
to 0 on `clearHippoData()`.

### Push notifications (Android)

Hippo's pushes reach your app through FCM. Hand them to Hippo, before any other notification handling, both in the
foreground and in the background handler:

```dart
FirebaseMessaging.onMessage.listen((message) async {
  if (await hippo.handleHippoNotification(message.data)) return; // Hippo shows it and updates the counts
  // ... your other notifications
});

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (await HippoFlutterSdk().handleHippoNotification(message.data)) return;
  // ...
}
```

On iOS `handleHippoNotification` only updates the counts (APNs shows the notification), so calling it on both
platforms is fine.

### Debug logging

In debug builds the plugin logs what it does with the tag `HippoFlutterSdk`: every call, every count Hippo reports,
notifications, and opening the chat screens. On Android, Hippo also logs its API requests and responses; on iOS, Hippo
prints its API calls to the console itself. Set `"debug": true` or `false` in the `initHippo` config to override it,
for example to see the logs in a release build. Keys, secrets and tokens are masked.

## Upgrading from 0.4.x

- iOS needs Hippo **2.1.72** or later (it was 2.1.66): one chat's count uses `fetchChatUnreadCount`, new in 2.1.72.
  Pin the tag in your Podfile as above, then `pod update Hippo`.
- Nothing else changes: `getChatUnreadCount` and `getChatUnreadCountStream` are new.

## Upgrading from 0.3.x

- `getUnreadCountStream()` now carries only the unread **message** count. Announcements, which used to arrive on the
  same stream and overwrite it, are on `getUnreadAnnouncementCountStream()`.
- `getUnreadCount()` asks Hippo for the count. On Android it used to always return 0.
- iOS needs Hippo 2.1.66 or later and iOS 15.1. A Podfile patch adding `userIdenficationSecret:` to the plugin is no
  longer needed: the plugin passes `userData.userIdentificationSecret` itself. Remove the patch.
- Android: call `handleHippoNotification` from your FCM handlers (see above).

## Documentation

For more detailed information, see the [`doc`](./doc) folder.
