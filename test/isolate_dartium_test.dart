/**
 * Test passing data to an isolate using Dartium, where we can't use
 * spawnFunction, only spawnUri.
 */
library serialization_test;

import 'dart:isolate';
import 'package:test/test.dart';
import 'serialization_test_common.dart';

/**
 * A Data URI containing the following program, used so we can spawn a URI
 * that will work in Dartium, where spawnFunction from a DOM isolate is
 * not allowed.
 *
 * library echo;
 *
 *  import "dart:isolate";
 *
 *  main(List<String> args, SendPort replyTo) {
 *   replyTo.send(args[0]);
 *  }
 */
var echoUri = Uri.parse(
    'data:text/plain;charset=utf-8;base64,'
    'bGlicmFyeSBlY2hvOw0KDQppbXBvcnQgImRhcnQ6aXNvbGF0ZSI7DQoNCm1haW4oTGlz'
    'dDxTdHJpbmc+IGFyZ3MsIFNlbmRQb3J0IHJlcGx5VG8pIHsNCiAgcmVwbHlUby5zZW5kK'
    'GFyZ3NbMF0pOw0KfQ==');

main() {
  test('round-trip, default format, pass to isolate', () {
    Node n1 = new Node("1"), n2 = new Node("2"), n3 = new Node("3");
    n1.children = [n2, n3];
    n2.parent = n1;
    n3.parent = n1;
    var s = nodeSerializerNonReflective(n1);
    var output = s.write(n2);
    ReceivePort port = new ReceivePort();
    var remote = Isolate.spawnUri(echoUri, [], [output, port.sendPort]);
    port.first.then(verify);
  });
}
