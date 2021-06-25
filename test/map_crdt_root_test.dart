import 'package:test/test.dart';
import 'package:lww_crdt/lww_crdt.dart';
import 'util/value_type.dart';

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

    final setTimestamp = (Record<String> record, int timestamp) {
      record.clock = DistributedClock(
        record.clock.vectorClock,
        timestamp,
        record.clock.node,
      );
    };

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    crdt1.put('key1', 'value1');
    setTimestamp(crdt1.getRecord('key1')!, timestamp - 100);
    crdt2.put('key1', 'value2');
    setTimestamp(crdt2.getRecord('key1')!, timestamp);

    crdt1.merge(MapCrdtRoot.from(crdt2));
    expect(crdt1.map, {'key1': 'value2'});
  });

  test('merge use vector clock', () async {
    final crdt1 = MapCrdtRoot<String, String>('node1');
    final crdt2 = MapCrdtRoot<String, String>('node2');

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    crdt2.put('key1', 'value2');
    crdt1.merge(MapCrdtRoot.from(crdt2));
    expect(crdt1.map, {'key1': 'value2'});

    crdt1.put('key1', 'value1');
    final record1 = crdt1.getRecord('key1')!;
    record1.clock = DistributedClock(
      record1.clock.vectorClock,
      timestamp - 100,
      record1.clock.node,
    );
    crdt2.merge(MapCrdtRoot.from(crdt1));

    expect(crdt2.map, {'key1': 'value1'});
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
