import std.conv : to;

class KeyState
{
    long limit = 3;
    long window = 10;
    bool hasWindow;
    long windowId;
    long used;
}

class Simulation
{
    KeyState[string] keys;

    private KeyState state(string key)
    {
        if (key !in keys)
        {
            keys[key] = new KeyState();
        }
        return keys[key];
    }

    private long usedAt(KeyState item, long timestamp, bool persist)
    {
        auto windowId = timestamp / item.window;
        if (!item.hasWindow || windowId != item.windowId)
        {
            if (persist)
            {
                item.windowId = windowId;
                item.hasWindow = true;
                item.used = 0;
            }
            return 0;
        }
        return item.used;
    }

    string allow(string key, long timestamp)
    {
        return allowWeighted(key, 1, timestamp);
    }

    string configure(string key, long limit, long window)
    {
        if (limit <= 0 || window <= 0)
        {
            return "invalid_request";
        }
        auto item = state(key);
        item.limit = limit;
        item.window = window;
        item.hasWindow = false;
        item.used = 0;
        return "true";
    }

    string remaining(string key, long timestamp)
    {
        auto item = state(key);
        auto used = usedAt(item, timestamp, false);
        return (item.limit - used).to!string;
    }

    string allowWeighted(string key, long cost, long timestamp)
    {
        if (cost <= 0)
        {
            return "invalid_request";
        }
        auto item = state(key);
        usedAt(item, timestamp, true);
        if (item.used + cost > item.limit)
        {
            return "false";
        }
        item.used += cost;
        return "true";
    }
}
