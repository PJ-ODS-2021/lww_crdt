import 'dart:convert';

import 'package:test/test.dart';
import 'package:lww_crdt/lww_crdt.dart';

void main() {
  test('equality', () {
    final c1 = DistributedClock(VectorClock.fromList([1, 2]), 42, 'node1');
    final c2 = DistributedClock(VectorClock.fromList([1, 2]), 42, 'node1');
    expect(c1, c2);
  });

  test('hash equality', () {
    final c1 = DistributedClock(VectorClock.fromList([1, 2]), 42, 'node1');
    final c2 = DistributedClock(VectorClock.fromList([1, 2]), 42, 'node1');
    expect(c1.hashCode, c2.hashCode);
  });

  test('compare to equality', () {
    final c1 = DistributedClock(VectorClock.fromList([1, 2]), 42, 'node1');
    final c2 = DistributedClock(VectorClock.fromList([1, 2]), 42, 'node1');
    expect(c1.compareTo(c2), 0);
  });

  test('compare to less', () {
    expect(
      DistributedClock(
        VectorClock.fromList([1, 1]),
        42,
        'node1',
      ).compareTo(DistributedClock(
        VectorClock.fromList([1, 2]),
        42,
        'node1',
      )),
      -1,
    );
    expect(
      DistributedClock(
        VectorClock.fromList([1, 2]),
        41,
        'node1',
      ).compareTo(DistributedClock(
        VectorClock.fromList([1, 2]),
        42,
        'node1',
      )),
      -1,
    );
    expect(
      DistributedClock(
        VectorClock.fromList([1, 2]),
        42,
        'node0',
      ).compareTo(DistributedClock(
        VectorClock.fromList([1, 2]),
        42,
        'node1',
      )),
      -1,
    );
  });

  test('compare to greater', () {
    expect(
      DistributedClock(
        VectorClock.fromList([1, 2]),
        42,
        'node1',
      ).compareTo(DistributedClock(
        VectorClock.fromList([1, 1]),
        42,
        'node1',
      )),
      1,
    );
    expect(
      DistributedClock(
        VectorClock.fromList([1, 2]),
        42,
        'node1',
      ).compareTo(DistributedClock(
        VectorClock.fromList([1, 2]),
        41,
        'node1',
      )),
      1,
    );
    expect(
      DistributedClock(
        VectorClock.fromList([1, 2]),
        42,
        'node1',
      ).compareTo(DistributedClock(
        VectorClock.fromList([1, 2]),
        42,
        'node0',
      )),
      1,
    );
  });

  test('to json', () {
    final clock = DistributedClock(VectorClock.fromList([1, 2]), 42, 'node1');
    expect(clock.toJson(), <String, dynamic>{
      'clock': [1, 2],
      'timestamp': 42,
      'node': 'node1',
    });
  });

  test('from json', () {
    const json = '{"clock": [1, 2], "timestamp": 42, "node": "node1"}';
    expect(
      DistributedClock.fromJson(jsonDecode(json)),
      DistributedClock(VectorClock.fromList([1, 2]), 42, 'node1'),
    );
  });
}
