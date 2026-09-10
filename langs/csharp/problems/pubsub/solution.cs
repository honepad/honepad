public class Simulation
{
    readonly Dictionary<string, List<string>> subs = new();
    readonly Dictionary<string, List<string>> inboxMap = new();
    readonly Dictionary<string, string> retained = new();

    public Simulation() { }

    public string Subscribe(string topic, string client)
    {
        if (!subs.TryGetValue(topic, out List<string>? clients))
        {
            clients = new List<string>();
            subs[topic] = clients;
        }
        if (clients.Contains(client))
        {
            return "false";
        }
        clients.Add(client);
        if (retained.TryGetValue(topic, out string? message))
        {
            if (!inboxMap.TryGetValue(client, out List<string>? items))
            {
                items = new List<string>();
                inboxMap[client] = items;
            }
            items.Add(topic + ":" + message);
        }
        return "true";
    }

    public string Unsubscribe(string topic, string client)
    {
        if (!subs.TryGetValue(topic, out List<string>? clients) || !clients.Contains(client))
        {
            return "false";
        }
        clients.Remove(client);
        if (clients.Count == 0)
        {
            subs.Remove(topic);
        }
        return "true";
    }

    public string Publish(string topic, string message)
    {
        if (!subs.TryGetValue(topic, out List<string>? clients))
        {
            return "0";
        }
        string payload = topic + ":" + message;
        foreach (string client in clients)
        {
            if (!inboxMap.TryGetValue(client, out List<string>? items))
            {
                items = new List<string>();
                inboxMap[client] = items;
            }
            items.Add(payload);
        }
        return clients.Count.ToString();
    }

    public string Inbox(string client)
    {
        return inboxMap.TryGetValue(client, out List<string>? items) ? string.Join(", ", items) : "";
    }

    public string ListTopics()
    {
        List<string> topics = new(subs.Keys);
        topics.Sort(StringComparer.Ordinal);
        return string.Join(", ", topics);
    }

    public string Subscribers(string topic)
    {
        if (!subs.TryGetValue(topic, out List<string>? clients))
        {
            return "";
        }
        List<string> ordered = new(clients);
        ordered.Sort(StringComparer.Ordinal);
        return string.Join(", ", ordered);
    }

    public string Peek(string client)
    {
        if (!inboxMap.TryGetValue(client, out List<string>? items) || items.Count == 0)
        {
            return "";
        }
        return items[0];
    }

    public string Ack(string client, int n)
    {
        if (n <= 0 || !inboxMap.TryGetValue(client, out List<string>? items))
        {
            return "invalid_request";
        }
        if (n > items.Count)
        {
            return "invalid_request";
        }
        items.RemoveRange(0, n);
        return items.Count.ToString();
    }

    public string Retain(string topic, string message)
    {
        retained[topic] = message;
        return "";
    }
}
