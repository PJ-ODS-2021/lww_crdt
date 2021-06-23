import 'package:test/test.dart';
import 'package:lww_crdt/lww_crdt.dart';

void main() {
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
    crdt1.merge(MapCrdt.from(crdt2, cloneValue: (v) => MapCrdtNode.from(v)));
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

    crdt1.merge(MapCrdt.from(crdt2, cloneValue: (v) => MapCrdtNode.from(v)));
    expect(crdt1Node.map, {'key1': 'value1', 'key2': 'value2'});
    crdt2.delete('node');
    crdt1.merge(MapCrdt.from(crdt2, cloneValue: (v) => MapCrdtNode.from(v)));
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

    crdt1.merge(MapCrdt.from(crdt2, cloneValue: (v) => MapCrdtNode.from(v)));
    expect(crdt1Node.map, {'key1': 'value1', 'key2': 'value2'});
    crdt2Node.delete('key1');
    crdt1.merge(MapCrdt.from(crdt2, cloneValue: (v) => MapCrdtNode.from(v)));
    expect(crdt1Node.map, {'key2': 'value2'});
  });
}
