import 'package:collection/collection.dart';

import 'vector_clock.dart';

class DistributedClock implements Comparable<DistributedClock> {
  final VectorClock _vectorClock;
  final int _timestamp;
  final String _node;

  DistributedClock(VectorClock clock, this._timestamp, this._node)
      : _vectorClock = VectorClock.from(clock);

  DistributedClock.from(DistributedClock other)
      : this(
          VectorClock.from(other._vectorClock),
          other._timestamp,
          other._node,
        );

  DistributedClock.now(VectorClock clock, String node)
      : this(clock, DateTime.now().millisecondsSinceEpoch, node);

  VectorClock get vectorClock => _vectorClock;
  int get timestamp => _timestamp;
  String get node => _node;

  @override
  String toString() => '$_vectorClock:$_timestamp:$_node';

  @override
  int get hashCode => ListEquality().hash([_vectorClock, _timestamp, _node]);

  @override
  bool operator ==(Object other) {
    if (!(other is DistributedClock)) return false;

    return other._vectorClock == _vectorClock &&
        other._timestamp == _timestamp &&
        other._node == _node;
  }

  @override
  int compareTo(DistributedClock other) {
    final vectorClockCmp = _vectorClock.partialCompareTo(other._vectorClock);
    if (vectorClockCmp != null && vectorClockCmp != 0) return vectorClockCmp;
    final timestampCmp = _timestamp.compareTo(other._timestamp);

    return timestampCmp != 0 ? timestampCmp : _node.compareTo(other._node);
  }

  bool operator <(DistributedClock other) => compareTo(other) < 0;

  bool operator <=(DistributedClock other) {
    final cmp = compareTo(other);

    return cmp == 0 || cmp == -1;
  }

  bool operator >(DistributedClock other) => compareTo(other) > 0;

  bool operator >=(DistributedClock other) {
    final cmp = compareTo(other);

    return cmp == 0 || cmp == 1;
  }

  factory DistributedClock.fromJson(Map<String, dynamic> json) {
    return DistributedClock(
      VectorClock.fromList(
        (json['clock'] as List).map((e) => e as int).toList(),
      ),
      json['timestamp'] as int,
      json['node'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'clock': List<int>.from(_vectorClock.value),
      'timestamp': _timestamp,
      'node': _node,
    };
  }
}
