import std.algorithm : sort;
import std.array : join;
import std.conv : to;

class Item
{
    string sku;
    string name;
    long qty;
    long reserved;

    this(string sku, string name)
    {
        this.sku = sku;
        this.name = name;
    }
}

class Simulation
{
    Item[string] items;

    string createItem(string sku, string name)
    {
        if (sku in items)
        {
            return "false";
        }
        items[sku] = new Item(sku, name);
        return "true";
    }

    string stock(string sku, long delta)
    {
        if (sku !in items)
        {
            return "";
        }
        auto item = items[sku];
        auto nxt = item.qty + delta;
        if (nxt < item.reserved)
        {
            return "invalid_request";
        }
        item.qty = nxt;
        return item.qty.to!string;
    }

    string getQty(string sku)
    {
        if (sku !in items)
        {
            return "";
        }
        return items[sku].qty.to!string;
    }

    string listLow(long threshold)
    {
        Item[] matched;
        foreach (item; items.byValue)
        {
            if (item.qty <= threshold)
            {
                matched ~= item;
            }
        }
        matched.sort!((a, b) {
            if (a.qty != b.qty)
            {
                return a.qty < b.qty;
            }
            return a.sku < b.sku;
        });
        string[] parts;
        foreach (item; matched)
        {
            parts ~= item.sku ~ "(" ~ item.qty.to!string ~ ")";
        }
        return parts.join(", ");
    }

    string reserve(string sku, long n)
    {
        if (sku !in items || n <= 0 || items[sku].reserved + n > items[sku].qty)
        {
            return "invalid_request";
        }
        items[sku].reserved += n;
        return "true";
    }

    string release(string sku, long n)
    {
        if (sku !in items || n <= 0 || n > items[sku].reserved)
        {
            return "invalid_request";
        }
        items[sku].reserved -= n;
        return "true";
    }

    string ship(string sku, long n)
    {
        if (sku !in items || n <= 0 || n > items[sku].reserved)
        {
            return "invalid_request";
        }
        items[sku].reserved -= n;
        items[sku].qty -= n;
        return "true";
    }
}
