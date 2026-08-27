import std.algorithm : map;
import std.array : array;
import std.exception : enforce;
import std.file : readText;
import std.json;
import std.stdio : stderr, writeln;
import std.traits : isIntegral;
import std.typecons : Nullable;

import solution;

static if (__traits(compiles, new Simulation()))
{
    alias Target = Simulation;
}
else static if (__traits(compiles, new InMemoryDatabase()))
{
    alias Target = InMemoryDatabase;
}
else
{
    static assert(false, "solution must define Simulation or InMemoryDatabase");
}

long argLong(JSONValue args, size_t i)
{
    auto value = args.array[i];
    if (value.type == JSONType.integer)
    {
        return value.integer;
    }
    if (value.type == JSONType.uinteger)
    {
        return cast(long) value.uinteger;
    }
    throw new Exception("expected integer argument");
}

string argStr(JSONValue args, size_t i)
{
    return args.array[i].str;
}

JSONValue toNode(T)(T value)
{
    static if (is(T == bool))
    {
        return JSONValue(value);
    }
    else static if (isIntegral!T)
    {
        return JSONValue(cast(long) value);
    }
    else static if (is(T == string))
    {
        return JSONValue(value);
    }
    else static if (is(T == string[]))
    {
        return JSONValue(value.map!(item => JSONValue(item)).array);
    }
    else static if (is(T == Nullable!long))
    {
        return value.isNull ? JSONValue(null) : JSONValue(value.get);
    }
    else static if (is(T == Nullable!string))
    {
        return value.isNull ? JSONValue(null) : JSONValue(value.get);
    }
    else
    {
        static assert(false, "unsupported return type " ~ T.stringof);
    }
}

void missing(string methodName)
{
    throw new Exception("missing method " ~ methodName);
}

JSONValue dispatch(Target obj, string methodName, JSONValue args)
{
    switch (methodName)
    {
    case "create_account":
        static if (__traits(hasMember, Target, "createAccount"))
            return toNode(obj.createAccount(argLong(args, 0), argStr(args, 1)));
        missing(methodName);
        break;
    case "deposit":
        static if (__traits(hasMember, Target, "deposit"))
            return toNode(obj.deposit(argLong(args, 0), argStr(args, 1), argLong(args, 2)));
        missing(methodName);
        break;
    case "transfer":
        static if (__traits(hasMember, Target, "transfer"))
            return toNode(
                obj.transfer(argLong(args, 0), argStr(args, 1), argStr(args, 2), argLong(args, 3))
            );
        missing(methodName);
        break;
    case "top_spenders":
        static if (__traits(hasMember, Target, "topSpenders"))
            return toNode(obj.topSpenders(argLong(args, 0), argLong(args, 1)));
        missing(methodName);
        break;
    case "pay":
        static if (__traits(hasMember, Target, "pay"))
            return toNode(obj.pay(argLong(args, 0), argStr(args, 1), argLong(args, 2)));
        missing(methodName);
        break;
    case "get_payment_status":
        static if (__traits(hasMember, Target, "getPaymentStatus"))
            return toNode(obj.getPaymentStatus(argLong(args, 0), argStr(args, 1), argStr(args, 2)));
        missing(methodName);
        break;
    case "merge_accounts":
        static if (__traits(hasMember, Target, "mergeAccounts"))
            return toNode(obj.mergeAccounts(argLong(args, 0), argStr(args, 1), argStr(args, 2)));
        missing(methodName);
        break;
    case "get_balance":
        static if (__traits(hasMember, Target, "getBalance"))
            return toNode(obj.getBalance(argLong(args, 0), argStr(args, 1), argLong(args, 2)));
        missing(methodName);
        break;
    case "add_file":
        static if (__traits(hasMember, Target, "addFile"))
            return toNode(obj.addFile(argStr(args, 0), argLong(args, 1)));
        missing(methodName);
        break;
    case "get_file_size":
        static if (__traits(hasMember, Target, "getFileSize"))
            return toNode(obj.getFileSize(argStr(args, 0)));
        missing(methodName);
        break;
    case "delete_file":
        static if (__traits(hasMember, Target, "deleteFile"))
            return toNode(obj.deleteFile(argStr(args, 0)));
        missing(methodName);
        break;
    case "copy_file":
        static if (__traits(hasMember, Target, "copyFile"))
            return toNode(obj.copyFile(argStr(args, 0), argStr(args, 1)));
        missing(methodName);
        break;
    case "get_n_largest":
        static if (__traits(hasMember, Target, "getNLargest"))
            return toNode(obj.getNLargest(argStr(args, 0), argLong(args, 1)));
        missing(methodName);
        break;
    case "add_user":
        static if (__traits(hasMember, Target, "addUser"))
            return toNode(obj.addUser(argStr(args, 0), argLong(args, 1)));
        missing(methodName);
        break;
    case "add_file_by":
        static if (__traits(hasMember, Target, "addFileBy"))
            return toNode(obj.addFileBy(argStr(args, 0), argStr(args, 1), argLong(args, 2)));
        missing(methodName);
        break;
    case "merge_user":
        static if (__traits(hasMember, Target, "mergeUser"))
            return toNode(obj.mergeUser(argStr(args, 0), argStr(args, 1)));
        missing(methodName);
        break;
    case "backup_user":
        static if (__traits(hasMember, Target, "backupUser"))
            return toNode(obj.backupUser(argStr(args, 0)));
        missing(methodName);
        break;
    case "restore_user":
        static if (__traits(hasMember, Target, "restoreUser"))
            return toNode(obj.restoreUser(argStr(args, 0)));
        missing(methodName);
        break;
    case "add_worker":
        static if (__traits(hasMember, Target, "addWorker"))
            return toNode(obj.addWorker(argStr(args, 0), argStr(args, 1), argLong(args, 2)));
        missing(methodName);
        break;
    case "register":
        static if (__traits(hasMember, Target, "register"))
            return toNode(obj.register(argStr(args, 0), argLong(args, 1)));
        missing(methodName);
        break;
    case "get":
        if (args.array.length == 1)
        {
            static if (__traits(hasMember, Target, "get") && __traits(compiles, obj.get("")))
                return toNode(obj.get(argStr(args, 0)));
            missing(methodName);
        }
        else
        {
            static if (__traits(hasMember, Target, "get") && __traits(compiles, obj.get("", "")))
                return toNode(obj.get(argStr(args, 0), argStr(args, 1)));
            missing(methodName);
        }
        break;
    case "top_n_workers":
        static if (__traits(hasMember, Target, "topNWorkers"))
            return toNode(obj.topNWorkers(argLong(args, 0), argStr(args, 1)));
        missing(methodName);
        break;
    case "promote":
        static if (__traits(hasMember, Target, "promote"))
            return toNode(
                obj.promote(argStr(args, 0), argStr(args, 1), argLong(args, 2), argLong(args, 3))
            );
        missing(methodName);
        break;
    case "calc_salary":
        static if (__traits(hasMember, Target, "calcSalary"))
            return toNode(obj.calcSalary(argStr(args, 0), argLong(args, 1), argLong(args, 2)));
        missing(methodName);
        break;
    case "set":
        static if (__traits(hasMember, Target, "set"))
            return toNode(obj.set(argStr(args, 0), argStr(args, 1), argStr(args, 2)));
        missing(methodName);
        break;
    case "delete":
        static if (__traits(hasMember, Target, "deleteField"))
            return toNode(obj.deleteField(argStr(args, 0), argStr(args, 1)));
        missing(methodName);
        break;
    case "scan":
        static if (__traits(hasMember, Target, "scan"))
            return toNode(obj.scan(argStr(args, 0)));
        missing(methodName);
        break;
    case "scan_by_prefix":
        static if (__traits(hasMember, Target, "scanByPrefix"))
            return toNode(obj.scanByPrefix(argStr(args, 0), argStr(args, 1)));
        missing(methodName);
        break;
    case "set_at":
        static if (__traits(hasMember, Target, "setAt"))
            return toNode(
                obj.setAt(argStr(args, 0), argStr(args, 1), argStr(args, 2), argLong(args, 3))
            );
        missing(methodName);
        break;
    case "set_at_with_ttl":
        static if (__traits(hasMember, Target, "setAtWithTtl"))
            return toNode(
                obj.setAtWithTtl(
                    argStr(args, 0),
                    argStr(args, 1),
                    argStr(args, 2),
                    argLong(args, 3),
                    argLong(args, 4)
                )
            );
        missing(methodName);
        break;
    case "delete_at":
        static if (__traits(hasMember, Target, "deleteAt"))
            return toNode(obj.deleteAt(argStr(args, 0), argStr(args, 1), argLong(args, 2)));
        missing(methodName);
        break;
    case "get_at":
        static if (__traits(hasMember, Target, "getAt"))
            return toNode(obj.getAt(argStr(args, 0), argStr(args, 1), argLong(args, 2)));
        missing(methodName);
        break;
    case "scan_at":
        static if (__traits(hasMember, Target, "scanAt"))
            return toNode(obj.scanAt(argStr(args, 0), argLong(args, 1)));
        missing(methodName);
        break;
    case "scan_by_prefix_at":
        static if (__traits(hasMember, Target, "scanByPrefixAt"))
            return toNode(obj.scanByPrefixAt(argStr(args, 0), argStr(args, 1), argLong(args, 2)));
        missing(methodName);
        break;
    case "backup":
        static if (__traits(hasMember, Target, "backup"))
            return toNode(obj.backup(argLong(args, 0)));
        missing(methodName);
        break;
    case "restore":
        static if (__traits(hasMember, Target, "restore"))
            return toNode(obj.restore(argLong(args, 0), argLong(args, 1)));
        missing(methodName);
        break;
    default:
        throw new Exception("unknown method " ~ methodName);
    }
    assert(false);
}

JSONValue failRow(
    string caseId,
    int index,
    string methodName,
    JSONValue expected,
    JSONValue actual
)
{
    JSONValue row;
    row["case"] = caseId;
    row["index"] = index;
    row["method"] = methodName;
    row["expected"] = expected;
    row["actual"] = actual;
    return row;
}

void main(string[] args)
{
    if (args.length < 2)
    {
        stderr.writeln("usage: adapter cases.json");
        import core.stdc.stdlib : exit;

        exit(2);
    }
    auto cases = parseJSON(readText(args[1]));
    enforce(cases.type == JSONType.array, "cases.json must be a JSON list");
    JSONValue[] failed;
    int passed = 0;
    foreach (row; cases.array)
    {
        auto obj = new Target();
        auto caseId = row["id"].str;
        auto calls = row["calls"].array;
        bool ok = true;
        foreach (i, call; calls)
        {
            auto methodName = call["m"].str;
            auto expected = call["e"];
            auto argv = call["a"];
            JSONValue actual;
            try
            {
                actual = dispatch(obj, methodName, argv);
            }
            catch (Exception exc)
            {
                failed ~= failRow(caseId, cast(int) i, methodName, expected, JSONValue("exc:" ~ exc.msg));
                ok = false;
                break;
            }
            if (actual != expected)
            {
                failed ~= failRow(caseId, cast(int) i, methodName, expected, actual);
                ok = false;
                break;
            }
        }
        if (ok)
        {
            passed += 1;
        }
    }
    JSONValue report;
    report["passed"] = passed;
    report["failed"] = failed;
    writeln(report.toString());
    if (failed.length > 0)
    {
        import core.stdc.stdlib : exit;

        exit(1);
    }
}
