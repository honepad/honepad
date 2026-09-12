import java.io.ByteArrayOutputStream
import java.io.FileDescriptor
import java.io.FileOutputStream
import java.io.PrintStream
import java.lang.reflect.Field
import java.lang.reflect.InvocationTargetException
import java.lang.reflect.Method
import java.nio.file.Files
import java.nio.file.Path
import java.util.Locale

class Adapter {
    companion object {
        @JvmStatic
        fun main(args: Array<String>) {
            if (args.size < 2) {
                System.err.println("usage: java Adapter cases.json ClassName")
                System.exit(2)
            }
            val casesPath = args[0]
            val className = args[1]
            val parsed = MiniJson.parse(Files.readString(Path.of(casesPath)))
            if (parsed !is List<*>) {
                throw IllegalArgumentException("cases.json must be a JSON list")
            }
            val cls = Class.forName(className)
            val failed = ArrayList<Map<String, Any?>>()
            var passed = 0
            val reportOut = sinkStdout()
            val captured = ByteArrayOutputStream()
            val sink = PrintStream(captured, true)
            System.setOut(sink)
            try {
            for (rowObj in parsed) {
                @Suppress("UNCHECKED_CAST")
                val row = rowObj as Map<String, Any?>
                val obj = cls.getDeclaredConstructor().newInstance()
                val caseId = row["id"].toString()
                @Suppress("UNCHECKED_CAST")
                val calls = row["calls"] as List<Any?>
                var ok = true
                for (i in calls.indices) {
                    @Suppress("UNCHECKED_CAST")
                    val call = calls[i] as Map<String, Any?>
                    val methodSnake = call["m"].toString()
                    val name = toCamel(methodSnake)
                    @Suppress("UNCHECKED_CAST")
                    val argv = call["a"] as List<Any?>
                    val expected = call["e"]
                    val actual: Any?
                    try {
                        actual = invoke(obj, name, argv)
                    } catch (exc: Exception) {
                        val cause = unwrap(exc)
                        failed.add(failRow(caseId, i, methodSnake, expected, "exc:" + cause.javaClass.simpleName))
                        ok = false
                        break
                    }
                    if (MiniJson.stringify(actual) != MiniJson.stringify(expected)) {
                        failed.add(failRow(caseId, i, methodSnake, expected, actual))
                        ok = false
                        break
                    }
                }
                if (ok) {
                    passed += 1
                }
            }
            } finally {
                sink.flush()
                sink.close()
            }
            val debug = captured.toString()
            if (debug.isNotEmpty()) {
                reportOut.print(debug)
                if (!debug.endsWith("\n")) {
                    reportOut.println()
                }
            }
            val report = LinkedHashMap<String, Any?>()
            report["passed"] = passed
            report["failed"] = failed
            reportOut.println(MiniJson.stringify(report))
            reportOut.flush()
            System.exit(if (failed.isEmpty()) 0 else 1)
        }

        var stdoutNullHold: FileOutputStream? = null

        fun sinkStdout(): PrintStream {
            return try {
                val saved = FileDescriptor()
                copyNativeId(FileDescriptor.out, saved)
                val reportOut = PrintStream(FileOutputStream(saved), true)
                val nullPath =
                    if (System.getProperty("os.name", "").lowercase(Locale.ROOT).contains("win")) {
                        "NUL"
                    } else {
                        "/dev/null"
                    }
                stdoutNullHold = FileOutputStream(nullPath)
                copyNativeId(stdoutNullHold!!.fd, FileDescriptor.out)
                reportOut
            } catch (_: Exception) {
                System.out
            }
        }

        fun copyNativeId(from: FileDescriptor, to: FileDescriptor) {
            var last: Exception? = null
            var copied = false
            for (name in arrayOf("fd", "handle")) {
                try {
                    val field: Field = FileDescriptor::class.java.getDeclaredField(name)
                    field.isAccessible = true
                    field.set(to, field.get(from))
                    copied = true
                } catch (exc: ReflectiveOperationException) {
                    last = exc
                }
            }
            if (!copied) {
                throw last ?: IllegalStateException("FileDescriptor id missing")
            }
        }

        fun failRow(
            caseId: String,
            index: Int,
            method: String,
            expected: Any?,
            actual: Any?,
        ): Map<String, Any?> {
            val row = LinkedHashMap<String, Any?>()
            row["case"] = caseId
            row["index"] = index
            row["method"] = method
            row["expected"] = expected
            row["actual"] = actual
            return row
        }

        fun toCamel(snake: String): String {
            if (!snake.contains("_")) {
                return snake
            }
            val parts = snake.split("_")
            val out = StringBuilder(parts[0])
            for (i in 1 until parts.size) {
                if (parts[i].isEmpty()) {
                    continue
                }
                out.append(parts[i][0].uppercaseChar())
                if (parts[i].length > 1) {
                    out.append(parts[i].substring(1))
                }
            }
            return out.toString()
        }

        fun invoke(obj: Any, name: String, argv: List<Any?>): Any? {
            val method = findMethod(obj.javaClass, name, argv.size)
                ?: throw NoSuchMethodException(name)
            val types = method.parameterTypes
            val converted = arrayOfNulls<Any>(argv.size)
            for (i in argv.indices) {
                converted[i] = convertArg(argv[i], types[i])
            }
            return method.invoke(obj, *converted)
        }

        fun findMethod(cls: Class<*>, name: String, argc: Int): Method? {
            for (method in cls.methods) {
                if (method.name == name && method.parameterCount == argc) {
                    return method
                }
            }
            return null
        }

        fun convertArg(arg: Any?, dest: Class<*>): Any? {
            if (arg == null) {
                if (dest.isPrimitive) {
                    throw IllegalArgumentException("null for primitive " + dest.name)
                }
                return null
            }
            if (dest == String::class.java) {
                if (arg !is String) {
                    throw IllegalArgumentException("cannot convert " + arg.javaClass.name + " to String")
                }
                return arg
            }
            if (dest == Int::class.javaPrimitiveType || dest == Int::class.javaObjectType) {
                if (arg is Number) {
                    return arg.toInt()
                }
                throw IllegalArgumentException("cannot convert " + arg.javaClass.name + " to int")
            }
            if (dest == Long::class.javaPrimitiveType || dest == Long::class.javaObjectType) {
                if (arg is Number) {
                    return arg.toLong()
                }
                throw IllegalArgumentException("cannot convert " + arg.javaClass.name + " to long")
            }
            if (dest == Boolean::class.javaPrimitiveType || dest == Boolean::class.javaObjectType) {
                if (arg is Boolean) {
                    return arg
                }
                throw IllegalArgumentException("cannot convert " + arg.javaClass.name + " to boolean")
            }
            if (dest.isInstance(arg)) {
                return arg
            }
            throw IllegalArgumentException("cannot convert " + arg.javaClass.name + " to " + dest.name)
        }

        fun unwrap(exc: Throwable): Throwable {
            if (exc is InvocationTargetException && exc.cause != null) {
                return exc.cause!!
            }
            return exc
        }
    }
}
