/**
 * Test passing data to an isolate using spawn.
 */
library serialization_test;

import 'dart:isolate';
import 'package:test/test.dart';
import 'serialization_test_common.dart';

main() {
  test('round-trip, default format, pass to isolate', () {
    Node n1 = new Node("1"), n2 = new Node("2"), n3 = new Node("3");
    n1.children = [n2, n3];
    n2.parent = n1;
    n3.parent = n1;
    var s = nodeSerializerNonReflective(n1);
    var output = s.write(n2);
    ReceivePort port = new ReceivePort();
    var remote = Isolate.spawn(echo, [output, port.sendPort]);
    port.first.then(verify);
  });
}
