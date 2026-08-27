import java.lang.reflect.InvocationTargetException
import java.lang.reflect.Method
import java.nio.file.Files
import java.nio.file.Path
import java.util.{ArrayList, LinkedHashMap, List => JList, Map => JMap}

object Adapter {
  def main(args: Array[String]): Unit = {
    if (args.length < 2) {
      System.err.println("usage: java Adapter cases.json ClassName")
      System.exit(2)
    }
    val casesPath = args(0)
    val className = args(1)
    val parsed = MiniJson.parse(Files.readString(Path.of(casesPath)))
    if (!parsed.isInstanceOf[JList[_]]) {
      throw new IllegalArgumentException("cases.json must be a JSON list")
    }
    val cases = parsed.asInstanceOf[JList[_]]
    val cls = Class.forName(className)
    val failed = new ArrayList[JMap[String, Object]]()
    var passed = 0
    val caseIt = cases.iterator()
    while (caseIt.hasNext) {
      val row = caseIt.next().asInstanceOf[JMap[String, Object]]
      val obj = cls.getDeclaredConstructor().newInstance()
      val caseId = String.valueOf(row.get("id"))
      val calls = row.get("calls").asInstanceOf[JList[_]]
      var ok = true
      var i = 0
      while (i < calls.size() && ok) {
        val call = calls.get(i).asInstanceOf[JMap[String, Object]]
        val methodSnake = String.valueOf(call.get("m"))
        val name = toCamel(methodSnake)
        val argv = call.get("a").asInstanceOf[JList[Object]]
        val expected = call.get("e")
        try {
          val actual = invoke(obj, name, argv)
          if (MiniJson.stringify(actual) != MiniJson.stringify(expected)) {
            failed.add(failRow(caseId, i, methodSnake, expected, actual))
            ok = false
          }
        } catch {
          case exc: Exception =>
            val cause = unwrap(exc)
            failed.add(
              failRow(caseId, i, methodSnake, expected, "exc:" + cause.getClass.getSimpleName)
            )
            ok = false
        }
        i += 1
      }
      if (ok) {
        passed += 1
      }
    }
    val report = new LinkedHashMap[String, Object]()
    report.put("passed", Int.box(passed))
    report.put("failed", failed)
    System.out.println(MiniJson.stringify(report))
    System.exit(if (failed.isEmpty) 0 else 1)
  }

  def failRow(
      caseId: String,
      index: Int,
      method: String,
      expected: Object,
      actual: Object
  ): JMap[String, Object] = {
    val row = new LinkedHashMap[String, Object]()
    row.put("case", caseId)
    row.put("index", Int.box(index))
    row.put("method", method)
    row.put("expected", expected)
    row.put("actual", actual)
    row
  }

  def toCamel(snake: String): String = {
    if (!snake.contains("_")) {
      return snake
    }
    val parts = snake.split("_", -1)
    val out = new StringBuilder(parts(0))
    var i = 1
    while (i < parts.length) {
      if (parts(i).nonEmpty) {
        out.append(parts(i).charAt(0).toUpper)
        if (parts(i).length > 1) {
          out.append(parts(i).substring(1))
        }
      }
      i += 1
    }
    out.toString
  }

  def invoke(obj: AnyRef, name: String, argv: JList[Object]): Object = {
    val method = findMethod(obj.getClass, name, argv.size())
    if (method == null) {
      throw new NoSuchMethodException(name)
    }
    val types = method.getParameterTypes
    val converted = new Array[Object](argv.size())
    var i = 0
    while (i < argv.size()) {
      converted(i) = convertArg(argv.get(i), types(i))
      i += 1
    }
    method.invoke(obj, converted: _*)
  }

  def findMethod(cls: Class[_], name: String, argc: Int): Method = {
    val methods = cls.getMethods
    var i = 0
    while (i < methods.length) {
      val method = methods(i)
      if (method.getName == name && method.getParameterCount == argc) {
        return method
      }
      i += 1
    }
    null
  }

  def convertArg(arg: Object, dest: Class[_]): Object = {
    if (arg == null) {
      if (dest.isPrimitive) {
        throw new IllegalArgumentException("null for primitive " + dest.getName)
      }
      return null
    }
    if (dest == classOf[String]) {
      if (!arg.isInstanceOf[String]) {
        throw new IllegalArgumentException("cannot convert " + arg.getClass.getName + " to String")
      }
      return arg
    }
    if (dest == java.lang.Integer.TYPE || dest == classOf[Integer]) {
      arg match {
        case n: java.lang.Number => Int.box(n.intValue())
        case _ =>
          throw new IllegalArgumentException("cannot convert " + arg.getClass.getName + " to int")
      }
    } else if (dest == java.lang.Long.TYPE || dest == classOf[java.lang.Long]) {
      arg match {
        case n: java.lang.Number => Long.box(n.longValue())
        case _ =>
          throw new IllegalArgumentException("cannot convert " + arg.getClass.getName + " to long")
      }
    } else if (dest == java.lang.Boolean.TYPE || dest == classOf[java.lang.Boolean]) {
      arg match {
        case b: java.lang.Boolean => b
        case _ =>
          throw new IllegalArgumentException(
            "cannot convert " + arg.getClass.getName + " to boolean"
          )
      }
    } else if (dest.isInstance(arg)) {
      arg
    } else {
      throw new IllegalArgumentException("cannot convert " + arg.getClass.getName + " to " + dest.getName)
    }
  }

  def unwrap(exc: Throwable): Throwable = {
    exc match {
      case ite: InvocationTargetException if ite.getCause != null => ite.getCause
      case other => other
    }
  }
}
