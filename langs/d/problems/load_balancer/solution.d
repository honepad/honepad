class Backend
{
    string backendId;
    bool health = true;
    long weight = 1;
    long inflight;

    this(string backendId)
    {
        this.backendId = backendId;
    }
}

class Simulation
{
    Backend[] backends;
    Backend[string] byId;
    long cursor;
    string[string] stickyMap;
    bool useLeast;

    string addBackend(string backendId)
    {
        if (backendId in byId)
        {
            return "false";
        }
        auto item = new Backend(backendId);
        backends ~= item;
        byId[backendId] = item;
        return "true";
    }

    private void resetCycle()
    {
        cursor = 0;
        useLeast = false;
        foreach (item; backends)
        {
            item.inflight = 0;
        }
    }

    string setHealth(string backendId, long flag)
    {
        if (backendId !in byId || (flag != 0 && flag != 1))
        {
            return "invalid_request";
        }
        byId[backendId].health = flag == 1;
        resetCycle();
        return "true";
    }

    string setWeight(string backendId, long weight)
    {
        if (backendId !in byId || weight <= 0)
        {
            return "invalid_request";
        }
        byId[backendId].weight = weight;
        resetCycle();
        return "true";
    }

    private Backend[] tickets(Backend[] items)
    {
        Backend[] outItems;
        foreach (item; items)
        {
            foreach (_; 0 .. item.weight)
            {
                outItems ~= item;
            }
        }
        return outItems;
    }

    private Backend pick()
    {
        Backend[] healthy;
        foreach (item; backends)
        {
            if (item.health)
            {
                healthy ~= item;
            }
        }
        if (healthy.length == 0)
        {
            return null;
        }
        Backend[] pool = healthy;
        if (useLeast)
        {
            long least = healthy[0].inflight;
            foreach (item; healthy)
            {
                if (item.inflight < least)
                {
                    least = item.inflight;
                }
            }
            pool = [];
            foreach (item; healthy)
            {
                if (item.inflight == least)
                {
                    pool ~= item;
                }
            }
        }
        auto ticketList = tickets(pool);
        if (ticketList.length == 0)
        {
            return null;
        }
        auto chosen = ticketList[cursor % ticketList.length];
        cursor += 1;
        return chosen;
    }

    private string take()
    {
        auto item = pick();
        if (item is null)
        {
            return "";
        }
        item.inflight += 1;
        return item.backendId;
    }

    string route()
    {
        return take();
    }

    string sticky(string clientId)
    {
        if (clientId in stickyMap)
        {
            auto bound = stickyMap[clientId];
            if (bound in byId)
            {
                auto item = byId[bound];
                if (item.health)
                {
                    item.inflight += 1;
                    return item.backendId;
                }
            }
        }
        auto chosen = take();
        if (chosen.length > 0)
        {
            stickyMap[clientId] = chosen;
        }
        return chosen;
    }

    string done(string backendId)
    {
        if (backendId !in byId || byId[backendId].inflight <= 0)
        {
            return "invalid_request";
        }
        byId[backendId].inflight -= 1;
        useLeast = true;
        return "true";
    }
}
