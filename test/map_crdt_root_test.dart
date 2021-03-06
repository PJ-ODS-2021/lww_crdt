import 'package:test/test.dart';
import 'package:lww_crdt/lww_crdt.dart';
import 'util/value_type.dart';

void _setTimestamp(Record<String> record, int timestamp) {
  record.clock = DistributedClock(
    record.clock.vectorClock,
    timestamp,
    record.clock.node,
  );
}

void main() {
  test('init with records', () {
    final crdt = MapCrdtRoot<String, String>(
      'node1',
      records: <String, Record<String>>{
        'key': Record<String>(
          clock: DistributedClock.now(
            VectorClock(1),
            'node1',
          ),
          value: 'value',
        ),
      },
    );
    expect(crdt.map, {'key': 'value'});
  });

  test('init with records fail validation invalid node', () {
    expect(
      () => MapCrdtRoot<String, String>(
        'node1',
        records: <String, Record<String>>{
          'key': Record<String>(
            clock: DistributedClock.now(
              VectorClock(1),
              'node2',
            ),
            value: 'value',
          ),
        },
      ),
      throwsArgumentError,
    );
  });

  test('init with records fail validation invalid vector clock', () {
    expect(
      () => MapCrdtRoot<String, String>(
        'node1',
        records: <String, Record<String>>{
          'key': Record<String>(
            clock: DistributedClock.now(
              VectorClock(2),
              'node1',
            ),
            value: 'value',
          ),
        },
      ),
      throwsArgumentError,
    );
  });

  test('put & get', () {
    final crdt = MapCrdtRoot<String, String>('node1');
    crdt.put('key', 'value');
    expect(crdt.get('key'), 'value');
    expect(crdt.vectorClock, VectorClock.fromList([1]));
  });

  test('add node empty map', () {
    final crdt = MapCrdtRoot<String, String>('node1');
    expect(crdt.nodes, ['node1']);
    expect(crdt.vectorClock.numNodes, 1);
    crdt.addNode('node2');
    expect(crdt.nodes, ['node1', 'node2']);
    expect(crdt.vectorClock.numNodes, 2);
  });

  test('add node with record', () {
    final crdt = MapCrdtRoot<String, String>('node1');
    crdt.put('key', 'value');
    final record = crdt.getRecord('key');
    expect(record, isNot(null));
    expect(record!.clock.vectorClock.numNodes, 1);
    crdt.addNode('node2');
    expect(crdt.vectorClock, VectorClock.fromList([1, 0]));
    expect(record.clock.vectorClock, VectorClock.fromList([1, 0]));

    crdt.put('key2', 'value2');
    final record2 = crdt.getRecord('key2');
    expect(record2, isNot(null));
    expect(crdt.vectorClock, VectorClock.fromList([2, 0]));
    expect(record.clock.vectorClock, VectorClock.fromList([1, 0]));
    expect(record2!.clock.vectorClock, VectorClock.fromList([2, 0]));
  });

  test('add node existing', () {
    final crdt = MapCrdtRoot<String, String>('node1');
    expect(crdt.nodes, ['node1']);
    expect(crdt.vectorClock.numNodes, 1);
    crdt.addNode('node1');
    expect(crdt.nodes, ['node1']);
    expect(crdt.vectorClock.numNodes, 1);
  });

  test('map', () {
    final crdt1 = MapCrdtRoot<String, String>('node1');
    expect(crdt1.map, {});
    crdt1.put('key1', 'value1');
    expect(crdt1.map, {'key1': 'value1'});
    crdt1.put('key2', 'value2');
    expect(crdt1.map, {'key1': 'value1', 'key2': 'value2'});
    crdt1.delete('key1');
    expect(crdt1.map, {'key2': 'value2'});
  });

  test('put all', () {
    final crdt = MapCrdtRoot<String, String>('node1');
    crdt.putAll({'key1': 'value1', 'key2': 'value2'});
    expect(crdt.map, {'key1': 'value1', 'key2': 'value2'});
    expect(crdt.getRecord('key1')!.clock, crdt.getRecord('key2')!.clock);
    expect(crdt.vectorClock, VectorClock.fromList([1]));
  });

  test('clone', () {
    final crdt1 = MapCrdtRoot<String, String>('node1');
    crdt1.put('key', 'value1');
    final crdt2 = MapCrdtRoot.from(crdt1);
    expect(crdt2.map, {'key': 'value1'});

    crdt2.getRecord('key')!.value = 'value2';
    expect(crdt1.map, {'key': 'value1'});
  });

  test('clone custom clone value', () {
    final crdt1 = MapCrdtRoot<String, ValueType>('node1');
    crdt1.put('key', ValueType('value1'));
    final crdt2 = MapCrdtRoot<String, ValueType>.from(
      crdt1,
      cloneValue: (v) => ValueType(v.value),
    );
    expect(crdt2.map, {'key': ValueType('value1')});

    crdt2.getRecord('key')!.value!.value = 'value2';
    expect(crdt1.map, {'key': ValueType('value1')});
  });

  test('clone custom clone key', () {
    final crdt1 = MapCrdtRoot<ValueType, String>('node1');
    crdt1.put(ValueType('key'), 'value1');
    final crdt2 = MapCrdtRoot<ValueType, String>.from(
      crdt1,
      cloneKey: (k) => ValueType(k.value),
    );
    expect(crdt2.map, {ValueType('key'): 'value1'});

    crdt2.records.keys.first.value = 'key2';
    expect(crdt1.map, {ValueType('key'): 'value1'});
  });

  test('values', () {
    final crdt1 = MapCrdtRoot<String, String>('node1');
    expect(crdt1.values, []);
    crdt1.put('key1', 'value1');
    expect(crdt1.values, ['value1']);
    crdt1.put('key2', 'value2');
    expect(crdt1.values, ['value1', 'value2']);
    crdt1.delete('key1');
    expect(crdt1.values, ['value2']);
  });

  test('merge keep both', () {
    final crdt1 = MapCrdtRoot<String, String>('node1');
    final crdt2 = MapCrdtRoot<String, String>('node2');
    crdt1.put('key1', 'value1');
    crdt2.put('key2', 'value2');

    crdt1.merge(MapCrdtRoot.from(crdt2));
    expect(crdt1.map, {'key1': 'value1', 'key2': 'value2'});
    expect(crdt1.nodes, ['node1', 'node2']);

    crdt2.merge(MapCrdtRoot.from(crdt1));
    expect(crdt2.map, {'key1': 'value1', 'key2': 'value2'});
    expect(crdt2.nodes, ['node1', 'node2']);
  });

  test('merge keep more recent by timestamp', () async {
    final crdt1 = MapCrdtRoot<String, String>('node1');
    final crdt2 = MapCrdtRoot<String, String>('node2');
    crdt1.put('key1', 'value1');
    await Future.delayed(Duration(milliseconds: 10));
    crdt2.put('key1', 'value2');

    crdt1.merge(MapCrdtRoot.from(crdt2));
    expect(crdt1.map, {'key1': 'value2'});
    expect(crdt1.nodes, ['node1', 'node2']);

    crdt2.merge(MapCrdtRoot.from(crdt1));
    expect(crdt2.map, {'key1': 'value2'});
    expect(crdt2.nodes, ['node1', 'node2']);
  });

  test('merge use timestamp in concurrent changes', () async {
    final crdt1 = MapCrdtRoot<String, String>('node1');
    final crdt2 = MapCrdtRoot<String, String>('node2');
    final crdt3 = MapCrdtRoot<String, String>('node3');
    crdt1.put('key1', 'value1');
    crdt2.merge(MapCrdtRoot.from(crdt1));
    crdt3.merge(MapCrdtRoot.from(crdt1));

    for (var i = 0; i < 10; i++) {
      crdt3.put('key1', 'value3');
    }
    await Future.delayed(Duration(milliseconds: 10));
    crdt2.put('key1', 'value2');

    crdt1.merge(MapCrdtRoot.from(crdt3));
    crdt1.merge(MapCrdtRoot.from(crdt2));

    expect(crdt1.map, {'key1': 'value2'});
    expect(crdt1.nodes, ['node1', 'node2', 'node3']);
  });

  test('merge timestamp initial tiebreak', () async {
    final crdt1 = MapCrdtRoot<String, String>('node1');
    final crdt2 = MapCrdtRoot<String, String>('node2');

    crdt1.put('key1', 'value1');
    _setTimestamp(crdt1.getRecord('key1')!, 0);
    crdt2.put('key1', 'value2');
    _setTimestamp(crdt2.getRecord('key1')!, 1);

    crdt1.merge(MapCrdtRoot.from(crdt2));
    expect(crdt1.map, {'key1': 'value2'});
  });

  test('merge use vector clock (node idle)', () async {
    final crdt1 = MapCrdtRoot<String, String>('node1');
    final crdt2 = MapCrdtRoot<String, String>('node2');

    crdt2.put('key1', 'value2');
    crdt1.merge(MapCrdtRoot.from(crdt2));
    expect(crdt1.map, {'key1': 'value2'});

    crdt1.put('key1', 'value1');
    _setTimestamp(crdt1.getRecord('key1')!, 0);
    crdt2.merge(MapCrdtRoot.from(crdt1));

    expect(crdt2.map, {'key1': 'value1'});
  });

  test('merge use vector clock (node busy)', () {
    final crdt1 = MapCrdtRoot<String, String>('node1');
    final crdt2 = MapCrdtRoot<String, String>('node2');

    crdt1.put('key', 'value');
    crdt2.merge(MapCrdtRoot.from(crdt1));

    for (var i = 0; i < 10; i++) {
      crdt1.put('unrelated key', 'unrelated value');
    }
    crdt2.put('key', 'new value');
    _setTimestamp(crdt1.getRecord('key')!, 0);

    crdt1.merge(MapCrdtRoot.from(crdt2));
    expect(crdt1.map, {'unrelated key': 'unrelated value', 'key': 'new value'});
    crdt2.merge(MapCrdtRoot.from(crdt1));
    expect(crdt2.map, {'unrelated key': 'unrelated value', 'key': 'new value'});
  });

  test('change node', () async {
    final crdt1 = MapCrdtRoot<String, String>('node1');
    crdt1.put('key1', 'value1');
    crdt1.changeNode('newNode1');
    expect(crdt1.node, 'newNode1');
    expect(crdt1.nodes.toSet(), {'node1', 'newNode1'});
    expect(
      () => crdt1.records.values
          .forEach((record) => crdt1.validateRecord(record)),
      returnsNormally,
    );
  });

  test('can contain changes', () async {
    final crdt1 = MapCrdtRoot<String, String>('node1');
    final crdt2 = MapCrdtRoot<String, String>('node2');
    expect(crdt1.canContainChangesFor(crdt2), true);
    expect(crdt2.canContainChangesFor(crdt1), true);
    crdt1.put('key', 'value');
    expect(crdt1.canContainChangesFor(crdt2), true);
    expect(crdt2.canContainChangesFor(crdt1), true);

    crdt2.merge(MapCrdtRoot.from(crdt1));
    expect(crdt2.canContainChangesFor(crdt1), true);
    expect(crdt1.canContainChangesFor(crdt2), false);

    crdt2.put('key2', 'value2');
    expect(crdt2.canContainChangesFor(crdt1), true);
    expect(crdt1.canContainChangesFor(crdt2), false);

    crdt1.put('key3', 'value3');
    expect(crdt2.canContainChangesFor(crdt1), true);
    expect(crdt1.canContainChangesFor(crdt2), true);
  });

  test('vector clock merge', () async {
    final crdt1 = MapCrdtRoot<String, String>('node1');
    final crdt2 = MapCrdtRoot<String, String>('node2');
    crdt1.put('key', 'value');
    crdt2.merge(crdt1);
    final crdt1ClockValue = crdt1.vectorClock.value[crdt1.vectorClockIndex];
    expect(crdt2.vectorClock.value.length, 2);
    expect(
      crdt2.vectorClock.value[(crdt2.vectorClockIndex + 1) % 2],
      crdt1ClockValue,
    );
  });

  test('to json', () {
    final node1Clock = DistributedClock.now(
      VectorClock(1),
      'node1',
    );
    final crdt = MapCrdtRoot<String, String>(
      'node1',
      vectorClock: VectorClock.fromList([1]),
      records: <String, Record<String>>{
        'key': Record<String>(
          clock: node1Clock,
          value: 'value',
        ),
      },
    );
    expect(crdt.toJson(), {
      'node': 'node1',
      'nodes': ['node1'],
      'vectorClock': [1],
      'records': {
        'key': {
          'clock': node1Clock.toJson(),
          'value': 'value',
        },
      },
    });
  });

  test('from json', () {
    final node1Clock = DistributedClock.now(
      VectorClock(1),
      'node1',
    );
    final json = {
      'node': 'node1',
      'nodes': ['node1'],
      'vectorClock': [1],
      'records': {
        'key': {
          'clock': node1Clock.toJson(),
          'value': 'value',
        },
      },
    };
    final crdt = MapCrdtRoot<String, String>.fromJson(json);
    expect(crdt.vectorClock, VectorClock.fromList([1]));
    expect(crdt.nodes, ['node1']);
    expect(crdt.map, {'key': 'value'});
    expect(crdt.records, {
      'key': Record<String>(
        clock: node1Clock,
        value: 'value',
      ),
    });
  });

  test('to json value encode', () {
    final node1Clock = DistributedClock.now(
      VectorClock(1),
      'node1',
    );
    final crdt = MapCrdtRoot<String, ValueType>(
      'node1',
      vectorClock: VectorClock.fromList([1]),
      records: <String, Record<ValueType>>{
        'key': Record<ValueType>(
          clock: node1Clock,
          value: ValueType('value'),
        ),
      },
    );
    expect(
      crdt.toJson(
        valueEncode: (v) => {'value': v.value},
      ),
      {
        'node': 'node1',
        'nodes': ['node1'],
        'vectorClock': [1],
        'records': {
          'key': {
            'clock': node1Clock.toJson(),
            'value': {
              'value': 'value',
            },
          },
        },
      },
    );
  });

  test('from json value decode', () {
    final node1Clock = DistributedClock.now(
      VectorClock(1),
      'node1',
    );
    final json = {
      'node': 'node1',
      'nodes': ['node1'],
      'vectorClock': [1],
      'records': {
        'key': {
          'clock': node1Clock.toJson(),
          'value': {
            'value': 'value',
          },
        },
      },
    };
    // ignore: prefer-trailing-comma
    final crdt = MapCrdtRoot<String, ValueType>.fromJson(
      json,
      valueDecode: (valueJson) => ValueType(valueJson['value']),
    );
    expect(crdt.vectorClock, VectorClock.fromList([1]));
    expect(crdt.nodes, ['node1']);
    expect(crdt.map, {'key': ValueType('value')});
    expect(crdt.records, {
      'key': Record<ValueType>(
        clock: node1Clock,
        value: ValueType('value'),
      ),
    });
  });
}
