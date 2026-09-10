import std.algorithm : sort;
import std.array : join;
import std.conv : to;

class Simulation
{
    string[][string] subs;
    string[][string] inboxMap;
    string[string] retained;

    string subscribe(string topic, string client)
    {
        auto clients = topic in subs;
        if (clients !is null)
        {
            foreach (existing; *clients)
            {
                if (existing == client)
                {
                    return "false";
                }
            }
            *clients ~= client;
        }
        else
        {
            subs[topic] = [client];
        }
        if (topic in retained)
        {
            inboxMap[client] ~= topic ~ ":" ~ retained[topic];
        }
        return "true";
    }

    string unsubscribe(string topic, string client)
    {
        auto clients = topic in subs;
        if (clients is null)
        {
            return "false";
        }
        foreach (i, existing; *clients)
        {
            if (existing == client)
            {
                *clients = (*clients)[0 .. i] ~ (*clients)[i + 1 .. $];
                if (clients.length == 0)
                {
                    subs.remove(topic);
                }
                return "true";
            }
        }
        return "false";
    }

    string publish(string topic, string message)
    {
        auto clients = topic in subs;
        if (clients is null)
        {
            return "0";
        }
        auto payload = topic ~ ":" ~ message;
        foreach (client; *clients)
        {
            inboxMap[client] ~= payload;
        }
        return clients.length.to!string;
    }

    string inbox(string client)
    {
        auto items = client in inboxMap;
        if (items is null)
        {
            return "";
        }
        return (*items).join(", ");
    }

    string listTopics()
    {
        auto topics = subs.keys;
        topics.sort();
        return topics.join(", ");
    }

    string subscribers(string topic)
    {
        auto clients = topic in subs;
        if (clients is null)
        {
            return "";
        }
        auto ordered = (*clients).dup;
        ordered.sort();
        return ordered.join(", ");
    }

    string peek(string client)
    {
        auto items = client in inboxMap;
        if (items is null || items.length == 0)
        {
            return "";
        }
        return (*items)[0];
    }

    string ack(string client, long n)
    {
        auto items = client in inboxMap;
        if (n <= 0 || items is null)
        {
            return "invalid_request";
        }
        if (n > items.length)
        {
            return "invalid_request";
        }
        *items = (*items)[n .. $];
        return items.length.to!string;
    }

    string retain(string topic, string message)
    {
        retained[topic] = message;
        return "";
    }
}
