class FieldVal
{
    public string Value;
    public int? Expiry;

    public FieldVal(string value, int? expiry)
    {
        Value = value;
        Expiry = expiry;
    }
}

class BackupField
{
    public string Value;
    public int? Remaining;

    public BackupField(string value, int? remaining)
    {
        Value = value;
        Remaining = remaining;
    }
}

public class InMemoryDatabase
{
    readonly Dictionary<string, Dictionary<string, FieldVal>> database = new();
    readonly List<int> backupTimestamps = new();
    readonly List<Dictionary<string, Dictionary<string, BackupField>>> backupStates = new();

    public InMemoryDatabase() { }

    string SetInternal(string key, string field, string value, int? expiry)
    {
        if (!database.TryGetValue(key, out Dictionary<string, FieldVal>? fields))
        {
            fields = new Dictionary<string, FieldVal>();
            database[key] = fields;
        }
        fields[field] = new FieldVal(value, expiry);
        return "";
    }

    bool IsAlive(string key, string field, int timestamp)
    {
        if (!database.TryGetValue(key, out Dictionary<string, FieldVal>? fields) || !fields.ContainsKey(field))
        {
            return false;
        }
        int? expiry = fields[field].Expiry;
        return expiry == null || timestamp < expiry;
    }

    public string Set(string key, string field, string value)
    {
        return SetInternal(key, field, value, null);
    }

    public string Get(string key, string field)
    {
        if (!database.TryGetValue(key, out Dictionary<string, FieldVal>? fields) || !fields.ContainsKey(field))
        {
            return "";
        }
        return fields[field].Value;
    }

    public string Delete(string key, string field)
    {
        if (!database.TryGetValue(key, out Dictionary<string, FieldVal>? fields) || !fields.ContainsKey(field))
        {
            return "false";
        }
        fields.Remove(field);
        return "true";
    }

    public string Scan(string key)
    {
        if (!database.TryGetValue(key, out Dictionary<string, FieldVal>? fields))
        {
            return "";
        }
        List<string> names = fields.Keys.ToList();
        names.Sort(StringComparer.Ordinal);
        return string.Join(", ", names.Select(field => field + "(" + fields[field].Value + ")"));
    }

    public string ScanByPrefix(string key, string prefix)
    {
        if (!database.TryGetValue(key, out Dictionary<string, FieldVal>? fields))
        {
            return "";
        }
        List<string> names = fields.Keys.Where(field => field.StartsWith(prefix, StringComparison.Ordinal)).ToList();
        names.Sort(StringComparer.Ordinal);
        return string.Join(", ", names.Select(field => field + "(" + fields[field].Value + ")"));
    }

    public string SetAt(string key, string field, string value, int timestamp)
    {
        _ = timestamp;
        return SetInternal(key, field, value, null);
    }

    public string SetAtWithTtl(string key, string field, string value, int timestamp, int ttl)
    {
        return SetInternal(key, field, value, timestamp + ttl);
    }

    public string DeleteAt(string key, string field, int timestamp)
    {
        if (!IsAlive(key, field, timestamp))
        {
            return "false";
        }
        database[key].Remove(field);
        return "true";
    }

    public string GetAt(string key, string field, int timestamp)
    {
        if (!IsAlive(key, field, timestamp))
        {
            return "";
        }
        return database[key][field].Value;
    }

    public string ScanAt(string key, int timestamp)
    {
        if (!database.TryGetValue(key, out Dictionary<string, FieldVal>? fields))
        {
            return "";
        }
        List<string> names = fields.Keys.Where(field => IsAlive(key, field, timestamp)).ToList();
        names.Sort(StringComparer.Ordinal);
        return string.Join(", ", names.Select(field => field + "(" + fields[field].Value + ")"));
    }

    public string ScanByPrefixAt(string key, string prefix, int timestamp)
    {
        if (!database.TryGetValue(key, out Dictionary<string, FieldVal>? fields))
        {
            return "";
        }
        List<string> names = fields
            .Keys.Where(field => field.StartsWith(prefix, StringComparison.Ordinal) && IsAlive(key, field, timestamp))
            .ToList();
        names.Sort(StringComparer.Ordinal);
        return string.Join(", ", names.Select(field => field + "(" + fields[field].Value + ")"));
    }

    public string Backup(int timestamp)
    {
        Dictionary<string, Dictionary<string, BackupField>> state = new();
        foreach (KeyValuePair<string, Dictionary<string, FieldVal>> keyEntry in database)
        {
            string key = keyEntry.Key;
            foreach (KeyValuePair<string, FieldVal> fieldEntry in keyEntry.Value)
            {
                string field = fieldEntry.Key;
                if (IsAlive(key, field, timestamp))
                {
                    FieldVal pair = fieldEntry.Value;
                    int? remaining = pair.Expiry == null ? null : pair.Expiry - timestamp;
                    if (!state.TryGetValue(key, out Dictionary<string, BackupField>? fields))
                    {
                        fields = new Dictionary<string, BackupField>();
                        state[key] = fields;
                    }
                    fields[field] = new BackupField(pair.Value, remaining);
                }
            }
        }
        backupTimestamps.Add(timestamp);
        backupStates.Add(state);
        return state.Count.ToString();
    }

    public string Restore(int timestamp, int timestampToRestore)
    {
        int idx = -1;
        for (int i = 0; i < backupTimestamps.Count; i++)
        {
            if (backupTimestamps[i] <= timestampToRestore)
            {
                idx = i;
            }
        }
        Dictionary<string, Dictionary<string, BackupField>> backup = backupStates[idx];
        database.Clear();
        foreach (KeyValuePair<string, Dictionary<string, BackupField>> keyEntry in backup)
        {
            foreach (KeyValuePair<string, BackupField> fieldEntry in keyEntry.Value)
            {
                BackupField pair = fieldEntry.Value;
                int? expiry = pair.Remaining == null ? null : timestamp + pair.Remaining;
                SetInternal(keyEntry.Key, fieldEntry.Key, pair.Value, expiry);
            }
        }
        return "";
    }
}
