#!/usr/bin/env dart
// argv: dart run adapter.dart <src> <class> <cases.json>
// Concatenates the solution with a dart:mirrors harness in a temp script.

import 'dart:io';

const String _harness = r'''
String toCamel(String snake) {
  if (!snake.contains('_')) {
    return snake;
  }
  final parts = snake.split('_');
  final out = StringBuffer(parts.first);
  for (final part in parts.skip(1)) {
    if (part.isEmpty) {
      continue;
    }
    out.write(part[0].toUpperCase());
    if (part.length > 1) {
      out.write(part.substring(1));
    }
  }
  return out.toString();
}

dynamic coerceArg(dynamic value) {
  if (value is double && value == value.roundToDouble()) {
    return value.toInt();
  }
  return value;
}

Map<String, dynamic> failRow(
  String caseId,
  int index,
  String method,
  dynamic expected,
  dynamic actual,
) {
  return {
    'case': caseId,
    'index': index,
    'method': method,
    'expected': expected,
    'actual': actual,
  };
}

void main(List<String> args) {
  if (args.length < 2) {
    stderr.writeln('usage: dart run.dart <cases.json> <class>');
    exit(2);
  }
  final casesPath = args[0];
  final className = args[1];
  final lib = currentMirrorSystem().isolate.rootLibrary;
  final decl = lib.declarations[MirrorSystem.getSymbol(className)];
  if (decl is! ClassMirror) {
    stderr.writeln('missing class $className');
    exit(2);
  }
  final cases = jsonDecode(File(casesPath).readAsStringSync()) as List<dynamic>;
  final failed = <Map<String, dynamic>>[];
  var passed = 0;
  for (final rowObj in cases) {
    final row = rowObj as Map<String, dynamic>;
    final obj = decl.newInstance(Symbol(''), []).reflectee;
    final im = reflect(obj);
    final caseId = row['id'].toString();
    final calls = (row['calls'] as List<dynamic>?) ?? <dynamic>[];
    var ok = true;
    for (var i = 0; i < calls.length; i++) {
      final call = calls[i] as Map<String, dynamic>;
      final methodSnake = call['m'].toString();
      final name = toCamel(methodSnake);
      final argv = ((call['a'] as List<dynamic>?) ?? <dynamic>[])
          .map(coerceArg)
          .toList();
      final expected = call['e'];
      dynamic actual;
      try {
        actual = im.invoke(MirrorSystem.getSymbol(name), argv).reflectee;
      } catch (exc) {
        failed.add(failRow(
          caseId,
          i,
          methodSnake,
          expected,
          'exc:${exc.runtimeType}',
        ));
        ok = false;
        break;
      }
      if (jsonEncode(actual) != jsonEncode(expected)) {
        failed.add(failRow(caseId, i, methodSnake, expected, actual));
        ok = false;
        break;
      }
    }
    if (ok) {
      passed += 1;
    }
  }
  stdout.writeln(jsonEncode({'passed': passed, 'failed': failed}));
  exit(failed.isEmpty ? 0 : 1);
}
''';

void main(List<String> args) {
  if (args.length < 3) {
    stderr.writeln('usage: dart run adapter.dart <src> <class> <cases.json>');
    exit(2);
  }
  final src = args[0];
  final className = args[1];
  final casesPath = args[2];
  final tmp = Directory.systemTemp.createTempSync('honepad-dart-');
  try {
    final runPath = '${tmp.path}/run.dart';
    File(runPath).writeAsStringSync(
      "import 'dart:convert';\n"
      "import 'dart:io';\n"
      "import 'dart:mirrors';\n\n"
      '${File(src).readAsStringSync()}\n\n'
      '$_harness',
    );
    final result = Process.runSync(
      Platform.resolvedExecutable,
      [runPath, casesPath, className],
    );
    stdout.write(result.stdout);
    stderr.write(result.stderr);
    exit(result.exitCode);
  } finally {
    tmp.deleteSync(recursive: true);
  }
}
