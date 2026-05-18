# Hippo Flutter SDK

[![pub version](https://img.shields.io/pub/v/hippo_flutter_sdk.svg)](https://pub.dev/packages/hippo_flutter_sdk)
[![license](https://img.shields.io/badge/license-MIT-blue.svg)](https://opensource.org/licenses/MIT)

A Flutter plugin for integrating the Hippo customer support platform into your mobile applications. Hippo provides a complete suite of tools for live chat, in-app messaging, and user support.

## Features

- Initialize the Hippo SDK with your application credentials.
- Display the chat conversations view.
- Initiate peer-to-peer chats between users.
- Get real-time updates on unread message counts.
- Clear all user data upon logout.

## Getting Started

To get started, add the Hippo Flutter SDK to your `pubspec.yaml` file:

```yaml
dependencies:
  hippo_flutter_sdk: ^0.1.2 # Check for the latest version on pub.dev
```

Then, run `flutter pub get` to install the package.

## Android Setup

The Hippo SDK requires the `Java-WebSocket` library to function correctly. To avoid potential version conflicts with other plugins, this dependency is not bundled and must be added manually to your main application.

In your app-level `android/app/build.gradle` file, please add the following dependency:

```groovy
dependencies {
    // ... other dependencies
    implementation 'org.java-websocket:Java-WebSocket:1.5.1'
}
```

## Usage

First, initialize the SDK with your app key and user details. This is typically done when your app starts.

```dart
import 'package:hippo_flutter_sdk/hippo_flutter_sdk.dart';
import 'dart:convert';

final _hippoFlutterSdkPlugin = HippoFlutterSdk();

void initHippo() {
  final config = {
    "appKey": "YOUR_APP_KEY",
    "userData": {
      "userUniqueKey": "UNIQUE_USER_ID",
      "fullName": "John Doe",
    },
  };
  _hippoFlutterSdkPlugin.initHippo(jsonEncode(config));
}
```

Once initialized, you can open the conversations view:

```dart
_hippoFlutterSdkPlugin.showConversations();
```

## Documentation

For more detailed information on installation, configuration, and advanced usage, please see the full documentation in the [`doc`](./doc) folder.
