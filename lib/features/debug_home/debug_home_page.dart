import 'package:flutter/material.dart';
import 'package:robyne/features/plugin_debug/plugin_debug_page.dart';
import 'package:robyne/features/search_debug/search_debug_page.dart';
import 'package:robyne/features/player_debug/player_debug_page.dart';
import 'package:robyne/features/local_debug/local_debug_page.dart';

class DebugHomePage extends StatefulWidget {
  const DebugHomePage({super.key});

  @override
  State<DebugHomePage> createState() => _DebugHomePageState();
}

class _DebugHomePageState extends State<DebugHomePage> {
  int _currentIndex = 0;

  final _pages = [
    PluginDebugPage(),
    SearchDebugPage(),
    PlayerDebugPage(),
    LocalDebugPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
        type: BottomNavigationBarType.fixed,
        items: [
          BottomNavigationBarItem(icon: Icon(Icons.extension), label: 'Plugin'),
          BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Search'),
          BottomNavigationBarItem(icon: Icon(Icons.play_circle), label: 'Player'),
          BottomNavigationBarItem(icon: Icon(Icons.folder), label: 'Local'),
        ],
      ),
    );
  }
}
