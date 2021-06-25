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
  void _mergeRecords(MapCrdt<K, V> other, VectorClock vectorClock) {
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
        } else {
          return localRecord.clock >= record.clock;
        }
      });
    _records.addAll(updatedRecords);
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
