import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:hippo_flutter_sdk/hippo_flutter_sdk.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hippo SDK Example',
      theme: ThemeData(
        primarySwatch: Colors.teal,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        scaffoldBackgroundColor: Colors.grey[100],
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.teal,
          elevation: 0,
          titleTextStyle: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        cardTheme: CardThemeData(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        ),
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final _hippoFlutterSdkPlugin = HippoFlutterSdk();
  int? _unreadCount;
  int? _announcementCount;
  StreamSubscription<int>? _unreadCountSubscription;
  StreamSubscription<int>? _announcementCountSubscription;
  bool _isHippoInitialized = false;

  void _initHippo() async {
    setState(() {
      _isHippoInitialized = true;
    });
    final config = {
      // Your Hippo app key: flutter run --dart-define=HIPPO_APP_KEY=...
      "appKey": const String.fromEnvironment('HIPPO_APP_KEY'),
      "appType": "1",
      // "environment": "live",
      "provider": "com.udvilabs.hippo_flutter_sdk_example.provider",
      "deviceToken": "1234567890", // Required
      "userData": {
        "userUniqueKey": "0e886538-a607-444f-a8e1-32651419f8a4", // Required
        "fullName": "Suresh Reddy",
        "email": "suresh@example.com",
        "phoneNumber": "+1234567890",
        "selectedlanguage": "en",
      },
    };
    await _hippoFlutterSdkPlugin.initHippo(jsonEncode(config));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Hippo Initialized!'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showConversations() {
    _hippoFlutterSdkPlugin.showConversations();
  }

  Future<void> _refreshCounts() async {
    final messages = await _hippoFlutterSdkPlugin.getUnreadCount();
    final announcements = await _hippoFlutterSdkPlugin.getUnreadAnnouncementCount();
    if (!mounted) return;
    setState(() {
      _unreadCount = messages;
      _announcementCount = announcements;
    });
  }

  void _clearHippoData() {
    _hippoFlutterSdkPlugin.clearHippoData();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Hippo data cleared!'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  void _openPeerChat() {
    final peerChatData = {
      "transactionId": ":61034680",
      "userUniqueKey": "0e886538-a607-444f-a8e1-32651419f8a4", // Current user's unique key
      "otherUserUniqueKeys": ["2072906"], // Peer's unique key
      "channelName": "Peer Chat",
      // "peerName": "Flutter Peer",
    };
    _hippoFlutterSdkPlugin.openPeerChat(jsonEncode(peerChatData));
  }

  @override
  void initState() {
    super.initState();
    _unreadCountSubscription = _hippoFlutterSdkPlugin
        .getUnreadCountStream()
        .listen((count) {
          if (!mounted) return;
          setState(() {
            _unreadCount = count;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Unread count updated: $count'),
              backgroundColor: Colors.blueAccent,
            ),
          );
        });
    _announcementCountSubscription = _hippoFlutterSdkPlugin
        .getUnreadAnnouncementCountStream()
        .listen((count) {
          if (!mounted) return;
          setState(() {
            _announcementCount = count;
          });
        });
  }

  @override
  void dispose() {
    _unreadCountSubscription?.cancel();
    _announcementCountSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Hippo SDK Demo')),
      body: ListView(
        padding: const EdgeInsets.all(8.0),
        children: [
          _ActionCard(
            title: 'Initialize Hippo',
            icon: Icons.power_settings_new,
            onTap: _initHippo,
          ),
          _ActionCard(
            title: 'Show Conversations',
            icon: Icons.chat_bubble_outline,
            onTap: _showConversations,
          ),
          _ActionCard(
            title: 'Unread Count',
            icon: Icons.mark_chat_unread_outlined,
            onTap: () {},
            trailing:
                _isHippoInitialized
                    ? _unreadCount != null
                        ? Chip(
                          label: Text('$_unreadCount'),
                          backgroundColor: Colors.teal,
                          labelStyle: const TextStyle(color: Colors.white),
                        )
                        : const CircularProgressIndicator()
                    : null,
          ),
          _ActionCard(
            title: 'Unread Announcements',
            icon: Icons.campaign_outlined,
            onTap: () {},
            trailing: _isHippoInitialized && _announcementCount != null
                ? Chip(
                    label: Text('$_announcementCount'),
                    backgroundColor: Colors.teal,
                    labelStyle: const TextStyle(color: Colors.white),
                  )
                : null,
          ),
          _ActionCard(
            title: 'Refresh Counts',
            icon: Icons.refresh,
            onTap: _refreshCounts,
          ),
          _ActionCard(
            title: 'Clear Hippo Data',
            icon: Icons.delete_sweep_outlined,
            onTap: _clearHippoData,
          ),
          _ActionCard(
            title: 'Open Peer Chat',
            icon: Icons.chat_outlined,
            onTap: _openPeerChat,
          ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onTap;
  final Widget? trailing;

  const _ActionCard({
    required this.title,
    required this.icon,
    required this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon, color: Colors.teal, size: 28),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
        trailing: trailing,
        onTap: onTap,
      ),
    );
  }
}
