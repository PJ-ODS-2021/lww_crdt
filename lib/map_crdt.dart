import 'dart:collection';

import 'package:collection/collection.dart';

import 'vector_clock.dart';
import 'record.dart';
import 'distributed_clock.dart';

class _MapCrdtBase<K, V> {
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

  Map<K, Record<V>> get records => _records;

  Map<K, V> get map => (Map<K, Record<V>>.from(_records)
        ..removeWhere((key, value) => value.isDeleted))
      .map((key, value) => MapEntry(key, value.value!));

  Iterable<V> get values => (List<Record<V>>.from(_records.values)
        ..removeWhere((record) => record.isDeleted))
      .map((record) => record.value!);

  Record<V>? getRecord(K key) => _records[key];
  V? get(K key) => getRecord(key)?.value;

  /// Merge records with other records and updates [vectorClock].
  /// Assumes all records have been updated to contain nodes [this] and [other].
  /// Important: Records of [other] will be changed. Use MapCrdt.from(other, cloneKey: ..., cloneValue: ...) to keep them intact.
  void _mergeRecords(_MapCrdtBase<K, V> other, VectorClock vectorClock) {
    final updatedRecords = other._records
      ..removeWhere((key, record) {
        vectorClock.merge(record.clock.vectorClock);
        final localRecord = _records[key];

        if (localRecord == null) return false;
        final value = record.value;
        final localValue = localRecord.value;
        if (localValue is MapCrdtNode &&
            value.runtimeType == localValue.runtimeType) {
          localValue.merge(value as MapCrdtNode);

          return true;
        } else {
          return localRecord.clock >= record.clock;
        }
      });
    _records.addAll(updatedRecords);
  }

  void _insertClockValue(int pos, [int initialClockValue = 0]) {
    _records.values.forEach((record) {
      record.clock.vectorClock.insertClockValue(pos, initialClockValue);
      final value = record.value;
      if (value is MapCrdtNode) value._insertClockValue(pos, initialClockValue);
    });
  }

  Map<String, dynamic> recordsToJson({
    Function(K)? keyEncode,
    Function(V)? valueEncode,
  }) {
    return _records.map((key, value) => MapEntry(
          keyEncode != null ? keyEncode(key) : key,
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
}

class MapCrdtNode<K, V> extends _MapCrdtBase<K, V> {
  final MapCrdt<dynamic, MapCrdtNode<K, V>> _parent;

  MapCrdtNode(
    this._parent, {
    Map<K, Record<V>>? records,
    bool validateRecord = true,
  }) : super(records ?? {}) {
    if (validateRecord) _parent._validateRecords(_records);
  }

  /// Warning: Doesn't clone the parent. Specify [parent] to use a new parent.
  MapCrdtNode.from(
    MapCrdtNode<K, V> other, {
    MapCrdt<dynamic, MapCrdtNode<K, V>>? parent,
    K Function(K)? cloneKey,
    V Function(V)? cloneValue,
  })  : _parent = parent ?? other._parent,
        super.from(other, cloneKey: cloneKey, cloneValue: cloneValue);

  MapCrdt<dynamic, MapCrdtNode<K, V>> get parent => _parent;

  /// Important: Records of [other] will be changed. Use MapCrdt.from(other, cloneKey: ..., cloneValue: ...) to keep them intact.
  void merge(MapCrdtNode<K, V> other, {bool mergeParentNodes = true}) {
    if (mergeParentNodes) _parent.mergeNodes(other._parent);
    _mergeRecords(other, _parent.vectorClock);
  }

  void putRecord(K key, Record<V> record, {bool validateRecord = true}) {
    if (validateRecord) _parent._validateRecord(record);
    _records[key] = record;
  }

  void put(K key, V? value) {
    putRecord(key, _parent._makeRecord(value));
  }

  void delete(K key) => put(key, null);

  @override
  String toString() {
    return 'CrdtNode$records';
  }
}

class MapCrdt<K, V> extends _MapCrdtBase<K, V> {
  final String _node;
  final List<String> _nodes;
  final VectorClock _vectorClock;
  late int _nodeClockIndex;

  MapCrdt(
    this._node, {
    Set<String>? nodes,
    VectorClock? vectorClock,
    Map<K, Record<V>>? records,
    bool validateRecords = true,
  })  : _nodes = nodes != null ? List.from(nodes) : [_node],
        _vectorClock =
            vectorClock ?? VectorClock(nodes == null ? 1 : nodes.length),
        super(records ?? {}) {
    if (_vectorClock.numNodes != _nodes.length) {
      throw ArgumentError('vector clock has invalid number of nodes');
    }
    _nodes.sort();
    _updateNodeClockIndex();
    if (validateRecords) _validateRecords(_records);
  }

  MapCrdt.from(
    MapCrdt<K, V> other, {
    K Function(K)? cloneKey,
    V Function(V)? cloneValue,
  })  : _node = other._node,
        _nodes = List.from(other._nodes),
        _vectorClock = VectorClock.from(other._vectorClock),
        _nodeClockIndex = other._nodeClockIndex,
        super.from(other, cloneKey: cloneKey, cloneValue: cloneValue);

  String get node => _node;
  VectorClock get vectorClock => _vectorClock;
  UnmodifiableListView<String> get nodes => UnmodifiableListView(_nodes);

  bool hasNode(String node) {
    return binarySearch(_nodes, node) != -1;
  }

  void putRecord(K key, Record<V> record, {bool validateRecord = true}) {
    if (validateRecord) _validateRecord(record);
    _records[key] = record;
  }

  void put(K key, V? value) {
    putRecord(key, _makeRecord(value));
  }

  void delete(K key) => put(key, null);

  void addNode(String node) {
    final insertPos = lowerBound(_nodes, node);
    if (insertPos < _nodes.length && _nodes[insertPos] == node) return;
    _nodes.insert(insertPos, node);
    _vectorClock.insertClockValue(insertPos);
    _insertClockValue(insertPos);
    _updateNodeClockIndex();
  }

  void mergeNodes(MapCrdt other) {
    other.nodes.forEach((node) => addNode(node));
    nodes.forEach((node) => other.addNode(node));
  }

  /// Important: Records of [other] will be changed. Use MapCrdt.from(other, cloneKey: ..., cloneValue: ...) to keep them intact.
  void merge(MapCrdt<K, V> other) {
    mergeNodes(other);
    _mergeRecords(other, _vectorClock);
    _vectorClock.increment(_nodeClockIndex);
  }

  void _validateRecord(Record record) {
    if (!hasNode(record.clock.node)) {
      throw ArgumentError(
        'node list doesn\'t contain the node of the record',
      );
    }
    if (record.clock.vectorClock.numNodes != _vectorClock.numNodes) {
      throw ArgumentError(
        'record vector clock does not have the same number of nodes as this crdt',
      );
    }
  }

  void _validateRecords<S>(Map<S, Record> records) =>
      _records.values.forEach(_validateRecord);

  Record<S> _makeRecord<S>(S? value) {
    return Record(
      clock: _makeDistributedClock(),
      value: value,
    );
  }

  DistributedClock _makeDistributedClock() => DistributedClock.now(
        _vectorClock..increment(_nodeClockIndex),
        _node,
      );

  void _updateNodeClockIndex() {
    _nodeClockIndex = binarySearch(_nodes, _node);
    if (!hasNode(node)) {
      throw ArgumentError('could not find own node in list of nodes');
    }
  }

  Map<String, dynamic> toJson({
    Function(K)? keyEncode,
    Function(V)? valueEncode,
  }) {
    return <String, dynamic>{
      'node': _node,
      'nodes': _nodes,
      'vectorClock': List<int>.from(_vectorClock.value),
      'records': recordsToJson(keyEncode: keyEncode, valueEncode: valueEncode),
    };
  }

  factory MapCrdt.fromJson(
    Map<String, dynamic> json, {
    K Function(dynamic)? keyDecode,
    V Function(dynamic)? valueDecode,
  }) {
    return MapCrdt(
      json['node'] as String,
      nodes: (json['nodes'] as List).map((e) => e as String).toSet(),
      vectorClock: VectorClock.fromList(
        (json['vectorClock'] as List).map((e) => e as int).toList(),
      ),
      records: _MapCrdtBase.recordsFromJson(
        json['records'],
        keyDecode: keyDecode,
        valueDecode: valueDecode,
      ),
    );
  }
}
