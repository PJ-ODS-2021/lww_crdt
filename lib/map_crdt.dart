import 'vector_clock.dart';
import 'record.dart';

abstract class MapCrdt<K, V> {
  /// Get all recods
  Map<K, Record<V>> get records;

  /// Get all not deleted entries
  Map<K, V> get map;

  /// Get all not deleted values
  Iterable<V> get values;

  /// Get the record for [key]
  Record<V>? getRecord(K key);

  /// Get the entry for [key]
  V? get(K key);

  /// Get the list of nodes that this crdt knows
  List<String> get nodes;

  /// True if this crdt knows of node [node]
  bool containsNode(String node);

  /// The name of this node
  String get node;

  /// The current vector clock of this node
  VectorClock get vectorClock;

  /// Update all records using the [updateRecord] function
  ///
  /// This function can be used to deep clone MapCrdt with MapCrdtNode values.
  void updateRecords(Record<V> Function(K, Record<V>) updateRecord);

  /// Update a single record if it exists
  void updateRecord(K key, Record<V> Function(Record<V>) updateRecord);

  /// Update all values that are not deleted
  void updateValues(V Function(K, V) updateValue);

  /// Update a single value if it exists and is not deleted
  void updateValue(K key, V Function(V) updateRecord);

  /// Add or replace a record
  void putRecord(K key, Record<V> record, {bool validateRecord = true});

  /// Add or replace an entry for [key].
  /// If [value] is null, the record for [key] will be marked as deleted.
  void put(K key, V? value);

  /// Put all entries with the same clock value
  void putAll(Map<K, V?> values);

  // Mark the entry for [key] as deleted.
  void delete(K key);

  /// Add a node to the list of known nodes
  ///
  /// The node is added to the current internal vector clock and all vector clocks of existing records
  void addNode(String node);

  /// Add all nodes from [other] to [this] and all nodes of [this] to [other]
  void mergeNodes(MapCrdt other);

  /// Merge all records of [other] into [this]
  ///
  /// Important: Records and nodes of [other] will be changed.
  /// Use the from(other, cloneKey: ..., cloneValue: ...) constructor to clone it before using this function if [other] is used after.
  void merge(MapCrdt<K, V> other);

  /// Insert a node into the internal vector clock.
  /// THIS METHOD IS ONLY INTENDED FOR INTERNAL USAGE.
  ///
  /// Using this method can irreversibly destroy the structure of internal vector clocks.
  ///
  /// Internal method used to recursively update the vector clock when new nodes are added and the correct insertion index is already known.
  void insertClockValue(int pos, [int initialClockValue = 0]);

  /// Encode all records to a JSON map
  ///
  /// Use [keyEncode] to specify custom key encoding.
  /// Use [valueEncode] to specify custom value encoding.
  Map<String, dynamic> recordsToJson({
    String Function(K)? keyEncode,
    dynamic Function(V)? valueEncode,
  });
}
