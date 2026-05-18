# Getting Started

This guide will walk you through the process of adding the Hippo Flutter SDK to your project and initializing it.

## Installation

1.  **Add the dependency**: Open your `pubspec.yaml` file and add the following line under `dependencies`:

    ```yaml
    dependencies:
      hippo_flutter_sdk: ^0.2.0 # Use the latest version
    ```

2.  **Install the package**: Run the following command in your terminal to get the package:

    ```bash
    flutter pub get
    ```

## Initialization

To start using the Hippo SDK, you need to initialize it with your configuration details. This should typically be done when your application starts.

```dart
import 'package:hippo_flutter_sdk/hippo_flutter_sdk.dart';
import 'dart:convert';

final _hippoFlutterSdkPlugin = HippoFlutterSdk();

void initHippo() {
  final config = {
    "appKey": "YOUR_APP_KEY",
    "appType": "1",
    "environment": "live",
    "userData": {
      "userUniqueKey": "UNIQUE_USER_ID", // Required
      "fullName": "John Doe",
      "email": "john.doe@example.com",
      "phoneNumber": "+1234567890"
    },
  };
  _hippoFlutterSdkPlugin.initHippo(jsonEncode(config));
}
```

Replace `"YOUR_APP_KEY"` and the `userData` with your actual application key and user details.
