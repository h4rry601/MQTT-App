import 'package:flutter/material.dart';
import '../models/message_data.dart';

class DetailScreen extends StatelessWidget {
  final MessageData message;

  const DetailScreen({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final isSuccess = message.result?.toLowerCase() == 'success';
    return Scaffold(
      appBar: AppBar(title: const Text('Message Details')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'UUID: ${message.uuid.isEmpty ? 'N/A' : message.uuid}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text('Time: ${message.formattedTimestamp}', style: const TextStyle(fontSize: 16)),
            Text(
              'Result: ${message.result ?? 'N/A'}',
              style: TextStyle(
                fontSize: 16,
                color: isSuccess ? Colors.green : Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text('Interval: ${message.interval ?? 'N/A'}s', style: const TextStyle(fontSize: 16)),
            Text('Amount: ${message.amount}', style: const TextStyle(fontSize: 16)),
            Text('Content: ${message.content}', style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 16),
            Text('Raw Payload: ${message.rawPayload}', style: const TextStyle(fontSize: 14, color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}