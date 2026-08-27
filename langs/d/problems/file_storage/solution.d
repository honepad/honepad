import std.algorithm : sort;
import std.array : array, join;
import std.conv : to;
import std.typecons : Nullable;

class StoredFile
{
    string name;
    long size;
    string owner;

    this(string name, long size, string owner)
    {
        this.name = name;
        this.size = size;
        this.owner = owner;
    }
}

class Simulation
{
    StoredFile[string] files;
    Nullable!long[string] capacity;
    long[string][string] backups;

    this()
    {
        capacity["admin"] = Nullable!long.init;
    }

    long used(string userId)
    {
        long sum = 0;
        foreach (item; files.byValue)
        {
            if (item.owner == userId)
            {
                sum += item.size;
            }
        }
        return sum;
    }

    Nullable!long remaining(string userId)
    {
        if (userId !in capacity)
        {
            return Nullable!long.init;
        }
        auto cap = capacity[userId];
        if (cap.isNull)
        {
            return Nullable!long.init;
        }
        return Nullable!long(cap.get - used(userId));
    }

    string addFile(string name, long size)
    {
        if (name in files)
        {
            return "false";
        }
        files[name] = new StoredFile(name, size, "admin");
        return "true";
    }

    string getFileSize(string name)
    {
        if (name !in files)
        {
            return "";
        }
        return files[name].size.to!string;
    }

    string deleteFile(string name)
    {
        if (name !in files)
        {
            return "";
        }
        auto size = files[name].size;
        files.remove(name);
        return size.to!string;
    }

    string copyFile(string source, string dest)
    {
        if (source !in files)
        {
            return "";
        }
        auto src = files[source];
        if (source == dest)
        {
            return src.size.to!string;
        }
        StoredFile destItem = null;
        if (dest in files)
        {
            destItem = files[dest];
        }
        auto owner = destItem is null ? src.owner : destItem.owner;
        auto extra = destItem is null ? src.size : src.size - destItem.size;
        auto left = remaining(owner);
        if (!left.isNull && extra > left.get)
        {
            return "";
        }
        if (destItem is null)
        {
            files[dest] = new StoredFile(dest, src.size, owner);
        }
        else
        {
            destItem.size = src.size;
        }
        return src.size.to!string;
    }

    string getNLargest(string prefix, long n)
    {
        StoredFile[] matched;
        foreach (item; files.byValue)
        {
            if (item.name.length >= prefix.length && item.name[0 .. prefix.length] == prefix)
            {
                matched ~= item;
            }
        }
        matched.sort!((a, b) {
            if (a.size != b.size)
            {
                return a.size > b.size;
            }
            return a.name < b.name;
        });
        auto take = n < matched.length ? cast(size_t) n : matched.length;
        string[] parts;
        foreach (item; matched[0 .. take])
        {
            parts ~= item.name ~ "(" ~ item.size.to!string ~ ")";
        }
        return parts.join(", ");
    }

    string addUser(string userId, long cap)
    {
        if (userId in capacity)
        {
            return "false";
        }
        capacity[userId] = Nullable!long(cap);
        return "true";
    }

    string addFileBy(string userId, string name, long size)
    {
        if (userId !in capacity || name in files)
        {
            return "";
        }
        auto left = remaining(userId);
        if (!left.isNull && size > left.get)
        {
            return "";
        }
        files[name] = new StoredFile(name, size, userId);
        auto after = remaining(userId);
        if (after.isNull)
        {
            return "";
        }
        return after.get.to!string;
    }

    string mergeUser(string userId1, string userId2)
    {
        if (userId1 == userId2)
        {
            return "";
        }
        if (userId1 !in capacity || userId2 !in capacity)
        {
            return "";
        }
        auto cap1 = capacity[userId1];
        auto cap2 = capacity[userId2];
        if (cap1.isNull || cap2.isNull)
        {
            return "";
        }
        capacity[userId1] = Nullable!long(cap1.get + cap2.get);
        foreach (item; files.byValue)
        {
            if (item.owner == userId2)
            {
                item.owner = userId1;
            }
        }
        capacity.remove(userId2);
        backups.remove(userId2);
        auto left = remaining(userId1);
        if (left.isNull)
        {
            return "";
        }
        return left.get.to!string;
    }

    string backupUser(string userId)
    {
        if (userId !in capacity)
        {
            return "";
        }
        long[string] snapshot;
        foreach (item; files.byValue)
        {
            if (item.owner == userId)
            {
                snapshot[item.name] = item.size;
            }
        }
        backups[userId] = snapshot;
        return snapshot.length.to!string;
    }

    string restoreUser(string userId)
    {
        if (userId !in capacity)
        {
            return "";
        }
        string[] owned;
        foreach (name, item; files)
        {
            if (item.owner == userId)
            {
                owned ~= name;
            }
        }
        foreach (name; owned)
        {
            files.remove(name);
        }
        if (userId !in backups)
        {
            return "0";
        }
        auto snapshot = backups[userId];
        int restored = 0;
        foreach (name, size; snapshot)
        {
            if (name in files)
            {
                continue;
            }
            auto left = remaining(userId);
            if (!left.isNull && size > left.get)
            {
                continue;
            }
            files[name] = new StoredFile(name, size, userId);
            restored += 1;
        }
        return restored.to!string;
    }
}
