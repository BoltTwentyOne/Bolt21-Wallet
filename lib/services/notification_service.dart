import 'dart:async';
import 'backends/lightning_backend.dart';
import '../utils/secure_logger.dart';

/// Service for handling payment notifications
class NotificationService {
  static final NotificationService instance = NotificationService._();
  NotificationService._();

  StreamSubscription? _subscription;

  /// Subscribe to SDK events for payment notifications
  void subscribeToPayments(Stream<BackendEvent> eventStream) {
    _subscription?.cancel();
    _subscription = eventStream.listen((event) {
      _handleEvent(event);
    });
    SecureLogger.info('Subscribed to payment notifications', tag: 'Notify');
  }

  void _handleEvent(BackendEvent event) {
    // Handle payment-related events
    if (event is PaymentReceivedEvent) {
      SecureLogger.info(
        'Payment received: ${event.payment.amountSat} sats',
        tag: 'Notify',
      );
    } else if (event is PaymentSentEvent) {
      SecureLogger.info(
        'Payment sent: ${event.payment.amountSat} sats',
        tag: 'Notify',
      );
    } else if (event is PaymentFailedEvent) {
      SecureLogger.warn(
        'Payment failed: ${event.payment.amountSat} sats',
        tag: 'Notify',
      );
    } else if (event is SyncedEvent) {
      SecureLogger.info(
        'Wallet synced',
        tag: 'Notify',
      );
    }
  }

  /// Unsubscribe from payment events
  void unsubscribe() {
    _subscription?.cancel();
    _subscription = null;
  }
}
