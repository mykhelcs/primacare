import 'dart:async';
import 'package:flutter/foundation.dart';

enum SyncActionType {
  dispenseItem,
  receiveStock,
  createPatient,
  markPaid,
}

class PendingSyncAction {
  final String id;
  final SyncActionType type;
  final Map<String, dynamic> payload;
  final DateTime createdAt;

  const PendingSyncAction({
    required this.id,
    required this.type,
    required this.payload,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type.name,
      'payload': payload,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory PendingSyncAction.fromMap(Map<String, dynamic> map) {
    return PendingSyncAction(
      id: map['id'] as String,
      type: SyncActionType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => SyncActionType.dispenseItem,
      ),
      payload: Map<String, dynamic>.from(map['payload'] as Map),
      createdAt: DateTime.tryParse(map['createdAt'] as String? ?? '') ?? DateTime.now(),
    );
  }
}

class OfflineSyncService extends ChangeNotifier {
  static final OfflineSyncService _instance = OfflineSyncService._internal();
  factory OfflineSyncService() => _instance;
  OfflineSyncService._internal();

  final List<PendingSyncAction> _pendingQueue = [];
  bool _isOnline = true;
  bool _isSyncing = false;

  bool get isOnline => _isOnline;
  bool get isSyncing => _isSyncing;
  int get pendingCount => _pendingQueue.length;
  List<PendingSyncAction> get queue => List.unmodifiable(_pendingQueue);

  void setConnectivity(bool online) {
    _isOnline = online;
    notifyListeners();
  }

  void enqueueAction({
    required SyncActionType type,
    required Map<String, dynamic> payload,
  }) {
    final action = PendingSyncAction(
      id: 'sync-${DateTime.now().millisecondsSinceEpoch}-${_pendingQueue.length}',
      type: type,
      payload: payload,
      createdAt: DateTime.now(),
    );
    _pendingQueue.add(action);
    notifyListeners();

    if (_isOnline) {
      flushPendingQueue();
    }
  }

  Future<void> flushPendingQueue({
    Future<bool> Function(PendingSyncAction action)? handler,
  }) async {
    if (_isSyncing || _pendingQueue.isEmpty) return;

    _isSyncing = true;
    notifyListeners();

    try {
      final toProcess = List<PendingSyncAction>.from(_pendingQueue);
      for (final action in toProcess) {
        bool success = true;
        if (handler != null) {
          success = await handler(action);
        } else {
          // Default mock flush delay
          await Future.delayed(const Duration(milliseconds: 300));
        }

        if (success) {
          _pendingQueue.removeWhere((item) => item.id == action.id);
        }
      }
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  void clearQueue() {
    _pendingQueue.clear();
    notifyListeners();
  }
}
