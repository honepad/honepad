class Item
{
    public string Sku;
    public string Name;
    public int Qty;
    public int Reserved;

    public Item(string sku, string name)
    {
        Sku = sku;
        Name = name;
        Qty = 0;
        Reserved = 0;
    }
}

public class Simulation
{
    readonly Dictionary<string, Item> items = new();

    public Simulation() { }

    public string CreateItem(string sku, string name)
    {
        if (items.ContainsKey(sku))
        {
            return "false";
        }
        items[sku] = new Item(sku, name);
        return "true";
    }

    public string Stock(string sku, int delta)
    {
        if (!items.TryGetValue(sku, out Item? item))
        {
            return "";
        }
        int nxt = item.Qty + delta;
        if (nxt < item.Reserved)
        {
            return "invalid_request";
        }
        item.Qty = nxt;
        return item.Qty.ToString();
    }

    public string GetQty(string sku)
    {
        return items.TryGetValue(sku, out Item? item) ? item.Qty.ToString() : "";
    }

    public string ListLow(int threshold)
    {
        List<Item> matched = new();
        foreach (Item item in items.Values)
        {
            if (item.Qty <= threshold)
            {
                matched.Add(item);
            }
        }
        matched.Sort((a, b) =>
        {
            int d = a.Qty.CompareTo(b.Qty);
            return d != 0 ? d : string.CompareOrdinal(a.Sku, b.Sku);
        });
        List<string> parts = new();
        foreach (Item item in matched)
        {
            parts.Add(item.Sku + "(" + item.Qty + ")");
        }
        return string.Join(", ", parts);
    }

    public string Reserve(string sku, int n)
    {
        if (!items.TryGetValue(sku, out Item? item) || n <= 0 || item.Reserved + n > item.Qty)
        {
            return "invalid_request";
        }
        item.Reserved += n;
        return "true";
    }

    public string Release(string sku, int n)
    {
        if (!items.TryGetValue(sku, out Item? item) || n <= 0 || n > item.Reserved)
        {
            return "invalid_request";
        }
        item.Reserved -= n;
        return "true";
    }

    public string Ship(string sku, int n)
    {
        if (!items.TryGetValue(sku, out Item? item) || n <= 0 || n > item.Reserved)
        {
            return "invalid_request";
        }
        item.Reserved -= n;
        item.Qty -= n;
        return "true";
    }
}
