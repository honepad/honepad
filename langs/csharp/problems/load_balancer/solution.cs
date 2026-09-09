class Backend
{
    public string BackendId;
    public bool Health = true;
    public int Weight = 1;
    public int Inflight;

    public Backend(string backendId)
    {
        BackendId = backendId;
    }
}

public class Simulation
{
    readonly List<Backend> backends = new();
    readonly Dictionary<string, Backend> byId = new();
    int cursor;
    readonly Dictionary<string, string> stickyMap = new();
    bool useLeast;

    public Simulation() { }

    public string AddBackend(string backendId)
    {
        if (byId.ContainsKey(backendId))
        {
            return "false";
        }
        Backend item = new(backendId);
        backends.Add(item);
        byId[backendId] = item;
        return "true";
    }

    public string SetHealth(string backendId, int flag)
    {
        if (!byId.TryGetValue(backendId, out Backend? item) || (flag != 0 && flag != 1))
        {
            return "invalid_request";
        }
        item.Health = flag == 1;
        ResetCycle();
        return "true";
    }

    public string SetWeight(string backendId, int weight)
    {
        if (!byId.TryGetValue(backendId, out Backend? item) || weight <= 0)
        {
            return "invalid_request";
        }
        item.Weight = weight;
        ResetCycle();
        return "true";
    }

    void ResetCycle()
    {
        cursor = 0;
        useLeast = false;
        foreach (Backend item in backends)
        {
            item.Inflight = 0;
        }
    }

    List<Backend> Tickets(List<Backend> items)
    {
        List<Backend> tickets = new();
        foreach (Backend item in items)
        {
            for (int i = 0; i < item.Weight; i++)
            {
                tickets.Add(item);
            }
        }
        return tickets;
    }

    Backend? Pick()
    {
        List<Backend> healthy = new();
        foreach (Backend item in backends)
        {
            if (item.Health)
            {
                healthy.Add(item);
            }
        }
        if (healthy.Count == 0)
        {
            return null;
        }
        List<Backend> pool = healthy;
        if (useLeast)
        {
            int least = healthy[0].Inflight;
            for (int i = 1; i < healthy.Count; i++)
            {
                if (healthy[i].Inflight < least)
                {
                    least = healthy[i].Inflight;
                }
            }
            pool = new List<Backend>();
            foreach (Backend item in healthy)
            {
                if (item.Inflight == least)
                {
                    pool.Add(item);
                }
            }
        }
        List<Backend> tickets = Tickets(pool);
        if (tickets.Count == 0)
        {
            return null;
        }
        Backend chosen = tickets[cursor % tickets.Count];
        cursor += 1;
        return chosen;
    }

    string Take()
    {
        Backend? item = Pick();
        if (item == null)
        {
            return "";
        }
        item.Inflight += 1;
        return item.BackendId;
    }

    public string Route()
    {
        return Take();
    }

    public string Sticky(string clientId)
    {
        if (stickyMap.TryGetValue(clientId, out string? bound) &&
            byId.TryGetValue(bound, out Backend? item) &&
            item.Health)
        {
            item.Inflight += 1;
            return item.BackendId;
        }
        string chosen = Take();
        if (chosen.Length > 0)
        {
            stickyMap[clientId] = chosen;
        }
        return chosen;
    }

    public string Done(string backendId)
    {
        if (!byId.TryGetValue(backendId, out Backend? item) || item.Inflight <= 0)
        {
            return "invalid_request";
        }
        item.Inflight -= 1;
        useLeast = true;
        return "true";
    }
}
