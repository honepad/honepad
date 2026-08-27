class StoredFile
{
    public string Name;
    public int Size;
    public string Owner;

    public StoredFile(string name, int size, string owner)
    {
        Name = name;
        Size = size;
        Owner = owner;
    }
}

public class Simulation
{
    readonly Dictionary<string, StoredFile> files = new();
    readonly Dictionary<string, int?> capacity = new() { ["admin"] = null };
    readonly Dictionary<string, Dictionary<string, int>> backups = new();

    public Simulation() { }

    int Used(string userId)
    {
        int sum = 0;
        foreach (StoredFile item in files.Values)
        {
            if (item.Owner == userId)
            {
                sum += item.Size;
            }
        }
        return sum;
    }

    int? Remaining(string userId)
    {
        if (!capacity.TryGetValue(userId, out int? cap) || cap == null)
        {
            return null;
        }
        return cap - Used(userId);
    }

    public string AddFile(string name, int size)
    {
        if (files.ContainsKey(name))
        {
            return "false";
        }
        files[name] = new StoredFile(name, size, "admin");
        return "true";
    }

    public string GetFileSize(string name)
    {
        return files.TryGetValue(name, out StoredFile? item) ? item.Size.ToString() : "";
    }

    public string DeleteFile(string name)
    {
        if (!files.Remove(name, out StoredFile? item))
        {
            return "";
        }
        return item.Size.ToString();
    }

    public string GetNLargest(string prefix, int n)
    {
        List<StoredFile> matched = files.Values.Where(item => item.Name.StartsWith(prefix, StringComparison.Ordinal)).ToList();
        matched.Sort(
            (a, b) =>
            {
                int d = b.Size.CompareTo(a.Size);
                return d != 0 ? d : string.CompareOrdinal(a.Name, b.Name);
            }
        );
        if (n < matched.Count)
        {
            matched = matched.GetRange(0, n);
        }
        return string.Join(", ", matched.Select(item => item.Name + "(" + item.Size + ")"));
    }

    public string AddUser(string userId, int cap)
    {
        if (capacity.ContainsKey(userId))
        {
            return "false";
        }
        capacity[userId] = cap;
        return "true";
    }

    public string AddFileBy(string userId, string name, int size)
    {
        if (!capacity.ContainsKey(userId) || files.ContainsKey(name))
        {
            return "";
        }
        int? left = Remaining(userId);
        if (left != null && size > left)
        {
            return "";
        }
        files[name] = new StoredFile(name, size, userId);
        int? after = Remaining(userId);
        return after == null ? "" : after.Value.ToString();
    }

    public string MergeUser(string userId1, string userId2)
    {
        if (userId1 == userId2)
        {
            return "";
        }
        if (!capacity.TryGetValue(userId1, out int? cap1) || !capacity.TryGetValue(userId2, out int? cap2))
        {
            return "";
        }
        if (cap1 == null || cap2 == null)
        {
            return "";
        }
        capacity[userId1] = cap1 + cap2;
        foreach (StoredFile item in files.Values)
        {
            if (item.Owner == userId2)
            {
                item.Owner = userId1;
            }
        }
        capacity.Remove(userId2);
        backups.Remove(userId2);
        int? left = Remaining(userId1);
        return left == null ? "" : left.Value.ToString();
    }

    public string BackupUser(string userId)
    {
        if (!capacity.ContainsKey(userId))
        {
            return "";
        }
        Dictionary<string, int> snap = new();
        foreach (StoredFile item in files.Values)
        {
            if (item.Owner == userId)
            {
                snap[item.Name] = item.Size;
            }
        }
        backups[userId] = snap;
        return snap.Count.ToString();
    }

    public string RestoreUser(string userId)
    {
        if (!capacity.ContainsKey(userId))
        {
            return "";
        }
        List<string> owned = files.Where(pair => pair.Value.Owner == userId).Select(pair => pair.Key).ToList();
        foreach (string name in owned)
        {
            files.Remove(name);
        }
        if (!backups.TryGetValue(userId, out Dictionary<string, int>? snap))
        {
            return "0";
        }
        int restored = 0;
        foreach (KeyValuePair<string, int> entry in snap)
        {
            if (files.ContainsKey(entry.Key))
            {
                continue;
            }
            int? left = Remaining(userId);
            if (left != null && entry.Value > left)
            {
                continue;
            }
            files[entry.Key] = new StoredFile(entry.Key, entry.Value, userId);
            restored += 1;
        }
        return restored.ToString();
    }
}
