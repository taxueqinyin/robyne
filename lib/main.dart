import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:robyne/core/audio/audio_player_service.dart';
import 'package:robyne/core/js_sandbox/sandbox_manager.dart';
import 'package:robyne/features/local_scan/local_scan_page.dart';
import 'package:robyne/features/player/player_controls.dart';
import 'package:robyne/features/plugin_management/plugin_management_page.dart';
import 'package:robyne/features/search/search_page.dart';

void main() {
  runApp(const ProviderScope(child: RobyneApp()));
}

class RobyneApp extends StatelessWidget {
  const RobyneApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Robyne',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.blue,
        useMaterial3: true,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        colorSchemeSeed: Colors.blue,
        useMaterial3: true,
        brightness: Brightness.dark,
      ),
      home: const MainPage(),
    );
  }
}

class MainPage extends ConsumerStatefulWidget {
  const MainPage({super.key});

  @override
  ConsumerState<MainPage> createState() => _MainPageState();
}

class _MainPageState extends ConsumerState<MainPage> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    // Initialize sandbox on startup
    Future.microtask(() {
      ref.read(sandboxManagerProvider.notifier).initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    final playerState = ref.watch(audioPlayerServiceProvider);

    // Auto-show player when a song starts playing
    if (playerState.currentSong != null) {
      ref.read(playerVisibleProvider.notifier).state = true;
    }

    final pages = [
      const SearchPage(),
      const LocalScanPage(),
      const PluginManagementPage(),
    ];

    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: pages[_currentIndex],
          ),
          const PlayerControls(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.search),
            label: 'Search',
          ),
          NavigationDestination(
            icon: Icon(Icons.folder),
            label: 'Local',
          ),
          NavigationDestination(
            icon: Icon(Icons.extension),
            label: 'Plugins',
          ),
        ],
      ),
    );
  }
}
