import 'dart:collection';

import 'dart:math';
import 'package:collection/collection.dart';

class VectorClock {
  final List<int> _value;

  VectorClock(int numNodes) : _value = List.filled(numNodes, 0, growable: true);
  VectorClock.fromList(List<int> value) : _value = List.from(value);
  VectorClock.from(VectorClock other) : this.fromList(other._value);

  int get numNodes => _value.length;
  UnmodifiableListView<int> get value => UnmodifiableListView(_value);

  void increment(int index) {
    if (index < 0 || index >= _value.length) {
      throw RangeError.range(index, 0, _value.length - 1);
    }
    _value[index]++;
  }

  void insertClockValue(int index, [int value = 0]) {
    if (index < 0 || index > _value.length) {
      throw RangeError.range(index, 0, _value.length);
    }
    _value.insert(index, value);
  }

  void merge(VectorClock other) {
    if (numNodes != other.numNodes) {
      throw ArgumentError.value(
        other,
        'Cannot merge clock with different numbers of nodes (this != other): $numNodes != ${other.numNodes}',
      );
    }
    for (var i = 0; i < _value.length; i++) {
      _value[i] = max(_value[i], other._value[i]);
    }
  }

  /// like compareTo but returns null if the vector clocks are not comparable
  int? partialCompareTo(VectorClock other) {
    if (other.numNodes != numNodes) return null;
    var vectorCmp = 0;
    for (var i = 0; i < _value.length; i++) {
      final nodeCmp = _value[i].compareTo(other._value[i]);
      if (vectorCmp == 0) {
        vectorCmp = nodeCmp;
      } else if (nodeCmp != 0 && vectorCmp != nodeCmp) {
        return null;
      }
    }

    return vectorCmp;
  }

  @override
  String toString() {
    return '[${_value.join(', ')}]';
  }

  @override
  int get hashCode => ListEquality().hash(_value);

  @override
  bool operator ==(Object other) => other is VectorClock
      ? ListEquality<int>().equals(other._value, _value)
      : false;
}
