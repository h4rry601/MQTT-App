import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:provider/provider.dart';
import 'providers/mqtt_provider.dart';
import 'screens/input_screen.dart';
import 'screens/results_screen.dart';
import 'screens/detail_screen.dart';
import 'models/message_data.dart';

void main() {
  // Thiết lập logging toàn cục
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((record) {
  });

  runApp(
    ChangeNotifierProvider(
      create: (context) => MqttProvider()..connect(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MQTT App Test',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const HomeScreen(),
        '/results': (context) => const ResultsScreen(),
        '/details': (context) {
          final message = ModalRoute.of(context)?.settings.arguments as MessageData?;
          return DetailScreen(
            message: message ??
                MessageData(
                  rawPayload: 'Error: Message data missing',
                  amount: 0,
                  content: 'N/A',
                ),
          );
        },
      },
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  static const List<Widget> _widgetOptions = <Widget>[
    InputScreen(),
    ResultsScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final connectionState = context.watch<MqttProvider>().connectionState;
    String statusText;
    Color statusColor;
    switch (connectionState) {
      case MqttConnectionState.connected:
        statusText = 'Connected';
        statusColor = Colors.green;
        break;
      case MqttConnectionState.connecting:
        statusText = 'Connecting...';
        statusColor = Colors.orange;
        break;
      case MqttConnectionState.disconnected:
        statusText = 'Disconnected';
        statusColor = Colors.red;
        break;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('MQTT Test App'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 15.0),
            child: Row(
              children: [
                Icon(Icons.circle, color: statusColor, size: 12),
                const SizedBox(width: 5),
                Text(statusText),
              ],
            ),
          ),
        ],
      ),
      body: Center(
        child: _widgetOptions.elementAt(_selectedIndex),
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.input),
            label: 'Input Data',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.list_alt),
            label: 'Results',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.blue,
        onTap: _onItemTapped,
      ),
    );
  }
}