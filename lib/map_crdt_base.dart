part of 'map_crdt_tree.dart';

abstract class _MapCrdtBase<K, V> implements MapCrdt<K, V> {
  final Map<K, Record<V>> _records;

  _MapCrdtBase(this._records);

  _MapCrdtBase.from(
    _MapCrdtBase<K, V> other, {
    K Function(K)? cloneKey,
    V Function(V)? cloneValue,
  }) : _records = Map.from(other._records).map((key, value) => MapEntry(
              cloneKey != null ? cloneKey(key) : key,
              Record<V>.from(value, cloneValue: cloneValue),
            ));

  @override
  Map<K, Record<V>> get records => _records;

  @override
  Map<K, V> get map => (Map<K, Record<V>>.from(_records)
        ..removeWhere((key, value) => value.isDeleted))
      .map((key, value) => MapEntry(key, value.value!));

  @override
  Iterable<V> get values => (List<Record<V>>.from(_records.values)
        ..removeWhere((record) => record.isDeleted))
      .map((record) => record.value!);

  @override
  Record<V>? getRecord(K key) => _records[key];

  @override
  V? get(K key) => getRecord(key)?.value;

  @override
  void updateRecords(Record<V> Function(K, Record<V>) updateRecord) {
    _records.updateAll((key, record) => updateRecord(key, record));
  }

  @override
  void updateRecord(K key, Record<V> Function(Record<V>) updateRecord) {
    _records.update(key, updateRecord);
  }

  @override
  void updateValues(V Function(K, V) updateValue) {
    _records.updateAll((k, record) => record.isDeleted
        ? record
        : Record(clock: record.clock, value: updateValue(k, record.value!)));
  }

  @override
  void updateValue(K key, V Function(V) updateRecord) {
    _records.update(
      key,
      (record) => record.isDeleted
          ? record
          : Record(clock: record.clock, value: updateRecord(record.value!)),
    );
  }

  @override
  Map<String, dynamic> recordsToJson({
    String Function(K)? keyEncode,
    dynamic Function(V)? valueEncode,
  }) {
    return _records.map((key, value) => MapEntry(
          keyEncode != null ? keyEncode(key) : key as String,
          value.toJson(valueEncode: valueEncode),
        ));
  }

  static Map<K, Record<V>> recordsFromJson<K, V>(
    Map json, {
    K Function(dynamic)? keyDecode,
    V Function(dynamic)? valueDecode,
  }) {
    return json.map((key, value) => MapEntry(
          keyDecode != null ? keyDecode(key) : key as K,
          Record<V>.fromJson(
            value as Map<String, dynamic>,
            valueDecode: valueDecode,
          ),
        ));
  }

  /// Merge records with other records and updates [vectorClock].
  /// Assumes all records have been updated to contain nodes [this] and [other].
  /// Important: Records of [other] will be changed. Use MapCrdt.from(other, cloneKey: ..., cloneValue: ...) to keep them intact.
  void _mergeRecords(
    MapCrdt<K, V> other,
    VectorClock vectorClock,
    MapCrdtRoot root,
  ) {
    final updatedRecords = other.records
      ..removeWhere((key, record) {
        vectorClock.merge(record.clock.vectorClock);
        final localRecord = _records[key];

        if (localRecord == null) return false;
        final value = record.value;
        final localValue = localRecord.value;
        if (localValue is MapCrdt &&
            value.runtimeType == localValue.runtimeType) {
          localValue.merge(value as MapCrdt);

          return true;
        } else if (localValue == null && value is MapCrdt) {
          return _forEveryRecordRecursive(
            value!,
            (record) => localRecord.clock >= record.clock,
          );
        } else {
          return localRecord.clock >= record.clock;
        }
      })
      ..map((key, value) =>
          MapEntry(key, _updateNodeParentIfNecessary(value, root)));
    _records.addAll(updatedRecords);
  }

  Record<V> _updateNodeParentIfNecessary(Record<V> record, MapCrdtRoot root) {
    if (record.isDeleted) return record;
    final value = record.value;
    if (value is MapCrdtNode) value._root = root;

    return record;
  }

  bool _forEveryRecordRecursive(MapCrdt crdt, bool Function(Record) test) {
    return crdt.records.values.every((record) {
      if (!test(record)) return false;
      final value = record.value;
      if (value is _MapCrdtBase) {
        if (!value._forEveryRecordRecursive(value, test)) return false;
      }

      return true;
    });
  }

  void _validateRecord(Record record, MapCrdtRoot root) {
    if (!containsNode(record.clock.node)) {
      throw ArgumentError(
        'node list doesn\'t contain the node of the record',
      );
    }
    if (record.clock.vectorClock.numNodes != vectorClock.numNodes) {
      throw ArgumentError(
        'record vector clock does not have the same number of nodes as this crdt',
      );
    }
    if (!record.isDeleted && record.value is MapCrdt) {
      MapCrdt subRecord = record.value!;
      if (subRecord.root != root) {
        throw ArgumentError('a node has an invalid root node');
      }
      subRecord.records.values
          .forEach((record) => subRecord.validateRecord(record));
    }
  }

  @override
  void insertClockValue(int pos, [int initialClockValue = 0]) {
    _records.values.forEach((record) {
      record.clock.vectorClock.insertClockValue(pos, initialClockValue);
      final value = record.value;
      if (value is MapCrdt) value.insertClockValue(pos, initialClockValue);
    });
  }
}
