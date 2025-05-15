import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MQTT Flutter App',
      theme: ThemeData(
        primarySwatch: Colors.deepPurple,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const MqttHomePage(),
    );
  }
}

class MqttHomePage extends StatefulWidget {
  const MqttHomePage({super.key});
  @override
  State<MqttHomePage> createState() => _MqttHomePageState();
}

class _MqttHomePageState extends State<MqttHomePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  final Set<String> sentUUIDs = {}; // Danh sách UUID đã gửi

  final String broker = '192.168.1.24';
  final int port = 31883;
  final String username = 'test';
  final String password = 'Abc@123';
  final String publishTopic = 'test/req';
  final String subscribeTopic = 'test/rep';

  late MqttServerClient client;
  bool isConnected = false;

  List<Map<String, dynamic>> receivedMessages = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _connectMQTT();
  }

  Future<void> _connectMQTT() async {
    client = MqttServerClient(broker, '');
    client.port = port;
    client.logging(on: false);
    client.keepAlivePeriod = 20;
    client.onDisconnected = _onDisconnected;
    client.secure = false;
    client.autoReconnect = true;
    client.onConnected = _onConnected;
    client.onSubscribed = _onSubscribed;

    final connMessage = MqttConnectMessage()
        .withClientIdentifier(
          'flutter_client_${DateTime.now().millisecondsSinceEpoch}',
        )
        .authenticateAs(username, password)
        .startClean()
        .withWillQos(MqttQos.atLeastOnce);

    client.connectionMessage = connMessage;

    try {
      final status = await client.connect();
      if (status?.state == MqttConnectionState.connected) {
        setState(() {
          isConnected = true;
        });
        client.subscribe(subscribeTopic, MqttQos.atLeastOnce);
        client.updates!.listen(_onMessage);
      } else {
        _disconnect();
      }
    } catch (e) {
      debugPrint('Exception: $e');
      _disconnect();
    }
  }

  void _onConnected() {
    debugPrint('Connected to MQTT broker');
    setState(() {
      isConnected = true;
    });
  }

  void _onDisconnected() {
    debugPrint('Disconnected from MQTT broker');
    setState(() {
      isConnected = false;
    });
  }

  void _onSubscribed(String topic) {
    debugPrint('Subscribed to $topic');
  }

  void _disconnect() {
    client.disconnect();
    setState(() {
      isConnected = false;
    });
  }

  void _onMessage(List<MqttReceivedMessage<MqttMessage>> event) {
    final recMess = event[0].payload as MqttPublishMessage;
    var payload = MqttPublishPayload.bytesToStringAsString(
      recMess.payload.message,
    );

    payload = payload.trim();
    debugPrint('Received raw payload: $payload');

    try {
      String formattedPayload = payload
          .replaceAll("'", "\"")
          .replaceAll("True", "true")
          .replaceAll("False", "false");
      final jsonData = json.decode(formattedPayload);

      if (jsonData is Map<String, dynamic>) {
        // Chỉ xử lý tin nhắn có UUID nằm trong danh sách đã gửi
        if (sentUUIDs.contains(jsonData['UUID'])) {
          String formattedTimeStamp;
          if (jsonData['TimeStamp'] is String) {
            // Xử lý TimeStamp dạng chuỗi YYYYMMDDHHmmss
            String rawTimeStamp = jsonData['TimeStamp'];
            formattedTimeStamp =
                "${rawTimeStamp.substring(6, 8)}-${rawTimeStamp.substring(4, 6)}-${rawTimeStamp.substring(0, 4)} ${rawTimeStamp.substring(8, 10)}:${rawTimeStamp.substring(10, 12)}:${rawTimeStamp.substring(12, 14)}";
          } else {
            // Xử lý TimeStamp dạng số nguyên (UNIX timestamp)
            int unixTimestamp = jsonData['TimeStamp'];
            DateTime dateTime = DateTime.fromMillisecondsSinceEpoch(
              unixTimestamp * 1000,
            );
            formattedTimeStamp =
                "${dateTime.day.toString().padLeft(2, '0')}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.year} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}:${dateTime.second.toString().padLeft(2, '0')}";
          }

          Color resultColor = jsonData['Result'] ? Colors.green : Colors.red;

          setState(() {
            receivedMessages.insert(0, {
              'UUID': jsonData['UUID'],
              'Amount': jsonData['Amount'],
              'Content': jsonData['Content'],
              'TimeStamp': formattedTimeStamp,
              'Interval': jsonData['Interval'],
              'Result': jsonData['Result'],
              'ResultColor': resultColor,
            });
          });
        }
      }
    } catch (e) {
      debugPrint('Lỗi xử lý JSON: $e');
      debugPrint('Payload lỗi: $payload');
    }
  }

  Future<String?> _getNewUUID() async {
    try {
      final response = await http.get(
        Uri.parse('http://192.168.1.24:31501/uuid'),
      );
      if (response.statusCode == 200) {
        // Parse JSON response
        final Map<String, dynamic> jsonResponse = json.decode(response.body);
        if (jsonResponse['result'] == 'success' &&
            jsonResponse['uuid'] != null) {
          return jsonResponse['uuid'];
        } else {
          debugPrint('Lỗi khi lấy UUID: Response không hợp lệ');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Lỗi khi lấy UUID: Response không hợp lệ'),
              ),
            );
          }
        }
      } else {
        debugPrint('Lỗi khi lấy UUID: ${response.statusCode}');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Lỗi khi lấy UUID: ${response.statusCode}')),
          );
        }
      }
    } catch (e) {
      debugPrint('Lỗi kết nối API UUID: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Lỗi kết nối API UUID: $e')));
      }
    }
    return null;
  }

  void _publishMessage() async {
    if (!isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chưa kết nối đến MQTT broker')),
      );
      return;
    }

    final amountText = _amountController.text.trim();
    final contentText = _contentController.text.trim();

    int? amount = int.tryParse(amountText);
    if (amount == null || amount < 1 || amount > 1000) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Amount must be a number between 1 and 1000'),
        ),
      );
      return;
    }

    if (contentText.isEmpty || contentText.length > 50) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Content must be non-empty and maximum 50 characters'),
        ),
      );
      return;
    }

    // Lấy UUID mới mỗi khi gửi tin nhắn
    final newUUID = await _getNewUUID();
    if (newUUID == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không thể lấy UUID. Vui lòng thử lại.'),
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    // Thêm UUID mới vào danh sách
    setState(() {
      sentUUIDs.add(newUUID);
    });

    final messageJson = json.encode({
      'UUID': newUUID,
      'Amount': amount,
      'Content': contentText,
    });

    final builder = MqttClientPayloadBuilder();
    builder.addString(messageJson);

    client.publishMessage(publishTopic, MqttQos.atLeastOnce, builder.payload!);

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Message published')));

    _amountController.clear();
    _contentController.clear();
  }

  void _showMessageDetails(Map<String, dynamic> message) {
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Message Details'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('UUID: ${message['UUID']}'),
                Text('Amount: ${message['Amount']}'),
                Text('Content: ${message['Content']}'),
                Text('TimeStamp: ${message['TimeStamp']}'),
                Text('Interval: ${message['Interval']} giây'),
                Text(
                  'Result: ${message['Result'] ? "Thành công" : "Thất bại"}',
                  style: TextStyle(color: message['ResultColor']),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                },
                child: const Text('Close'),
              ),
            ],
          ),
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    _contentController.dispose();
    _disconnect();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MQTT Flutter App'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.publish), text: 'Update Data'),
            Tab(icon: Icon(Icons.list), text: 'Results'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildUpdateDataTab(), _buildResultsTab()],
      ),
    );
  }

  Widget _buildUpdateDataTab() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _amountController,
              decoration: const InputDecoration(
                labelText: 'Amount',
                hintText: 'Enter an integer (1-1000)',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              maxLength: 4,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _contentController,
              decoration: const InputDecoration(
                labelText: 'Content',
                hintText: 'Enter content (max 50 chars)',
                border: OutlineInputBorder(),
              ),
              maxLength: 50,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _publishMessage,
              icon: const Icon(Icons.send),
              label: const Text('Send Data'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  vertical: 14,
                  horizontal: 24,
                ),
                textStyle: const TextStyle(fontSize: 18),
              ),
            ),
            const SizedBox(height: 16),
            isConnected
                ? Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.check_circle, color: Colors.green),
                    SizedBox(width: 8),
                    Text('Connected to MQTT broker'),
                  ],
                )
                : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.error, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Disconnected'),
                  ],
                ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultsTab() {
    return receivedMessages.isEmpty
        ? const Center(
          child: Text(
            'Waiting for data from MQTT...',
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),
        )
        : ListView.builder(
          itemCount: receivedMessages.length,
          itemBuilder: (ctx, index) {
            final message = receivedMessages[index];
            return Card(
              margin: const EdgeInsets.all(8),
              child: ListTile(
                title: Text('Amount: ${message['Amount']}'),
                subtitle: Text('Content: ${message['Content']}'),
                leading: Icon(Icons.message, color: message['ResultColor']),
                onTap: () => _showMessageDetails(message),
              ),
            );
          },
        );
  }
}
