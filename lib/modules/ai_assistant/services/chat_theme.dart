import 'package:flutter/material.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart';

final chatTheme = DefaultChatTheme(
  primaryColor: Colors.deepPurple,
  secondaryColor: Color(0xFFE8E8E8),
  inputBackgroundColor: Colors.white,
  inputTextColor: Colors.black87,
  backgroundColor: Color(0xFFF5F5F5),
  receivedMessageBodyTextStyle: const TextStyle(
    color: Colors.black87,
    fontSize: 16,
  ),
  sentMessageBodyTextStyle: const TextStyle(
    color: Colors.white,
    fontSize: 16,
  ),
);
