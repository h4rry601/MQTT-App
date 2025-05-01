// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/mqtt_provider.dart';
import '../models/message_data.dart';
import '../widgets/message_list_item.dart';

class ResultsScreen extends StatelessWidget {
  const ResultsScreen({super.key});

  void _navigateToDetail(BuildContext context, MessageData message) {
    Navigator.pushNamed(context, '/details', arguments: message);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<MqttProvider>(
      builder: (context, mqttProvider, child) {
        final messages = mqttProvider.receivedMessages;

        return Scaffold(
          body: RefreshIndicator(
            onRefresh: () async {
              await Future.delayed(const Duration(milliseconds: 500));
            },
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(12.0),
                  color: Colors.blue.withOpacity(0.1),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Trạng thái: ${_getConnectionStatusText(mqttProvider.connectionState)}',
                        style: TextStyle(
                          fontSize: 14, 
                          color: _getConnectionStatusColor(mqttProvider.connectionState),
                          fontWeight: FontWeight.bold
                        ),
                      ),
                      Text(
                        'Tin nhắn: ${messages.length}',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                if (!mqttProvider.isConnected)
                  Expanded(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.signal_wifi_off, size: 50, color: Colors.grey),
                          const SizedBox(height: 16),
                          const Text(
                            'MQTT đã ngắt kết nối. Đang chờ kết nối...',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: () {
                              mqttProvider.connect();
                            },
                            icon: const Icon(Icons.refresh),
                            label: const Text('Kết nối lại'),
                          ),
                        ],
                      ),
                    ),
                  )
                else if (messages.isEmpty)
                  Expanded(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.hourglass_empty, size: 50, color: Colors.grey),
                          const SizedBox(height: 16),
                          const Text(
                            'Đang chờ tin nhắn trên topic: test/rep...',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Gửi dữ liệu từ màn hình Input Data để nhận kết quả',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 14, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: ListView.builder(
                      key: ValueKey(messages.length),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final message = messages[index];
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                          margin: EdgeInsets.only(
                            top: index == 0 ? 8.0 : 4.0,
                            bottom: 4.0,
                            left: 8.0,
                            right: 8.0,
                          ),
                          child: MessageListItem(
                            message: message,
                            onTap: () => _navigateToDetail(context, message),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _getConnectionStatusText(MqttConnectionState state) {
    switch (state) {
      case MqttConnectionState.connected:
        return 'Đã kết nối';
      case MqttConnectionState.connecting:
        return 'Đang kết nối...';
      case MqttConnectionState.disconnected:
        return 'Đã ngắt kết nối';
      }
  }

  Color _getConnectionStatusColor(MqttConnectionState state) {
    switch (state) {
      case MqttConnectionState.connected:
        return Colors.green;
      case MqttConnectionState.connecting:
        return Colors.orange;
      case MqttConnectionState.disconnected:
        return Colors.red;
      }
  }
}