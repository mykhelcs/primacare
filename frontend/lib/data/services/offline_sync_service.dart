import 'dart:async';
import 'dart:convert';
import 'dart:io';
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

/// Persistence contract for storing queued offline clinical actions across restarts.
abstract class OfflineQueueStorage {
  Future<String?> read();
  Future<void> write(String data);
  Future<void> clear();
}

/// File-backed JSON queue storage for desktop/mobile targets (safe no-op on Web).
class FileOfflineQueueStorage implements OfflineQueueStorage {
  final String fileName;

  FileOfflineQueueStorage({this.fileName = 'primacare_offline_queue.json'});

  File? _resolveFile() {
    if (kIsWeb) return null;
    try {
      return File('${Directory.systemTemp.path}${Platform.pathSeparator}$fileName');
    } catch (_) {
      return null;
    }
  }

  @override
  Future<String?> read() async {
    final file = _resolveFile();
    if (file == null) return null;
    try {
      if (!await file.exists()) return null;
      return await file.readAsString();
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> write(String data) async {
    final file = _resolveFile();
    if (file == null) return;
    try {
      await file.writeAsString(data, flush: true);
    } catch (_) {}
  }

  @override
  Future<void> clear() async {
    final file = _resolveFile();
    if (file == null) return;
    try {
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
  }
}

typedef SyncActionHandler = Future<bool> Function(PendingSyncAction action);

class OfflineSyncService extends ChangeNotifier {
  static final OfflineSyncService _instance = OfflineSyncService._internal(
    FileOfflineQueueStorage(),
  );
  factory OfflineSyncService() => _instance;

  /// Creates an isolated instance for deterministic unit testing.
  OfflineSyncService.isolated({OfflineQueueStorage? storage})
      : _storage = storage ?? FileOfflineQueueStorage();

  OfflineSyncService._internal(this._storage);

  final OfflineQueueStorage _storage;
  final List<PendingSyncAction> _pendingQueue = [];
  bool _isOnline = true;
  bool _isSyncing = false;
  SyncActionHandler? _defaultHandler;

  bool get isOnline => _isOnline;
  bool get isSyncing => _isSyncing;
  int get pendingCount => _pendingQueue.length;
  List<PendingSyncAction> get queue => List.unmodifiable(_pendingQueue);

  void registerDefaultHandler(SyncActionHandler? handler) {
    _defaultHandler = handler;
  }

  void setConnectivity(bool online) {
    _isOnline = online;
    notifyListeners();
    if (online && _pendingQueue.isNotEmpty && _defaultHandler != null) {
      unawaited(flushPendingQueue());
    }
  }

  Future<void> restoreQueue() async {
    final raw = await _storage.read();
    if (raw == null || raw.trim().isEmpty) return;
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      _pendingQueue
        ..clear()
        ..addAll(
          decoded.map(
            (e) => PendingSyncAction.fromMap(Map<String, dynamic>.from(e as Map)),
          ),
        );
      notifyListeners();
    } catch (_) {
      // Ignore corrupt persisted cache rather than crashing startup
    }
  }

  Future<void> _persistQueue() async {
    if (_pendingQueue.isEmpty) {
      await _storage.clear();
      return;
    }
    final encoded = jsonEncode(_pendingQueue.map((e) => e.toMap()).toList());
    await _storage.write(encoded);
  }

  void enqueueAction({
    required SyncActionType type,
    required Map<String, dynamic> payload,
  }) {
    unawaited(enqueueActionAndWait(type: type, payload: payload));
  }

  Future<void> enqueueActionAndWait({
    required SyncActionType type,
    required Map<String, dynamic> payload,
  }) async {
    final action = PendingSyncAction(
      id: 'sync-${DateTime.now().millisecondsSinceEpoch}-${_pendingQueue.length}',
      type: type,
      payload: payload,
      createdAt: DateTime.now(),
    );
    _pendingQueue.add(action);
    notifyListeners();
    await _persistQueue();

    if (_isOnline && _defaultHandler != null) {
      await flushPendingQueue();
    }
  }

  Future<void> flushPendingQueue({
    SyncActionHandler? handler,
  }) async {
    if (_isSyncing || _pendingQueue.isEmpty) return;

    final effectiveHandler = handler ?? _defaultHandler;
    _isSyncing = true;
    notifyListeners();

    try {
      final toProcess = List<PendingSyncAction>.from(_pendingQueue);
      for (final action in toProcess) {
        bool success = false;
        if (effectiveHandler != null) {
          try {
            success = await effectiveHandler(action);
          } catch (_) {
            success = false;
          }
        } else if (!kReleaseMode) {
          // Allow simulated flush only in debug/test when no handler is wired
          await Future.delayed(const Duration(milliseconds: 50));
          success = true;
        }

        if (success) {
          _pendingQueue.removeWhere((item) => item.id == action.id);
        }
      }
      await _persistQueue();
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  void clearQueue() {
    _pendingQueue.clear();
    notifyListeners();
    unawaited(_storage.clear());
  }
}
