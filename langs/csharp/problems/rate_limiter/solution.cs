class KeyState
{
    public int Limit = 3;
    public int Window = 10;
    public int? WindowId;
    public int Used;
}

public class Simulation
{
    readonly Dictionary<string, KeyState> keys = new();

    public Simulation() { }

    KeyState State(string key)
    {
        if (!keys.TryGetValue(key, out KeyState? item))
        {
            item = new KeyState();
            keys[key] = item;
        }
        return item;
    }

    static int UsedAt(KeyState item, int timestamp, bool persist)
    {
        int windowId = timestamp / item.Window;
        if (item.WindowId is null || windowId != item.WindowId)
        {
            if (persist)
            {
                item.WindowId = windowId;
                item.Used = 0;
            }
            return 0;
        }
        return item.Used;
    }

    public string Allow(string key, int timestamp)
    {
        return AllowWeighted(key, 1, timestamp);
    }

    public string Configure(string key, int limit, int window)
    {
        if (limit <= 0 || window <= 0)
        {
            return "invalid_request";
        }
        KeyState item = State(key);
        item.Limit = limit;
        item.Window = window;
        item.WindowId = null;
        item.Used = 0;
        return "true";
    }

    public string Remaining(string key, int timestamp)
    {
        KeyState item = State(key);
        int used = UsedAt(item, timestamp, false);
        return (item.Limit - used).ToString();
    }

    public string AllowWeighted(string key, int cost, int timestamp)
    {
        if (cost <= 0)
        {
            return "invalid_request";
        }
        KeyState item = State(key);
        UsedAt(item, timestamp, true);
        if (item.Used + cost > item.Limit)
        {
            return "false";
        }
        item.Used += cost;
        return "true";
    }
}
