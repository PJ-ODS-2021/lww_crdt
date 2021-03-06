import 'package:test/test.dart';
import 'package:lww_crdt/lww_crdt.dart';
import 'util/value_type.dart';

MapCrdtRoot<String, MapCrdtNode<String, String>> _deepCloneCrdt(
  MapCrdtRoot<String, MapCrdtNode<String, String>> crdt,
) {
  final crdtCopy = MapCrdtRoot<String, MapCrdtNode<String, String>>.from(crdt);
  crdtCopy.updateValues((k, v) => MapCrdtNode.from(v, parent: crdtCopy));

  return crdtCopy;
}

void main() {
  test('put all', () {
    final crdt = MapCrdtRoot<String, MapCrdtNode<String, String>>('node1');
    final crdtNode = MapCrdtNode<String, String>(crdt);
    crdt.put('node', crdtNode);
    crdtNode.putAll({'key1': 'value1', 'key2': 'value2'});

    expect(crdtNode.map, {'key1': 'value1', 'key2': 'value2'});
    expect(
      crdtNode.getRecord('key1')!.clock,
      crdtNode.getRecord('key2')!.clock,
    );
    expect(crdt.vectorClock, VectorClock.fromList([2]));
  });

  test('map crdt deep clone', () {
    final crdt = MapCrdtRoot<String, MapCrdtNode<String, String>>('node');
    final crdtNode = MapCrdtNode<String, String>(crdt)..put('key', 'value');
    crdt.put('node', crdtNode);

    final crdtCopy = _deepCloneCrdt(crdt);
    crdtCopy.put('node2', MapCrdtNode(crdtCopy)..put('key2', 'value2'));
    expect(crdtCopy.nodes, ['node']);
    expect(crdtCopy.records.keys.toSet(), {'node', 'node2'});
    expect(crdtCopy.get('node2')?.map, {'key2': 'value2'});
    expect(crdtCopy.get('node')?.map, {'key': 'value'});
    crdtCopy.get('node')!.put('key3', 'value3');
    expect(crdtCopy.get('node')?.map, {'key': 'value', 'key3': 'value3'});
    crdtCopy.addNode('node2');
    expect(crdtCopy.nodes, ['node', 'node2']);
    crdtCopy.get('node')!.root.addNode('node3');
    expect(crdtCopy.nodes, ['node', 'node2', 'node3']);

    // expect original unchanged
    expect(crdt.nodes, ['node']);
    expect(crdt.records.keys.toSet(), {'node'});
    expect(crdtNode.map, {'key': 'value'});
    expect(crdt.get('node')?.map, {'key': 'value'});
  });

  test('map crdt node merge', () {
    final crdt1 = MapCrdtRoot<String, MapCrdtNode<String, String>>('node1');
    final crdt1Node = MapCrdtNode<String, String>(crdt1);
    final crdt2 = MapCrdtRoot<String, MapCrdtNode<String, String>>('node2');
    final crdt2Node = MapCrdtNode<String, String>(crdt2);
    crdt1.put('node', crdt1Node);
    crdt2.put('node', crdt2Node);
    crdt1Node.put('key1', 'value1');
    crdt2Node.put('key2', 'value2');

    expect(crdt1Node.map, {'key1': 'value1'});
    expect(crdt2Node.map, {'key2': 'value2'});
    crdt1.merge(_deepCloneCrdt(crdt2));
    expect(crdt1.get('node')?.map, {'key1': 'value1', 'key2': 'value2'});
    expect(crdt1Node.map, {'key1': 'value1', 'key2': 'value2'});
  });

  test('map crdt merge node parent updated', () {
    final crdt1 = MapCrdtRoot<String, MapCrdtNode<String, String>>('node1');
    final crdt2 = MapCrdtRoot<String, MapCrdtNode<String, String>>('node2');
    final crdt2Node = MapCrdtNode<String, String>(crdt2);
    crdt2.put('node', crdt2Node);
    crdt2Node.put('key2', 'value2');

    crdt1.merge(_deepCloneCrdt(crdt2));
    expect(crdt1.map['node']?.map, {'key2': 'value2'});
    expect(
      crdt1.records.values.every((record) =>
          record.isDeleted || (record.value as MapCrdtNode).root == crdt1),
      true,
      reason: 'expected crdt nodes to have updated their parent',
    );
  });

  test('map crdt node merge delete node', () {
    final crdt1 = MapCrdtRoot<String, MapCrdtNode<String, String>>('node1');
    final crdt1Node = MapCrdtNode<String, String>(crdt1);
    final crdt2 = MapCrdtRoot<String, MapCrdtNode<String, String>>('node2');
    final crdt2Node = MapCrdtNode<String, String>(crdt2);
    crdt1.put('node', crdt1Node);
    crdt2.put('node', crdt2Node);
    crdt1Node.put('key1', 'value1');
    crdt2Node.put('key2', 'value2');

    crdt1.merge(_deepCloneCrdt(crdt2));
    expect(crdt1Node.map, {'key1': 'value1', 'key2': 'value2'});
    crdt2.delete('node');
    crdt1.merge(_deepCloneCrdt(crdt2));
    expect(crdt1.map, {});
  });

  test('map crdt node merge node first updated then deleted', () async {
    final crdt1 = MapCrdtRoot<String, MapCrdtNode<String, String>>('node1');
    final crdt1Node = MapCrdtNode<String, String>(crdt1);
    final crdt2 = MapCrdtRoot<String, MapCrdtNode<String, String>>('node2');
    final crdt2Node = MapCrdtNode<String, String>(crdt2);
    crdt1.put('node', crdt1Node);
    crdt2.put('node', crdt2Node);

    // first update in crdt2 then delete in crdt1
    crdt2Node.put('key2', 'new value');
    await Future.delayed(Duration(milliseconds: 10));
    crdt1.delete('node');

    crdt1.merge(_deepCloneCrdt(crdt2));
    expect(crdt1.map, {});
  });

  test(
    'map crdt node merge node first updated then deleted after merge',
    () async {
      final crdt1 = MapCrdtRoot<String, MapCrdtNode<String, String>>('node1');
      final crdt1Node = MapCrdtNode<String, String>(crdt1);
      final crdt2 = MapCrdtRoot<String, MapCrdtNode<String, String>>('node2');
      final crdt2Node = MapCrdtNode<String, String>(crdt2);
      crdt1.put('node', crdt1Node);
      crdt2.put('node', crdt2Node);
      crdt1.merge(_deepCloneCrdt(crdt2));

      // first update in crdt2 then delete in crdt1
      crdt2Node.put('key2', 'new value');
      await Future.delayed(Duration(milliseconds: 10));
      crdt1.delete('node');

      crdt1.merge(_deepCloneCrdt(crdt2));
      expect(crdt1.map, {});
    },
  );

  test('map crdt node merge node first deleted then updated', () async {
    final crdt1 = MapCrdtRoot<String, MapCrdtNode<String, String>>('node1');
    final crdt1Node = MapCrdtNode<String, String>(crdt1);
    final crdt2 = MapCrdtRoot<String, MapCrdtNode<String, String>>('node2');
    final crdt2Node = MapCrdtNode<String, String>(crdt2);
    crdt1.put('node', crdt1Node);
    crdt2.put('node', crdt2Node);

    // first delete in crdt1 then update in crdt2
    crdt1.delete('node');
    await Future.delayed(Duration(milliseconds: 10));
    crdt2Node.put('key', 'value');

    crdt1.merge(_deepCloneCrdt(crdt2));
    expect(crdt1.map.keys.toSet(), {'node'});
    expect(crdt1.map['node']?.map, {'key': 'value'});
  });

  test(
    'map crdt node merge node first deleted then updated after merge',
    () async {
      final crdt1 = MapCrdtRoot<String, MapCrdtNode<String, String>>('node1');
      final crdt1Node = MapCrdtNode<String, String>(crdt1);
      final crdt2 = MapCrdtRoot<String, MapCrdtNode<String, String>>('node2');
      final crdt2Node = MapCrdtNode<String, String>(crdt2);
      crdt1.put('node', crdt1Node);
      crdt2.put('node', crdt2Node);
      crdt1.merge(_deepCloneCrdt(crdt2));

      // first delete in crdt1 then update in crdt2
      crdt1.delete('node');
      await Future.delayed(Duration(milliseconds: 10));
      crdt2Node.put('key', 'value');

      crdt1.merge(_deepCloneCrdt(crdt2));
      expect(crdt1.map.keys.toSet(), {'node'});
      expect(crdt1.map['node']?.map, {'key': 'value'});
    },
  );

  test('map crdt node merge delete in node', () {
    final crdt1 = MapCrdtRoot<String, MapCrdtNode<String, String>>('node1');
    final crdt1Node = MapCrdtNode<String, String>(crdt1);
    final crdt2 = MapCrdtRoot<String, MapCrdtNode<String, String>>('node2');
    final crdt2Node = MapCrdtNode<String, String>(crdt2);
    crdt1.put('node', crdt1Node);
    crdt2.put('node', crdt2Node);
    crdt1Node.put('key1', 'value1');
    crdt2Node.put('key2', 'value2');

    crdt1.merge(_deepCloneCrdt(crdt2));
    expect(crdt1Node.map, {'key1': 'value1', 'key2': 'value2'});
    crdt2Node.delete('key1');
    crdt1.merge(_deepCloneCrdt(crdt2));
    expect(crdt1Node.map, {'key2': 'value2'});
  });

  test('vector clock merge with node', () async {
    final crdt1 = MapCrdtRoot<String, MapCrdtNode<String, String>>('node1');
    final crdt1Node = MapCrdtNode<String, String>(crdt1);
    final crdt2 = MapCrdtRoot<String, MapCrdtNode<String, String>>('node2');
    crdt1.put('node', crdt1Node);
    crdt1Node.put('key', 'value');
    crdt2.merge(crdt1);
    final crdt1ClockValue = crdt1.vectorClock.value[crdt1.vectorClockIndex];
    expect(crdt2.vectorClock.value.length, 2);
    expect(
      crdt2.vectorClock.value[(crdt2.vectorClockIndex + 1) % 2],
      crdt1ClockValue,
    );
  });

  test('map crdt node to json', () {
    final crdt = MapCrdtRoot<String, MapCrdtNode<String, String>>('node1');
    final crdtNode = MapCrdtNode<String, String>(crdt);
    crdt.put('node1', crdtNode);
    crdtNode.put('key1', 'value1');

    final key1Clock = crdtNode.getRecord('key1')!.clock;
    final expectedCrdtNodeJson = {
      'key1': {
        'clock': key1Clock.toJson(),
        'value': 'value1',
      },
    };
    expect(crdtNode.toJson(), expectedCrdtNodeJson);

    final node1Clock = crdt.getRecord('node1')!.clock;
    expect(crdt.toJson(valueEncode: (node) => node.toJson()), {
      'node': 'node1',
      'nodes': ['node1'],
      'vectorClock': crdt.vectorClock.value.toList(),
      'records': {
        'node1': {
          'clock': node1Clock.toJson(),
          'value': expectedCrdtNodeJson,
        },
      },
    });
  });

  test('map crdt node to json custom value type', () {
    final crdt = MapCrdtRoot<String, MapCrdtNode<String, ValueType>>('node1');
    final crdtNode = MapCrdtNode<String, ValueType>(crdt);
    crdt.put('node1', crdtNode);
    crdtNode.put('key1', ValueType('value1'));

    final valueEncodeFunc = (ValueType v) => {'value': v.value};

    final key1Clock = crdtNode.getRecord('key1')!.clock;
    final expectedCrdtNodeJson = {
      'key1': {
        'clock': key1Clock.toJson(),
        'value': {'value': 'value1'},
      },
    };
    expect(
      crdtNode.toJson(valueEncode: valueEncodeFunc),
      expectedCrdtNodeJson,
    );

    final node1Clock = crdt.getRecord('node1')!.clock;
    expect(
      crdt.toJson(
        valueEncode: (node) => node.toJson(valueEncode: valueEncodeFunc),
      ),
      {
        'node': 'node1',
        'nodes': ['node1'],
        'vectorClock': crdt.vectorClock.value.toList(),
        'records': {
          'node1': {
            'clock': node1Clock.toJson(),
            'value': expectedCrdtNodeJson,
          },
        },
      },
    );
  });

  test('map crdt node from json', () {
    final vectorClock = VectorClock(1);
    final node1Clock = DistributedClock(
      vectorClock..increment(0),
      DateTime.now().millisecondsSinceEpoch,
      'node1',
    );
    final key1Clock = DistributedClock(
      vectorClock..increment(0),
      DateTime.now().millisecondsSinceEpoch,
      'node1',
    );
    final crdtNodeJson = {
      'key1': {
        'clock': key1Clock.toJson(),
        'value': 'value1',
      },
    };
    expect(
      MapCrdtNode<String, String>.fromJson(
        crdtNodeJson,
        parent: MapCrdtRoot<String, MapCrdtNode<String, String>>('node1'),
      ).records,
      {
        'key1': Record<String>(
          clock: key1Clock,
          value: 'value1',
        ),
      },
    );

    final crdtJson = {
      'node': 'node1',
      'nodes': ['node1'],
      'vectorClock': vectorClock.value.toList(),
      'records': {
        'node1': {
          'clock': node1Clock.toJson(),
          'value': crdtNodeJson,
        },
      },
    };
    final decodedCrdt =
        MapCrdtRoot<String, MapCrdtNode<String, String>>.fromJson(
      crdtJson,
      lateValueDecode: (crdt, json) => MapCrdtNode<String, String>.fromJson(
        json,
        parent: crdt,
      ),
    );
    expect(
      decodedCrdt.records,
      {
        'node1': Record<MapCrdtNode<String, String>>(
          clock: node1Clock,
          value: MapCrdtNode<String, String>(
            decodedCrdt,
            records: {
              'key1': Record<String>(
                clock: key1Clock,
                value: 'value1',
              ),
            },
          ),
        ),
      },
    );
  });

  test('map crdt node from json custom value type', () {
    final vectorClock = VectorClock(1);
    final node1Clock = DistributedClock(
      vectorClock..increment(0),
      DateTime.now().millisecondsSinceEpoch,
      'node1',
    );
    final key1Clock = DistributedClock(
      vectorClock..increment(0),
      DateTime.now().millisecondsSinceEpoch,
      'node1',
    );
    final crdtNodeJson = {
      'key1': {
        'clock': key1Clock.toJson(),
        'value': {'value': 'value1'},
      },
    };
    expect(
      MapCrdtNode<String, ValueType>.fromJson(
        crdtNodeJson,
        parent: MapCrdtRoot<String, MapCrdtNode<String, ValueType>>('node1'),
        valueDecode: (v) => ValueType(v['value'] as String),
      ).records,
      {
        'key1': Record<ValueType>(
          clock: key1Clock,
          value: ValueType('value1'),
        ),
      },
    );

    final crdtJson = {
      'node': 'node1',
      'nodes': ['node1'],
      'vectorClock': vectorClock.value.toList(),
      'records': {
        'node1': {
          'clock': node1Clock.toJson(),
          'value': crdtNodeJson,
        },
      },
    };
    final decodedCrdt =
        MapCrdtRoot<String, MapCrdtNode<String, ValueType>>.fromJson(
      crdtJson,
      lateValueDecode: (crdt, json) => MapCrdtNode<String, ValueType>.fromJson(
        json,
        parent: crdt,
        valueDecode: (v) => ValueType(v['value']),
      ),
    );
    expect(
      decodedCrdt.records,
      {
        'node1': Record<MapCrdtNode<String, ValueType>>(
          clock: node1Clock,
          value: MapCrdtNode<String, ValueType>(
            decodedCrdt,
            records: {
              'key1': Record<ValueType>(
                clock: key1Clock,
                value: ValueType('value1'),
              ),
            },
          ),
        ),
      },
    );
  });

  test('map crdt mixed node merge', () {
    final crdt1 = MapCrdtRoot<String, dynamic>('node1');
    final crdt2 = MapCrdtRoot<String, dynamic>('node2');
    final crdt1Node = MapCrdtNode<String, String>(crdt1);
    final crdt2Node = MapCrdtNode<String, String>(crdt2);
    crdt1.put('node', crdt1Node);
    crdt2.put('node', crdt2Node);
    crdt1.put('title1', 'this is title 1');
    crdt2.put('title2', 'this is title 2');
    crdt1Node.put('key1', 'value1');
    crdt2Node.put('key2', 'value2');

    crdt1.merge(crdt2);
    expect(crdt1.map.keys.toSet(), {'node', 'title1', 'title2'});
    expect(crdt1Node.map, {'key1': 'value1', 'key2': 'value2'});
    expect(crdt1.get('node')?.map, {'key1': 'value1', 'key2': 'value2'});
    expect(crdt1.get('title1'), 'this is title 1');
    expect(crdt1.get('title2'), 'this is title 2');
  });
}
