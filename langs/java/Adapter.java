import java.io.ByteArrayOutputStream;
import java.io.FileDescriptor;
import java.io.FileOutputStream;
import java.io.PrintStream;
import java.lang.reflect.Field;
import java.lang.reflect.InvocationTargetException;
import java.lang.reflect.Method;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;

public class Adapter {
    public static void main(String[] args) throws Exception {
        if (args.length < 2) {
            System.err.println("usage: java Adapter cases.json ClassName");
            System.exit(2);
        }
        String casesPath = args[0];
        String className = args[1];
        Object parsed = MiniJson.parse(Files.readString(Path.of(casesPath)));
        if (!(parsed instanceof List)) {
            throw new IllegalArgumentException("cases.json must be a JSON list");
        }
        @SuppressWarnings("unchecked")
        List<Object> cases = (List<Object>) parsed;
        Class<?> cls = Class.forName(className);
        List<Map<String, Object>> failed = new ArrayList<>();
        int passed = 0;
        PrintStream reportOut = sinkStdout();
        ByteArrayOutputStream captured = new ByteArrayOutputStream();
        PrintStream sink = new PrintStream(captured, true);
        System.setOut(sink);
        try {
            for (Object rowObj : cases) {
                @SuppressWarnings("unchecked")
                Map<String, Object> row = (Map<String, Object>) rowObj;
                Object obj = cls.getDeclaredConstructor().newInstance();
                String caseId = String.valueOf(row.get("id"));
                @SuppressWarnings("unchecked")
                List<Object> calls = (List<Object>) row.get("calls");
                boolean ok = true;
                for (int i = 0; i < calls.size(); i++) {
                    @SuppressWarnings("unchecked")
                    Map<String, Object> call = (Map<String, Object>) calls.get(i);
                    String methodSnake = String.valueOf(call.get("m"));
                    String name = toCamel(methodSnake);
                    @SuppressWarnings("unchecked")
                    List<Object> argv = (List<Object>) call.get("a");
                    Object expected = call.get("e");
                    Object actual;
                    try {
                        actual = invoke(obj, name, argv);
                    } catch (Exception exc) {
                        Throwable cause = unwrap(exc);
                        failed.add(failRow(caseId, i, methodSnake, expected, "exc:" + cause.getClass().getSimpleName()));
                        ok = false;
                        break;
                    }
                    if (!MiniJson.stringify(actual).equals(MiniJson.stringify(expected))) {
                        failed.add(failRow(caseId, i, methodSnake, expected, actual));
                        ok = false;
                        break;
                    }
                }
                if (ok) {
                    passed += 1;
                }
            }
        } finally {
            sink.flush();
            sink.close();
        }
        String debug = captured.toString();
        if (!debug.isEmpty()) {
            reportOut.print(debug);
            if (!debug.endsWith("\n")) {
                reportOut.println();
            }
        }
        Map<String, Object> report = new LinkedHashMap<>();
        report.put("passed", passed);
        report.put("failed", failed);
        reportOut.println(MiniJson.stringify(report));
        reportOut.flush();
        System.exit(failed.isEmpty() ? 0 : 1);
    }

    static FileOutputStream stdoutNullHold;

    static PrintStream sinkStdout() {
        try {
            FileDescriptor saved = new FileDescriptor();
            copyNativeId(FileDescriptor.out, saved);
            PrintStream reportOut = new PrintStream(new FileOutputStream(saved), true);
            String nullPath =
                    System.getProperty("os.name", "").toLowerCase(Locale.ROOT).contains("win")
                            ? "NUL"
                            : "/dev/null";
            stdoutNullHold = new FileOutputStream(nullPath);
            copyNativeId(stdoutNullHold.getFD(), FileDescriptor.out);
            return reportOut;
        } catch (Exception exc) {
            return System.out;
        }
    }

    static void copyNativeId(FileDescriptor from, FileDescriptor to) throws Exception {
        Exception last = null;
        boolean copied = false;
        for (String name : new String[] {"fd", "handle"}) {
            try {
                Field field = FileDescriptor.class.getDeclaredField(name);
                field.setAccessible(true);
                field.set(to, field.get(from));
                copied = true;
            } catch (ReflectiveOperationException exc) {
                last = exc;
            }
        }
        if (!copied) {
            throw last != null ? last : new IllegalStateException("FileDescriptor id missing");
        }
    }

    static Map<String, Object> failRow(String caseId, int index, String method, Object expected, Object actual) {
        Map<String, Object> row = new LinkedHashMap<>();
        row.put("case", caseId);
        row.put("index", index);
        row.put("method", method);
        row.put("expected", expected);
        row.put("actual", actual);
        return row;
    }

    static String toCamel(String snake) {
        if (!snake.contains("_")) {
            return snake;
        }
        String[] parts = snake.split("_", -1);
        StringBuilder out = new StringBuilder(parts[0]);
        for (int i = 1; i < parts.length; i++) {
            if (parts[i].isEmpty()) {
                continue;
            }
            out.append(Character.toUpperCase(parts[i].charAt(0)));
            if (parts[i].length() > 1) {
                out.append(parts[i].substring(1));
            }
        }
        return out.toString();
    }

    static Object invoke(Object obj, String name, List<Object> argv) throws Exception {
        Method method = findMethod(obj.getClass(), name, argv.size());
        if (method == null) {
            throw new NoSuchMethodException(name);
        }
        Class<?>[] types = method.getParameterTypes();
        Object[] converted = new Object[argv.size()];
        for (int i = 0; i < argv.size(); i++) {
            converted[i] = convertArg(argv.get(i), types[i]);
        }
        return method.invoke(obj, converted);
    }

    static Method findMethod(Class<?> cls, String name, int argc) {
        for (Method method : cls.getMethods()) {
            if (method.getName().equals(name) && method.getParameterCount() == argc) {
                return method;
            }
        }
        return null;
    }

    static Object convertArg(Object arg, Class<?> dest) {
        if (arg == null) {
            if (dest.isPrimitive()) {
                throw new IllegalArgumentException("null for primitive " + dest.getName());
            }
            return null;
        }
        if (dest == String.class) {
            if (!(arg instanceof String)) {
                throw new IllegalArgumentException("cannot convert " + arg.getClass().getName() + " to String");
            }
            return arg;
        }
        if (dest == int.class || dest == Integer.class) {
            if (arg instanceof Number) {
                return ((Number) arg).intValue();
            }
            throw new IllegalArgumentException("cannot convert " + arg.getClass().getName() + " to int");
        }
        if (dest == long.class || dest == Long.class) {
            if (arg instanceof Number) {
                return ((Number) arg).longValue();
            }
            throw new IllegalArgumentException("cannot convert " + arg.getClass().getName() + " to long");
        }
        if (dest == boolean.class || dest == Boolean.class) {
            if (arg instanceof Boolean) {
                return arg;
            }
            throw new IllegalArgumentException("cannot convert " + arg.getClass().getName() + " to boolean");
        }
        if (dest.isInstance(arg)) {
            return arg;
        }
        throw new IllegalArgumentException("cannot convert " + arg.getClass().getName() + " to " + dest.getName());
    }

    static Throwable unwrap(Throwable exc) {
        if (exc instanceof InvocationTargetException && exc.getCause() != null) {
            return exc.getCause();
        }
        return exc;
    }
}
