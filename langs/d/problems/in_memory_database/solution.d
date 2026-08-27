import std.algorithm : sort;
import std.array : array, join;
import std.typecons : Nullable;

struct FieldVal
{
    string value;
    Nullable!long expiry;
}

class InMemoryDatabase
{
    FieldVal[string][string] database;
    long[] backupTimestamps;
    FieldVal[string][string][] backupStates;

    string setInternal(string key, string field, string value, Nullable!long expiry)
    {
        database[key][field] = FieldVal(value, expiry);
        return "";
    }

    bool isAlive(string key, string field, long timestamp)
    {
        if (key !in database || field !in database[key])
        {
            return false;
        }
        auto expiry = database[key][field].expiry;
        if (expiry.isNull)
        {
            return true;
        }
        return timestamp < expiry.get;
    }

    string set(string key, string field, string value)
    {
        return setInternal(key, field, value, Nullable!long.init);
    }

    string get(string key, string field)
    {
        if (key !in database || field !in database[key])
        {
            return "";
        }
        return database[key][field].value;
    }

    string deleteField(string key, string field)
    {
        if (key !in database || field !in database[key])
        {
            return "false";
        }
        database[key].remove(field);
        return "true";
    }

    string scan(string key)
    {
        if (key !in database)
        {
            return "";
        }
        auto names = database[key].keys.array;
        names.sort();
        string[] parts;
        foreach (field; names)
        {
            parts ~= field ~ "(" ~ database[key][field].value ~ ")";
        }
        return parts.join(", ");
    }

    string scanByPrefix(string key, string prefix)
    {
        if (key !in database)
        {
            return "";
        }
        string[] names;
        foreach (field; database[key].keys)
        {
            if (field.length >= prefix.length && field[0 .. prefix.length] == prefix)
            {
                names ~= field;
            }
        }
        names.sort();
        string[] parts;
        foreach (field; names)
        {
            parts ~= field ~ "(" ~ database[key][field].value ~ ")";
        }
        return parts.join(", ");
    }

    string setAt(string key, string field, string value, long timestamp)
    {
        return setInternal(key, field, value, Nullable!long.init);
    }

    string setAtWithTtl(string key, string field, string value, long timestamp, long ttl)
    {
        return setInternal(key, field, value, Nullable!long(timestamp + ttl));
    }

    string deleteAt(string key, string field, long timestamp)
    {
        if (!isAlive(key, field, timestamp))
        {
            return "false";
        }
        database[key].remove(field);
        return "true";
    }

    string getAt(string key, string field, long timestamp)
    {
        if (!isAlive(key, field, timestamp))
        {
            return "";
        }
        return database[key][field].value;
    }

    string scanAt(string key, long timestamp)
    {
        if (key !in database)
        {
            return "";
        }
        string[] names;
        foreach (field; database[key].keys)
        {
            if (isAlive(key, field, timestamp))
            {
                names ~= field;
            }
        }
        names.sort();
        string[] parts;
        foreach (field; names)
        {
            parts ~= field ~ "(" ~ database[key][field].value ~ ")";
        }
        return parts.join(", ");
    }

    string scanByPrefixAt(string key, string prefix, long timestamp)
    {
        if (key !in database)
        {
            return "";
        }
        string[] names;
        foreach (field; database[key].keys)
        {
            if (field.length >= prefix.length && field[0 .. prefix.length] == prefix
                && isAlive(key, field, timestamp))
            {
                names ~= field;
            }
        }
        names.sort();
        string[] parts;
        foreach (field; names)
        {
            parts ~= field ~ "(" ~ database[key][field].value ~ ")";
        }
        return parts.join(", ");
    }

    string backup(long timestamp)
    {
        FieldVal[string][string] state;
        foreach (key, fields; database)
        {
            foreach (field, pair; fields)
            {
                if (isAlive(key, field, timestamp))
                {
                    Nullable!long remaining;
                    if (!pair.expiry.isNull)
                    {
                        remaining = pair.expiry.get - timestamp;
                    }
                    state[key][field] = FieldVal(pair.value, remaining);
                }
            }
        }
        backupTimestamps ~= timestamp;
        backupStates ~= state;
        return state.length.toString;
    }

    string restore(long timestamp, long timestampToRestore)
    {
        auto idx = -1;
        foreach (i, ts; backupTimestamps)
        {
            if (ts <= timestampToRestore)
            {
                idx = cast(int) i;
            }
        }
        auto backup = backupStates[idx];
        database = null;
        foreach (key, fields; backup)
        {
            foreach (field, pair; fields)
            {
                Nullable!long expiry;
                if (!pair.expiry.isNull)
                {
                    expiry = timestamp + pair.expiry.get;
                }
                setInternal(key, field, pair.value, expiry);
            }
        }
        return "";
    }
}

private string toString(size_t value)
{
    import std.conv : to;

    return value.to!string;
}
