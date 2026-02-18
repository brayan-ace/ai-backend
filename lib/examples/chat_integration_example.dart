import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:io';
import '../services/api_service.dart';
import '../services/network_connectivity_service.dart';
import '../widgets/premium_error_notification.dart';
import '../utils/app_localizations.dart';
import '../utils/theme.dart';

/// Example Integration
/// How to use the premium internet error notification system
class ChatIntegrationExample extends StatefulWidget {
  const ChatIntegrationExample({Key? key}) : super(key: key);

  @override
  State<ChatIntegrationExample> createState() => _ChatIntegrationExampleState();
}

class _ChatIntegrationExampleState extends State<ChatIntegrationExample> {
  final NetworkConnectivityService _connectivity = NetworkConnectivityService();
  final TextEditingController _messageController = TextEditingController();
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _initializeConnectivity();
  }

  /// Initialize network monitoring
  Future<void> _initializeConnectivity() async {
    await _connectivity.initialize();
    // Listen to connection status changes
    _connectivity.connectionStatus.listen((isConnected) {
      if (!isConnected && mounted) {
        debugPrint('🌐 Network connection lost!');
      }
    });
  }

  /// Send message with premium error handling
  Future<void> _sendMessage(String message) async {
    if (message.isEmpty) return;

    // Check network before sending
    if (!_connectivity.isConnected) {
      if (mounted) {
        await showPremiumError(
          context,
          errorType: 'network',
          onRetry: () => _sendMessage(message),
        );
      }
      return;
    }

    setState(() => _isSending = true);
    _messageController.clear();

    try {
      // Send via API service
      final response = await ApiService.send('chat', {'message': message});
      if (mounted) {
        // Show success or add message to UI
        debugPrint('✅ Message sent successfully: $response');
        // TODO: Add response to chat UI
      }
    } on TimeoutException catch (_) {
      // Handle timeout errors
      if (mounted) {
        await showPremiumError(
          context,
          errorType: 'timeout',
          onRetry: () => _sendMessage(message),
        );
      }
    } on SocketException catch (_) {
      // Handle network errors
      if (mounted) {
        await showPremiumError(
          context,
          errorType: 'network',
          customMessage: AppLocalizations.of(
            context,
          ).t('error.network.message'),
          onRetry: () => _sendMessage(message),
        );
      }
    } catch (e) {
      // Handle generic errors
      if (mounted) {
        String errorType = 'generic';
        if (e.toString().contains('500')) {
          errorType = 'server_error';
        } else if (e.toString().contains('timeout')) {
          errorType = 'timeout';
        }

        await showPremiumError(
          context,
          errorType: errorType,
          onRetry: () => _sendMessage(message),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _connectivity.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Chat Example'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: Container(
              // TODO: Add chat messages here
              child: Center(child: Text('Messages will appear here')),
            ),
          ),
          Container(
            padding: EdgeInsets.all(AppTheme.spaceMd),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Type your message...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      ),
                      filled: true,
                      fillColor: AppTheme.surfaceCard,
                    ),
                    enabled: !_isSending,
                  ),
                ),
                SizedBox(width: AppTheme.spaceSm),
                GestureDetector(
                  onTap: _isSending
                      ? null
                      : () => _sendMessage(_messageController.text),
                  child: Container(
                    padding: EdgeInsets.all(AppTheme.spaceMd),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: AppTheme.primaryGradient,
                      ),
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    ),
                    child: _isSending
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : Icon(Icons.send, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// ============================================================================
/// IMPLEMENTATION GUIDE
/// ============================================================================
///
/// Step 1: Add imports to your chat screen:
/// ```dart
/// import '../services/network_connectivity_service.dart';
/// import '../widgets/premium_error_notification.dart';
/// import 'dart:io'; // For SocketException and TimeoutException
/// ```
///
/// Step 2: Initialize network connectivity in initState():
/// ```dart
/// @override
/// void initState() {
///   super.initState();
///   final connectivity = NetworkConnectivityService();
///   connectivity.initialize();
/// }
/// ```
///
/// Step 3: Wrap your API calls with error handling:
/// ```dart
/// try {
///   final response = await ApiService.send('chat', {'message': message});
///   // Handle success
/// } on SocketException catch (_) {
///   await showPremiumError(
///     context,
///     errorType: 'network',
///     onRetry: () => _sendMessage(message),
///   );
/// } catch (e) {
///   await showPremiumError(
///     context,
///     errorType: 'generic',
///     onRetry: () => _sendMessage(message),
///   );
/// }
/// ```
///
/// Step 4: Available error types:
/// - 'network': No internet connection (red theme)
/// - 'timeout': Request timeout (orange theme)
/// - 'server_error': Server error (purple theme)
/// - 'generic': Generic errors (indigo theme)
///
/// Step 5: Customization options:
/// - customMessage: Override the default message
/// - onRetry: Callback when user taps retry
/// - displayDuration: How long to show error (default 6s)
///
/// Step 6: Localization:
/// All error messages are automatically localized through AppLocalizations
/// Error strings available in all languages: en, es, fr, hi, ar
/// Update localization files to add custom messages
///
