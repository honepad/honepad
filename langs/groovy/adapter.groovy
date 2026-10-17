#!/usr/bin/env groovy
// argv: groovy adapter.groovy <src> <class> <cases.json>

import groovy.json.JsonOutput
import groovy.json.JsonSlurper
import java.io.OutputStream
import java.io.PrintStream

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
            if (Double.isNaN(d)) {
                return '"NaN"'
            }
            if (Double.isInfinite(d)) {
                return d > 0.0d ? '"Infinity"' : '"-Infinity"'
            }
            if (d == Math.rint(d)) {
                return Long.toString((long) d)
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

static Object tagValue(Object value) {
    if (value instanceof Float || value instanceof Double) {
        double d = ((Number) value).doubleValue()
        if (Double.isNaN(d)) {
            return 'NaN'
        }
        if (Double.isInfinite(d)) {
            return d > 0.0d ? 'Infinity' : '-Infinity'
        }
    }
    if (value instanceof Collection) {
        List<Object> out = []
        for (Object item : (Collection) value) {
            out.add(tagValue(item))
        }
        return out
    }
    if (value instanceof Map) {
        Map<Object, Object> out = [:]
        ((Map) value).each { k, v ->
            out[k] = tagValue(v)
        }
        return out
    }
    if (value != null && value.getClass().isArray()) {
        int length = java.lang.reflect.Array.getLength(value)
        List<Object> out = []
        for (int i = 0; i < length; i++) {
            out.add(tagValue(java.lang.reflect.Array.get(value, i)))
        }
        return out
    }
    if (value != null && !(value instanceof CharSequence) && !(value instanceof Number)
            && !(value instanceof Boolean) && !(value instanceof Class)
            && !(value instanceof Collection) && !(value instanceof Map)) {
        try {
            Map props = value.properties
            Map<Object, Object> out = [:]
            props.each { k, v ->
                if (k != 'class') {
                    out[k] = tagValue(v)
                }
            }
            return out
        } catch (Exception ignored) {
            return String.valueOf(value)
        }
    }
    return value
}

static boolean containsNonFinite(Object value) {
    if (value instanceof Float || value instanceof Double) {
        double d = ((Number) value).doubleValue()
        return Double.isNaN(d) || Double.isInfinite(d)
    }
    if (value instanceof Collection) {
        for (Object item : (Collection) value) {
            if (containsNonFinite(item)) {
                return true
            }
        }
    }
    if (value instanceof Map) {
        for (Object item : ((Map) value).values()) {
            if (containsNonFinite(item)) {
                return true
            }
        }
    }
    if (value != null && value.getClass().isArray()) {
        int length = java.lang.reflect.Array.getLength(value)
        for (int i = 0; i < length; i++) {
            if (containsNonFinite(java.lang.reflect.Array.get(value, i))) {
                return true
            }
        }
        return false
    }
    if (value != null && !(value instanceof CharSequence) && !(value instanceof Number)
            && !(value instanceof Boolean) && !(value instanceof Class)
            && !(value instanceof Collection) && !(value instanceof Map)) {
        try {
            Map props = value.properties
            for (Map.Entry entry : props.entrySet()) {
                if (entry.key == 'class') {
                    continue
                }
                if (containsNonFinite(entry.value)) {
                    return true
                }
            }
        } catch (Exception ignored) {
            return false
        }
    }
    return false
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
PrintStream reportOut = System.out
System.setOut(new PrintStream(OutputStream.nullOutputStream()))
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
        boolean mismatch = containsNonFinite(actual)
        if (!mismatch) {
            mismatch = jsonEncode(actual) != jsonEncode(expected)
        }
        if (mismatch) {
            Object shown = containsNonFinite(actual) ? tagValue(actual) : actual
            failed.add(failRow(caseId, i, methodSnake, expected, shown))
            ok = false
            break
        }
    }
    if (ok) {
        passed += 1
    }
}
Map report = [passed: passed, failed: failed]
reportOut.println jsonEncode(report)
System.exit(failed.isEmpty() ? 0 : 1)
