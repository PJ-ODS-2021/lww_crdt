import 'dart:collection';

import 'package:collection/collection.dart';

import 'vector_clock.dart';
import 'record.dart';
import 'distributed_clock.dart';
import 'map_crdt.dart';

part 'map_crdt_base.dart';

class MapCrdtRoot<K, V> extends _MapCrdtBase<K, V> {
  final List<String> _nodes;
  final VectorClock _vectorClock;
  late String _node;
  late int _nodeClockIndex;

  MapCrdtRoot(
    this._node, {
    Set<String>? nodes,
    VectorClock? vectorClock,
    Map<K, Record<V>>? records,
    bool validateRecords = true,
  })  : _nodes = nodes != null ? List.from(nodes) : [_node],
        _vectorClock = vectorClock == null
            ? VectorClock(nodes == null ? 1 : nodes.length)
            : VectorClock.from(vectorClock),
        super(records ?? {}) {
    if (_vectorClock.numNodes != _nodes.length) {
      throw ArgumentError('vector clock has invalid number of nodes');
    }
    _nodes.sort();
    _updateNodeClockIndex();
    if (validateRecords) _validateRecords(_records);
  }

  /// Create a copy of [other].
  ///
  /// Use [cloneKey] to provide a function to clone the key.
  /// Use [cloneValue] to provide a function to clone the value.
  ///
  /// To clone deep clone values that require the parent CRDT (e.g. MapCrdtNode),
  /// don't provide [cloneValue] and call [updateValues] or [updateRecords] later.
  MapCrdtRoot.from(
    MapCrdtRoot<K, V> other, {
    K Function(K)? cloneKey,
    V Function(V)? cloneValue,
  })  : _node = other._node,
        _nodes = List.from(other._nodes),
        _vectorClock = VectorClock.from(other._vectorClock),
        _nodeClockIndex = other._nodeClockIndex,
        super.from(other, cloneKey: cloneKey, cloneValue: cloneValue);

  @override
  MapCrdtRoot<K, V> get root => this;

  @override
  List<String> get nodes => UnmodifiableListView(_nodes);

  @override
  bool containsNode(String node) => binarySearch(_nodes, node) != -1;

  @override
  String get node => _node;

  @override
  VectorClock get vectorClock => _vectorClock;

  @override
  int get vectorClockIndex => _nodeClockIndex;

  @override
  void putRecord(K key, Record<V> record, {bool validateRecord = true}) {
    if (validateRecord) this.validateRecord(record);
    _records[key] = record;
  }

  @override
  void validateRecord(Record record) => _validateRecord(record, this);

  @override
  void put(K key, V? value) {
    putRecord(key, _makeRecord(value), validateRecord: false);
  }

  @override
  void putAll(Map<K, V?> values) {
    final clock = _makeDistributedClock();
    values.forEach((key, value) {
      _records[key] = Record(clock: clock, value: value);
    });
  }

  @override
  void delete(K key) => put(key, null);

  @override
  void addNode(String node) {
    final insertPos = lowerBound(_nodes, node);
    if (insertPos < _nodes.length && _nodes[insertPos] == node) return;
    _nodes.insert(insertPos, node);
    _vectorClock.insertClockValue(insertPos);
    insertClockValue(insertPos);
    _updateNodeClockIndex();
  }

  @override
  void mergeNodes(MapCrdt other) {
    other.nodes.forEach((node) => addNode(node));
    nodes.forEach((node) => other.addNode(node));
  }

  @override
  void merge(MapCrdt<K, V> other) {
    mergeNodes(other);
    _vectorClock.merge(other.vectorClock);
    _mergeRecords(other, _vectorClock, this);
    _vectorClock.increment(_nodeClockIndex);
  }

  /// Changes the internal node name
  ///
  /// The old node name will still be kept in the list of nodes.
  void changeNode(String node) {
    addNode(node);
    _node = node;
    _updateNodeClockIndex();
  }

  bool canContainChangesFor(MapCrdtRoot other) {
    final tmp = MapCrdtRoot(
      node,
      nodes: nodes.toSet(),
      vectorClock: vectorClock,
    );
    other.nodes.forEach(tmp.addNode);
    if (!ListEquality().equals(other.nodes, tmp.nodes)) return true;
    final clockCmp = tmp.vectorClock.partialCompareTo(other.vectorClock);

    return clockCmp == null || clockCmp > 0;
  }

  void _validateRecords<S>(Map<S, Record> records) =>
      _records.values.forEach(validateRecord);

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
    if (!containsNode(node)) {
      throw ArgumentError('could not find own node in list of nodes');
    }
  }

  Map<String, dynamic> toJson({
    String Function(K)? keyEncode,
    dynamic Function(V)? valueEncode,
  }) {
    return <String, dynamic>{
      'node': _node,
      'nodes': _nodes,
      'vectorClock': List<int>.from(_vectorClock.value),
      'records': recordsToJson(keyEncode: keyEncode, valueEncode: valueEncode),
    };
  }

  factory MapCrdtRoot.fromJson(
    Map<String, dynamic> json, {
    K Function(dynamic)? keyDecode,
    V Function(dynamic)? valueDecode,
    V Function(MapCrdtRoot<K, V>, dynamic)? lateValueDecode,
  }) {
    final crdt = MapCrdtRoot(
      json['node'] as String,
      nodes: (json['nodes'] as List).map((e) => e as String).toSet(),
      vectorClock: VectorClock.fromList(
        (json['vectorClock'] as List).map((e) => e as int).toList(),
      ),
      records: lateValueDecode == null
          ? _MapCrdtBase.recordsFromJson(
              json['records'],
              keyDecode: keyDecode,
              valueDecode: valueDecode,
            )
          : null,
    );
    if (lateValueDecode != null) {
      _MapCrdtBase.recordsFromJson(
        json['records'],
        keyDecode: keyDecode,
        valueDecode: (v) => lateValueDecode(crdt, v),
      ).forEach(
        (key, value) => crdt.putRecord(key, value, validateRecord: false),
      );
    }

    return crdt;
  }
}

class MapCrdtNode<K, V> extends _MapCrdtBase<K, V> {
  MapCrdtRoot _root;

  MapCrdtNode(
    this._root, {
    Map<K, Record<V>>? records,
    bool validateRecord = true,
  }) : super(records ?? {}) {
    if (validateRecord) _root._validateRecords(_records);
  }

  /// Warning: Doesn't clone the parent. Specify [parent] to use a new parent.
  MapCrdtNode.from(
    MapCrdtNode<K, V> other, {
    MapCrdtRoot<dynamic, MapCrdtNode<K, V>>? parent,
    K Function(K)? cloneKey,
    V Function(V)? cloneValue,
  })  : _root = parent ?? other._root,
        super.from(other, cloneKey: cloneKey, cloneValue: cloneValue);

  @override
  MapCrdtRoot get root => _root;

  @override
  List<String> get nodes => _root.nodes;

  @override
  bool containsNode(String node) => _root.containsNode(node);

  @override
  String get node => _root.node;

  @override
  VectorClock get vectorClock => _root.vectorClock;

  @override
  int get vectorClockIndex => _root.vectorClockIndex;

  @override
  void merge(MapCrdt<K, V> other, {bool mergeParentNodes = true}) {
    if (mergeParentNodes) _root.mergeNodes(other);
    _mergeRecords(other, _root.vectorClock, root);
  }

  @override
  void putRecord(K key, Record<V> record, {bool validateRecord = true}) {
    if (validateRecord) this.validateRecord(record);
    _records[key] = record;
  }

  @override
  void validateRecord(Record record) {
    _validateRecord(record, root);
  }

  @override
  void put(K key, V? value) {
    putRecord(key, _root._makeRecord(value), validateRecord: false);
  }

  @override
  void putAll(Map<K, V?> values) {
    final clock = _root._makeDistributedClock();
    values.forEach((key, value) {
      _records[key] = Record(clock: clock, value: value);
    });
  }

  @override
  void delete(K key) => put(key, null);

  @override
  void addNode(String node) => _root.addNode(node);

  @override
  void mergeNodes(MapCrdt other) => _root.mergeNodes(other);

  @override
  String toString() {
    return 'CrdtNode$records';
  }

  Map<String, dynamic> toJson({
    String Function(K)? keyEncode,
    Function(V)? valueEncode,
  }) =>
      recordsToJson(keyEncode: keyEncode, valueEncode: valueEncode);

  factory MapCrdtNode.fromJson(
    Map<String, dynamic> json, {
    required MapCrdtRoot<dynamic, MapCrdtNode<K, V>> parent,
    K Function(dynamic)? keyDecode,
    V Function(dynamic)? valueDecode,
    bool validateRecords = true,
  }) {
    return MapCrdtNode(
      parent,
      records: _MapCrdtBase.recordsFromJson(
        json,
        keyDecode: keyDecode,
        valueDecode: valueDecode,
      ),
      validateRecord: validateRecords,
    );
  }

  @override
  bool operator ==(Object other) => other is MapCrdtNode<K, V>
      ? other._root == _root && MapEquality().equals(other._records, _records)
      : false;
}
