enum SyncAction { create, update, delete }

extension SyncActionX on SyncAction {
  String get value => name.toUpperCase();
  static SyncAction fromValue(String v) =>
      SyncAction.values.firstWhere((e) => e.value == v, orElse: () => SyncAction.update);
}

/// Local-only row (see design doc §2: "sync_queue ... không đồng bộ lên
/// server"). Tracks pending offline writes until they're pushed via
/// POST /sync/push.
class SyncQueueItem {
  final String id;
  final String tableName;
  final String recordId;
  final SyncAction action;
  final bool isSynced;
  final DateTime createdAt;

  SyncQueueItem({
    required this.id,
    required this.tableName,
    required this.recordId,
    required this.action,
    this.isSynced = false,
    required this.createdAt,
  });

  factory SyncQueueItem.fromMap(Map<String, dynamic> map) => SyncQueueItem(
        id: map['id'],
        tableName: map['table_name'],
        recordId: map['record_id'],
        action: SyncActionX.fromValue(map['action']),
        isSynced: (map['is_synced'] as int? ?? 0) == 1,
        createdAt: DateTime.parse(map['created_at']),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'table_name': tableName,
        'record_id': recordId,
        'action': action.value,
        'is_synced': isSynced ? 1 : 0,
        'created_at': createdAt.toIso8601String(),
      };
}
