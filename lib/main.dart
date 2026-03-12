import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:usage_stats/usage_stats.dart';
import 'database_helper.dart';
import 'background_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeService();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cognitive Memory',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple, brightness: Brightness.dark),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isServiceRunning = false;

  @override
  void initState() {
    super.initState();
    _checkServiceStatus();
  }

  Future<void> _checkServiceStatus() async {
    final running = await FlutterBackgroundService().isRunning();
    setState(() {
      _isServiceRunning = running;
    });
  }

  Future<void> _requestUsagePermission() async {
    bool? isGranted = await UsageStats.checkUsagePermission();
    if (isGranted == null || !isGranted) {
      await UsageStats.grantUsagePermission();
    }
  }

  Future<void> _toggleService() async {
    await _requestUsagePermission();
    
    final service = FlutterBackgroundService();
    var isRunning = await service.isRunning();
    
    if (isRunning) {
      service.invoke("stopService");
    } else {
      await service.startService();
    }
    
    await Future.delayed(const Duration(milliseconds: 500));
    _checkServiceStatus();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Cognitive Memory"),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.memory, size: 100, color: Colors.deepPurpleAccent),
            const SizedBox(height: 20),
            Text(
              _isServiceRunning ? "Tracking is Active" : "Tracking is Stopped",
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 40),
            ElevatedButton.icon(
              onPressed: _toggleService,
              icon: Icon(_isServiceRunning ? Icons.stop : Icons.play_arrow),
              label: Text(_isServiceRunning ? "Stop Tracking" : "Start Tracking"),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
            ),
            const SizedBox(height: 20),
            OutlinedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => const TimelineScreen()),
                );
              },
              child: const Text("View Memory Timeline"),
            ),
          ],
        ),
      ),
    );
  }
}

class TimelineScreen extends StatefulWidget {
  const TimelineScreen({super.key});

  @override
  State<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends State<TimelineScreen> {
  List<Map<String, dynamic>> _events = [];

  @override
  void initState() {
    super.initState();
    _loadEvents();
    
    // Listen for updates from background service
    FlutterBackgroundService().on('update').listen((event) {
      if (mounted) _loadEvents();
    });
  }

  Future<void> _loadEvents() async {
    final events = await DatabaseHelper().getEvents();
    setState(() {
      _events = events;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Memory Timeline"),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadEvents,
          ),
        ],
      ),
      body: _events.isEmpty
          ? const Center(child: Text("No memory events yet."))
          : ListView.builder(
              itemCount: _events.length,
              itemBuilder: (context, index) {
                final event = _events[index];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: ListTile(
                    leading: const Icon(Icons.history),
                    title: Text(event['app_name'] ?? "Unknown App"),
                    subtitle: Text(event['activity'] ?? "App opened"),
                    trailing: Text(
                      event['timestamp'] ?? "",
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
