import 'dart:collection';

import 'package:collection/collection.dart';

import 'vector_clock.dart';
import 'record.dart';
import 'distributed_clock.dart';

class MapCrdt<K, V> {
  final String _node;
  final List<String> _nodes;
  final VectorClock _vectorClock;
  final Map<K, Record<V>> _records;
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
        _records = records ?? {} {
    if (_vectorClock.numNodes != _nodes.length) {
      throw ArgumentError('vector clock has invalid number of nodes');
    }
    _nodes.sort();
    _updateNodeClockIndex();

    if (validateRecords) {
      _records.forEach((key, value) {
        if (!hasNode(value.clock.node)) {
          throw ArgumentError(
            'node list doesn\'t contain the node of record',
          );
        }
        if (value.clock.vectorClock.numNodes != _vectorClock.numNodes) {
          throw ArgumentError(
            'record vector clock has different number of nodes',
          );
        }
      });
    }
  }

  MapCrdt.from(
    MapCrdt<K, V> other, {
    K Function(K)? cloneKey,
    V Function(V)? cloneValue,
  })  : _node = other._node,
        _nodes = List.from(other._nodes),
        _vectorClock = VectorClock.from(other._vectorClock),
        _records = Map.from(other._records).map((key, value) => MapEntry(
              cloneKey != null ? cloneKey(key) : key,
              Record<V>.from(value, cloneValue: cloneValue),
            )),
        _nodeClockIndex = other._nodeClockIndex;

  String get node => _node;
  VectorClock get vectorClock => _vectorClock;
  UnmodifiableListView<String> get nodes => UnmodifiableListView(_nodes);
  Map<K, Record<V>> get records => _records;

  Map<K, V> get map => (Map<K, Record<V>>.from(_records)
        ..removeWhere((key, value) => value.isDeleted))
      .map((key, value) => MapEntry(key, value.value!));

  Iterable<V> get values => (List<Record<V>>.from(_records.values)
        ..removeWhere((record) => record.isDeleted))
      .map((record) => record.value!);

  bool hasNode(String node) {
    return binarySearch(_nodes, node) != -1;
  }

  void putRecord(K key, Record<V> record) {
    if (record.clock.vectorClock.numNodes != _vectorClock.numNodes) {
      throw ArgumentError(
        'record vector clock does not have the same number of nodes as this crdt',
      );
    }
    _records[key] = record;
  }

  void put(K key, V? value) {
    putRecord(key, _makeRecord(value));
  }

  void delete(K key) => put(key, null);
  Record<V>? getRecord(K key) => _records[key];
  V? get(K key) => getRecord(key)?.value;

  void addNode(String node) {
    final insertPos = lowerBound(_nodes, node);
    if (insertPos < _nodes.length && _nodes[insertPos] == node) return;
    _nodes.insert(insertPos, node);
    _vectorClock.insertClockValue(insertPos);
    _records.values.forEach((record) {
      record.clock.vectorClock.insertClockValue(insertPos);
    });
    _updateNodeClockIndex();
  }

  /// Important: the other crdt will get changed. Use MapCrdt.from(other, cloneKey: ..., cloneValue: ...) to keep it intact.
  void merge(MapCrdt<K, V> other) {
    other.nodes.forEach((node) => addNode(node));
    nodes.forEach((node) => other.addNode(node));

    final updatedRecords = other._records
      ..removeWhere((key, value) {
        _vectorClock.merge(value.clock.vectorClock);
        final localRecord = _records[key];

        return localRecord != null && localRecord.clock >= value.clock;
      });
    _records.addAll(updatedRecords);

    _vectorClock.increment(_nodeClockIndex);
  }

  Record<V> _makeRecord(V? value) {
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
      'records': _records.map((key, value) => MapEntry(
            keyEncode != null ? keyEncode(key) : key,
            value.toJson(valueEncode: valueEncode),
          )),
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
      records: (json['records'] as Map).map((key, value) => MapEntry(
            keyDecode != null ? keyDecode(key) : key as K,
            Record<V>.fromJson(
              value as Map<String, dynamic>,
              valueDecode: valueDecode,
            ),
          )),
    );
  }
}
