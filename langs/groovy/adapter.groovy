#!/usr/bin/env groovy
// argv: groovy adapter.groovy <src> <class> <cases.json>

import groovy.json.JsonOutput
import groovy.json.JsonSlurper

static String toCamel(String snake) {
    if (!snake.contains('_')) {
        return snake
    }
    String[] parts = snake.split('_', -1)
    StringBuilder out = new StringBuilder(parts[0])
    for (int i = 1; i < parts.length; i++) {
        if (parts[i].isEmpty()) {
            continue
        }
        out.append(Character.toUpperCase(parts[i].charAt(0)))
        if (parts[i].length() > 1) {
            out.append(parts[i].substring(1))
        }
    }
    return out.toString()
}

static String jsonEncode(Object value) {
    if (value == null) {
        return 'null'
    }
    if (value instanceof Boolean) {
        return value ? 'true' : 'false'
    }
    if (value instanceof Number) {
        if (value instanceof BigDecimal) {
            BigDecimal dec = (BigDecimal) value
            if (dec.scale() <= 0) {
                return dec.toBigInteger().toString()
            }
        }
        if (value instanceof Float || value instanceof Double) {
            double d = ((Number) value).doubleValue()
            if (d == Math.rint(d) && !Double.isInfinite(d)) {
                return Long.toString(d.longValue())
            }
        }
        return value.toString()
    }
    if (value instanceof CharSequence) {
        return JsonOutput.toJson(value.toString())
    }
    if (value instanceof Collection) {
        return '[' + value.collect { jsonEncode(it) }.join(',') + ']'
    }
    if (value instanceof Map) {
        List<String> parts = []
        ((Map) value).each { k, v ->
            parts.add(jsonEncode(k.toString()) + ':' + jsonEncode(v))
        }
        return '{' + parts.join(',') + '}'
    }
    return JsonOutput.toJson(value)
}

static Map failRow(String caseId, int index, String method, Object expected, Object actual) {
    [
        case    : caseId,
        index   : index,
        method  : method,
        expected: expected,
        actual  : actual,
    ]
}

if (args.length < 3) {
    System.err.println('usage: groovy adapter.groovy <src> <class> <cases.json>')
    System.exit(2)
}

String src = args[0]
String className = args[1]
String casesPath = args[2]
GroovyClassLoader loader = new GroovyClassLoader(this.class.classLoader)
loader.parseClass(new File(src))
Class cls = loader.loadClass(className)
List cases = (List) new JsonSlurper().parse(new File(casesPath))
List failed = []
int passed = 0
for (Object rowObj : cases) {
    Map row = (Map) rowObj
    Object obj = cls.getDeclaredConstructor().newInstance()
    String caseId = String.valueOf(row.id)
    List calls = (List) (row.calls ?: [])
    boolean ok = true
    for (int i = 0; i < calls.size(); i++) {
        Map call = (Map) calls[i]
        String methodSnake = String.valueOf(call.m)
        String name = toCamel(methodSnake)
        List argv = (List) (call.a ?: [])
        Object expected = call.e
        Object actual
        try {
            actual = obj.invokeMethod(name, argv as Object[])
        } catch (Exception exc) {
            failed.add(failRow(caseId, i, methodSnake, expected, 'exc:' + exc.getClass().getSimpleName()))
            ok = false
            break
        }
        if (jsonEncode(actual) != jsonEncode(expected)) {
            failed.add(failRow(caseId, i, methodSnake, expected, actual))
            ok = false
            break
        }
    }
    if (ok) {
        passed += 1
    }
}
Map report = [passed: passed, failed: failed]
println jsonEncode(report)
System.exit(failed.isEmpty() ? 0 : 1)
