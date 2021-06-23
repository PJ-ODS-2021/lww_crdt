import 'package:test/test.dart';
import 'package:lww_crdt/lww_crdt.dart';

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
}
