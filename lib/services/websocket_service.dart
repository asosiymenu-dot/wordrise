import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'api_service.dart'; // For logging or error handling if needed

class WebSocketService {
  WebSocketService(this.baseUrl);

  final String baseUrl;
  
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  
  bool _isConnected = false;
  bool get isConnected => _isConnected;

  String? _authToken;

  // Connection parameters
  int _retryCount = 0;
  Timer? _reconnectTimer;
  final int _maxRetries = 10;
  
  final _eventController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get events => _eventController.stream;

  void connect(String token) {
    _authToken = token;
    _retryCount = 0;
    _connectInternal();
  }

  void _connectInternal() {
    if (_isConnected) return;
    
    // Convert http/https to ws/wss
    final wsUrl = baseUrl
        .replaceFirst('https://', 'wss://')
        .replaceFirst('http://', 'ws://')
        .replaceAll('/v1', '/ws'); // Adjust based on Nginx configuration
        
    // If testing locally on Android emulator to a local PHP server, adjust the port
    // For now, we assume it's running on port 8080 or proxied via Nginx.
    final uri = Uri.parse(wsUrl);
    
    try {
      _channel = WebSocketChannel.connect(uri);
      
      _channel!.ready.then((_) {
        if (_authToken != null) {
          _channel!.sink.add(jsonEncode({
            'type': 'auth',
            'token': _authToken,
          }));
        }
        
        if (_retryCount > 0) {
          _eventController.add({'type': 'reconnected'});
        }
      }).catchError((dynamic e) {
         _onError(e);
      });

      _subscription = _channel!.stream.listen(
        _onMessage,
        onError: _onError,
        onDone: _onDone,
        cancelOnError: false,
      );
    } catch (e) {
      _onError(e);
    }
  }

  void _onMessage(dynamic message) {
    _isConnected = true;
    _retryCount = 0; // Reset retries on successful communication
    
    try {
      final data = jsonDecode(message as String) as Map<String, dynamic>;
      _eventController.add(data);
    } catch (e) {
      debugPrint('WebSocket message decode error: $e');
    }
  }

  void _onError(dynamic error) {
    debugPrint('WebSocket Error: $error');
    _isConnected = false;
    _scheduleReconnect();
  }

  void _onDone() {
    debugPrint('WebSocket Disconnected');
    _isConnected = false;
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_authToken == null) return; // Don't reconnect if we intentionally disconnected (e.g., logout)
    
    if (_retryCount >= _maxRetries) {
      debugPrint('WebSocket max retries reached.');
      return;
    }

    _reconnectTimer?.cancel();
    
    // Exponential backoff
    final delay = Duration(seconds: (2 ^ _retryCount).clamp(1, 60));
    _retryCount++;
    
    debugPrint('WebSocket reconnecting in ${delay.inSeconds} seconds (attempt $_retryCount)');
    _reconnectTimer = Timer(delay, _connectInternal);
  }

  void disconnect() {
    _authToken = null;
    _reconnectTimer?.cancel();
    _subscription?.cancel();
    _channel?.sink.close();
    _isConnected = false;
  }

  void dispose() {
    disconnect();
    _eventController.close();
  }
}
