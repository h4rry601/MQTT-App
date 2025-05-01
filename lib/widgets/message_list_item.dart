import 'package:flutter/material.dart';
import '../models/message_data.dart';

class MessageListItem extends StatelessWidget {
  final MessageData message;
  final VoidCallback onTap;

  const MessageListItem({
    super.key,
    required this.message,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isSuccess = message.result?.toLowerCase() == 'success';
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        onTap: onTap,
        title: Text(
          'UUID: ${message.uuid.isEmpty ? 'N/A' : message.uuid}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Time: ${message.formattedTimestamp}'),
            Text(
              'Result: ${message.result ?? 'N/A'}',
              style: TextStyle(
                color: isSuccess ? Colors.green : Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text('Interval: ${message.interval ?? 'N/A'}s'),
            Text('Amount: ${message.amount}'),
            Text('Content: ${message.content}'),
          ],
        ),
      ),
    );
  }
}