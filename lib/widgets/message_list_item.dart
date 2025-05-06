import 'package:flutter/material.dart';
import '../models/message_data.dart';
import 'package:intl/intl.dart';

class MessageListItem extends StatelessWidget {
  final MessageData messageData;
  final VoidCallback onTap;

  const MessageListItem({
    Key? key,
    required this.messageData,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('HH:mm:ss dd/MM/yyyy');
    
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: ListTile(
        title: Text(
          'Amount: ${messageData.amount}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              messageData.content.length > 30 
                ? '${messageData.content.substring(0, 30)}...' 
                : messageData.content,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              'Received: ${dateFormat.format(messageData.timestamp)}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        onTap: onTap,
      ),
    );
  }
}