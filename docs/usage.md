# Usage Guide

This guide provides examples of how to use the core features of the Hippo Flutter SDK.

## Showing Conversations

To open the main chat view where users can see all their conversations, use the `showConversations` method:

```dart
_hippoFlutterSdkPlugin.showConversations();
```

## Opening a Peer-to-Peer Chat

To open a direct chat with another user, you can use the `openPeerChat` method. You'll need to provide a unique `transactionId` for the chat, along with the unique keys for both the current user and the peer.

```dart
import 'dart:convert';

void openPeerChat() {
  final peerChatData = {
    "transactionId": "peer-chat-12345",
    "userUniqueKey": "CURRENT_USER_ID", // The current user's unique key
    "otherUserUniqueKeys": ["PEER_USER_ID"], // The peer's unique key
    "channelName": "Support Chat",
  };
  _hippoFlutterSdkPlugin.openPeerChat(jsonEncode(peerChatData));
}
```

## Clearing User Data

If you need to log out a user and clear all their data from the device, you can use the `clearHippoData` method:

```dart
_hippoFlutterSdkPlugin.clearHippoData();
```

## Listening for Unread Messages

The SDK provides a stream that you can listen to for real-time updates on the number of unread messages.

```dart
StreamSubscription<int>? _unreadCountSubscription;

void listenForUnreadMessages() {
  _unreadCountSubscription = _hippoFlutterSdkPlugin.getUnreadCountStream().listen((count) {
    print('Unread message count: $count');
    // You can update your UI here
  });
}

// Don't forget to cancel the subscription when you're done!
@override
void dispose() {
  _unreadCountSubscription?.cancel();
  super.dispose();
}
```
