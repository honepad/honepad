using System.Reflection;
using System.Text;
using System.Text.Json;

public class Adapter
{
    public static void Main(string[] args)
    {
        List<string> positional = args.Where(item => item.Length > 0 && item != "--" && !item.StartsWith('-')).ToList();
        if (positional.Count < 2)
        {
            Console.Error.WriteLine("usage: honepadrun cases.json ClassName");
            Environment.Exit(2);
        }

        string casesPath = positional[0];
        string className = positional[1];
        using JsonDocument doc = JsonDocument.Parse(File.ReadAllText(casesPath));
        if (doc.RootElement.ValueKind != JsonValueKind.Array)
        {
            throw new InvalidOperationException("cases.json must be a JSON list");
        }

        Type type =
            typeof(Adapter).Assembly.GetTypes().FirstOrDefault(item => item.Name == className)
            ?? throw new InvalidOperationException("missing type " + className);

        List<Dictionary<string, object?>> failed = new();
        int passed = 0;
        foreach (JsonElement row in doc.RootElement.EnumerateArray())
        {
            object obj =
                Activator.CreateInstance(type)
                ?? throw new InvalidOperationException("could not construct " + className);
            string caseId = row.GetProperty("id").GetString() ?? "";
            JsonElement calls = row.GetProperty("calls");
            bool ok = true;
            int index = 0;
            foreach (JsonElement call in calls.EnumerateArray())
            {
                string methodSnake = call.GetProperty("m").GetString() ?? "";
                string name = ToPascal(methodSnake);
                List<JsonElement> argv = call.GetProperty("a").EnumerateArray().ToList();
                JsonElement expected = call.GetProperty("e");
                object? actual;
                try
                {
                    actual = Invoke(obj, name, argv);
                }
                catch (Exception exc)
                {
                    failed.Add(FailRow(caseId, index, methodSnake, expected, "exc:" + Unwrap(exc).GetType().Name));
                    ok = false;
                    break;
                }
                if (!JsonEqual(actual, expected))
                {
                    failed.Add(FailRow(caseId, index, methodSnake, expected, actual));
                    ok = false;
                    break;
                }
                index += 1;
            }
            if (ok)
            {
                passed += 1;
            }
        }

        Dictionary<string, object?> report = new()
        {
            ["passed"] = passed,
            ["failed"] = failed,
        };
        Console.WriteLine(JsonSerializer.Serialize(report));
        Environment.Exit(failed.Count == 0 ? 0 : 1);
    }

    static Dictionary<string, object?> FailRow(
        string caseId,
        int index,
        string method,
        JsonElement expected,
        object? actual
    )
    {
        return new Dictionary<string, object?>
        {
            ["case"] = caseId,
            ["index"] = index,
            ["method"] = method,
            ["expected"] = expected,
            ["actual"] = actual,
        };
    }

    static string ToPascal(string snake)
    {
        string[] parts = snake.Split('_');
        StringBuilder output = new();
        foreach (string part in parts)
        {
            if (part.Length == 0)
            {
                continue;
            }
            output.Append(char.ToUpperInvariant(part[0]));
            if (part.Length > 1)
            {
                output.Append(part[1..]);
            }
        }
        return output.ToString();
    }

    static object? Invoke(object obj, string name, List<JsonElement> argv)
    {
        MethodInfo method =
            FindMethod(obj.GetType(), name, argv.Count)
            ?? throw new MissingMethodException(name);
        ParameterInfo[] types = method.GetParameters();
        object?[] converted = new object?[argv.Count];
        for (int i = 0; i < argv.Count; i++)
        {
            converted[i] = ConvertArg(argv[i], types[i].ParameterType);
        }
        return method.Invoke(obj, converted);
    }

    static MethodInfo? FindMethod(Type type, string name, int argc)
    {
        foreach (MethodInfo method in type.GetMethods())
        {
            if (method.Name == name && method.GetParameters().Length == argc)
            {
                return method;
            }
        }
        return null;
    }

    static object? ConvertArg(JsonElement arg, Type dest)
    {
        Type inner = Nullable.GetUnderlyingType(dest) ?? dest;
        if (arg.ValueKind == JsonValueKind.Null)
        {
            if (dest.IsValueType && Nullable.GetUnderlyingType(dest) == null)
            {
                throw new ArgumentException("null for non-nullable " + dest.Name);
            }
            return null;
        }
        if (inner == typeof(string))
        {
            if (arg.ValueKind != JsonValueKind.String)
            {
                throw new ArgumentException("cannot convert " + arg.ValueKind + " to string");
            }
            return arg.GetString();
        }
        if (inner == typeof(int))
        {
            if (arg.ValueKind != JsonValueKind.Number)
            {
                throw new ArgumentException("cannot convert " + arg.ValueKind + " to int");
            }
            return arg.GetInt32();
        }
        if (inner == typeof(long))
        {
            if (arg.ValueKind != JsonValueKind.Number)
            {
                throw new ArgumentException("cannot convert " + arg.ValueKind + " to long");
            }
            return arg.GetInt64();
        }
        if (inner == typeof(bool))
        {
            if (arg.ValueKind is not (JsonValueKind.True or JsonValueKind.False))
            {
                throw new ArgumentException("cannot convert " + arg.ValueKind + " to bool");
            }
            return arg.GetBoolean();
        }
        throw new ArgumentException("cannot convert " + arg.ValueKind + " to " + dest.Name);
    }

    static bool JsonEqual(object? actual, JsonElement expected)
    {
        return JsonSerializer.Serialize(actual) == JsonSerializer.Serialize(expected);
    }

    static Exception Unwrap(Exception exc)
    {
        if (exc is TargetInvocationException { InnerException: { } inner })
        {
            return inner;
        }
        return exc;
    }
}
