import 'package:test/test.dart';
import 'package:lww_crdt/lww_crdt.dart';
import 'util/value_type.dart';

MapCrdt<String, MapCrdtNode<String, String>> _deepCloneCrdt(
  MapCrdt<String, MapCrdtNode<String, String>> crdt,
) {
  final crdtCopy = MapCrdt<String, MapCrdtNode<String, String>>.from(crdt);
  crdtCopy.updateValues((k, v) => MapCrdtNode.from(v, parent: crdtCopy));

  return crdtCopy;
}

void main() {
  test('map crdt deep clone', () {
    final crdt = MapCrdt<String, MapCrdtNode<String, String>>('node');
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
    crdtCopy.get('node')!.parent.addNode('node3');
    expect(crdtCopy.nodes, ['node', 'node2', 'node3']);

    // expect original unchanged
    expect(crdt.nodes, ['node']);
    expect(crdt.records.keys.toSet(), {'node'});
    expect(crdtNode.map, {'key': 'value'});
    expect(crdt.get('node')?.map, {'key': 'value'});
  });

  test('map crdt node merge', () {
    final crdt1 = MapCrdt<String, MapCrdtNode<String, String>>('node1');
    final crdt1Node = MapCrdtNode<String, String>(crdt1);
    final crdt2 = MapCrdt<String, MapCrdtNode<String, String>>('node2');
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

  test('map crdt node merge delete node', () {
    final crdt1 = MapCrdt<String, MapCrdtNode<String, String>>('node1');
    final crdt1Node = MapCrdtNode<String, String>(crdt1);
    final crdt2 = MapCrdt<String, MapCrdtNode<String, String>>('node2');
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

  test('map crdt node merge delete in node', () {
    final crdt1 = MapCrdt<String, MapCrdtNode<String, String>>('node1');
    final crdt1Node = MapCrdtNode<String, String>(crdt1);
    final crdt2 = MapCrdt<String, MapCrdtNode<String, String>>('node2');
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

  test('map crdt node to json', () {
    final crdt = MapCrdt<String, MapCrdtNode<String, String>>('node1');
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
    final crdt = MapCrdt<String, MapCrdtNode<String, ValueType>>('node1');
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
        parent: MapCrdt<String, MapCrdtNode<String, String>>('node1'),
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
    final decodedCrdt = MapCrdt<String, MapCrdtNode<String, String>>.fromJson(
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
        parent: MapCrdt<String, MapCrdtNode<String, ValueType>>('node1'),
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
        MapCrdt<String, MapCrdtNode<String, ValueType>>.fromJson(
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
}
