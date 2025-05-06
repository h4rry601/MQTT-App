import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/mqtt_provider.dart';
import '../widgets/message_list_item.dart';
import 'detail_screen.dart';

class ResultsScreen extends StatefulWidget {
  const ResultsScreen({Key? key}) : super(key: key);

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen> {
  @override
  void initState() {
    super.initState();
    // Connect to MQTT when the screen initializes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final mqttProvider = Provider.of<MqttProvider>(context, listen: false);
      mqttProvider.connect();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Received Messages'),
        actions: [
          // Refresh button
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                // This will trigger a rebuild
              });
            },
            tooltip: 'Refresh',
          ),
          // Status indicator for MQTT connection
          Consumer<MqttProvider>(
            builder: (context, mqttProvider, _) => Padding(
              padding: const EdgeInsets.all(8.0),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: mqttProvider.isConnected ? Colors.green : Colors.red,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    mqttProvider.isConnected ? 'Connected' : 'Disconnected',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Connection status banner
          Consumer<MqttProvider>(
            builder: (context, mqttProvider, _) => Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10),
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: mqttProvider.isConnected ? Colors.green.shade100 : Colors.red.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: mqttProvider.isConnected ? Colors.green : Colors.red,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    mqttProvider.isConnected ? Icons.cloud_done : Icons.cloud_off,
                    color: mqttProvider.isConnected ? Colors.green : Colors.red,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    mqttProvider.isConnected 
                        ? 'Connected to MQTT Server (Topic: test/rep)'
                        : 'Disconnected from MQTT Server',
                    style: TextStyle(
                      color: mqttProvider.isConnected ? Colors.green.shade700 : Colors.red.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Messages list
          Expanded(
            child: Consumer<MqttProvider>(
              builder: (context, mqttProvider, _) {
                final messages = mqttProvider.receivedMessages;
                
                if (messages.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.inbox_outlined,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No messages received yet',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (!mqttProvider.isConnected)
                    Text(
                      'MQTT is disconnected',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.red[400],
                      ),
                    ),
                ],
              ),
            );
                }
                
                return RefreshIndicator(
                  onRefresh: () async {
                    // Pull to refresh functionality
                    setState(() {});
                    return Future.delayed(const Duration(milliseconds: 300));
                  },
                  child: ListView.builder(
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      // Display messages in reverse order (newest first)
                      final message = messages[messages.length - 1 - index];
                      
                      return MessageListItem(
                        messageData: message,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => DetailScreen(messageData: message),
                            ),
                          );
                        },
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}