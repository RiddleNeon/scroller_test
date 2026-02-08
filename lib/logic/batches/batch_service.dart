import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirestoreBatchQueue {
  static final FirestoreBatchQueue instance = FirestoreBatchQueue._internal();
  factory FirestoreBatchQueue() => instance;
  FirestoreBatchQueue._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final List<_BatchOperation> _pendingOperations = [];
  Timer? _commitTimer;

  static const Duration _batchDelay = Duration(seconds: 5);
  static const int _maxBatchSize = 500;
  static const int _autoCommitThreshold = 400;

  bool _isCommitting = false;

  void set(DocumentReference ref, Map<String, dynamic> data, {bool merge = false}) {
    _pendingOperations.add(_BatchOperation(
      type: _OperationType.set,
      reference: ref,
      data: data,
      merge: merge,
    ));

    _scheduleCommit();
  }

  void update(DocumentReference ref, Map<String, dynamic> data) {
    _pendingOperations.add(_BatchOperation(
      type: _OperationType.update,
      reference: ref,
      data: data,
    ));

    _scheduleCommit();
  }

  void delete(DocumentReference ref) {
    _pendingOperations.add(_BatchOperation(
      type: _OperationType.delete,
      reference: ref,
    ));

    _scheduleCommit();
  }

  void _scheduleCommit() {
    _commitTimer?.cancel();

    if (_pendingOperations.length >= _autoCommitThreshold) {
      _commitBatch();
      return;
    }

    _commitTimer = Timer(_batchDelay, () {
      _commitBatch();
    });
  }

  Future<void> commit() async {
    _commitTimer?.cancel();
    await _commitBatch();
  }

  Future<void> _commitBatch() async {
    if (_isCommitting || _pendingOperations.isEmpty) return;

    _isCommitting = true;

    try {
      final operationsToCommit = List<_BatchOperation>.from(_pendingOperations);
      _pendingOperations.clear();

      final optimizedOps = _optimizeOperations(operationsToCommit);

      final chunks = _splitIntoChunks(optimizedOps, _maxBatchSize);

      for (final chunk in chunks) {
        await _commitChunk(chunk);
      }
    } catch (e) {
      print('Error committing batch: $e');
    } finally {
      _isCommitting = false;
    }
  }

  List<_BatchOperation> _optimizeOperations(List<_BatchOperation> operations) {
    // Group operations by document path
    final Map<String, List<_BatchOperation>> grouped = {};

    for (final op in operations) {
      final path = op.reference.path;
      grouped.putIfAbsent(path, () => []);
      grouped[path]!.add(op);
    }

    final optimized = <_BatchOperation>[];

    for (final entry in grouped.entries) {
      final ops = entry.value;

      if (ops.length == 1) {
        // Single operation, keep as is
        optimized.add(ops.first);
        continue;
      }

      // Multiple operations on same document
      // Strategy: Keep only the last operation, but merge update data
      final lastOp = ops.last;

      if (lastOp.type == _OperationType.delete) {
        // If last operation is delete, ignore all previous operations
        optimized.add(lastOp);
      } else if (lastOp.type == _OperationType.update) {
        // Merge all update operations
        final mergedData = <String, dynamic>{};
        for (final op in ops.where((o) => o.type == _OperationType.update)) {
          mergedData.addAll(op.data ?? {});
        }

        optimized.add(_BatchOperation(
          type: _OperationType.update,
          reference: lastOp.reference,
          data: mergedData,
        ));
      } else {
        // Set operation
        optimized.add(lastOp);
      }
    }

    return optimized;
  }

  /// Split operations into chunks
  List<List<_BatchOperation>> _splitIntoChunks(
      List<_BatchOperation> operations,
      int chunkSize,
      ) {
    final chunks = <List<_BatchOperation>>[];

    for (var i = 0; i < operations.length; i += chunkSize) {
      final end = (i + chunkSize < operations.length)
          ? i + chunkSize
          : operations.length;
      chunks.add(operations.sublist(i, end));
    }

    return chunks;
  }

  /// Commit a single chunk of operations
  Future<void> _commitChunk(List<_BatchOperation> operations) async {
    final batch = _firestore.batch();

    for (final op in operations) {
      switch (op.type) {
        case _OperationType.set:
          if (op.merge) {
            batch.set(op.reference, op.data!, SetOptions(merge: true));
          } else {
            batch.set(op.reference, op.data!);
          }
          break;
        case _OperationType.update:
          batch.update(op.reference, op.data!);
          break;
        case _OperationType.delete:
          batch.delete(op.reference);
          break;
      }
    }

    await batch.commit();
  }

  /// Get current queue size
  int get queueSize => _pendingOperations.length;

  /// Check if there are pending operations
  bool get hasPendingOperations => _pendingOperations.isNotEmpty;

  /// Clear all pending operations (use with caution!)
  void clear() {
    _commitTimer?.cancel();
    _pendingOperations.clear();
  }
}

enum _OperationType {
  set,
  update,
  delete,
}

class _BatchOperation {
  final _OperationType type;
  final DocumentReference reference;
  final Map<String, dynamic>? data;
  final bool merge;

  _BatchOperation({
    required this.type,
    required this.reference,
    this.data,
    this.merge = false,
  });
}

/// Extension methods for easy batching
extension BatchQueueExtension on DocumentReference {
  void batchSet(Map<String, dynamic> data, {bool merge = false}) {
    FirestoreBatchQueue().set(this, data, merge: merge);
  }

  void batchUpdate(Map<String, dynamic> data) {
    FirestoreBatchQueue().update(this, data);
  }

  void batchDelete() {
    FirestoreBatchQueue().delete(this);
  }
}