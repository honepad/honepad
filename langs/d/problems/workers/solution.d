import std.algorithm : sort;
import std.array : join;
import std.conv : to;
import std.typecons : Nullable;

struct WorkSession
{
    long start;
    long end;
    long rate;
    string position;
}

struct Promo
{
    string position;
    long compensation;
    long startTimestamp;
}

class Worker
{
    string workerId;
    string position;
    long compensation;
    bool inOffice;
    Nullable!long enteredAt;
    WorkSession[] finished;
    Nullable!Promo pendingPromo;

    this(string workerId, string position, long compensation)
    {
        this.workerId = workerId;
        this.position = position;
        this.compensation = compensation;
    }

    long totalTime()
    {
        long sum = 0;
        foreach (session; finished)
        {
            sum += session.end - session.start;
        }
        return sum;
    }

    long positionTime(string pos)
    {
        long sum = 0;
        foreach (session; finished)
        {
            if (session.position == pos)
            {
                sum += session.end - session.start;
            }
        }
        return sum;
    }

    void applyPromoOnEnter(long timestamp)
    {
        if (pendingPromo.isNull)
        {
            return;
        }
        auto promo = pendingPromo.get;
        if (timestamp >= promo.startTimestamp)
        {
            position = promo.position;
            compensation = promo.compensation;
            pendingPromo.nullify();
        }
    }
}

class Simulation
{
    Worker[string] workers;

    string addWorker(string workerId, string position, long compensation)
    {
        if (workerId in workers)
        {
            return "false";
        }
        workers[workerId] = new Worker(workerId, position, compensation);
        return "true";
    }

    string register(string workerId, long timestamp)
    {
        if (workerId !in workers)
        {
            return "invalid_request";
        }
        auto worker = workers[workerId];
        if (worker.inOffice)
        {
            worker.finished ~= WorkSession(
                worker.enteredAt.get,
                timestamp,
                worker.compensation,
                worker.position
            );
            worker.inOffice = false;
            worker.enteredAt.nullify();
            return "registered";
        }
        worker.applyPromoOnEnter(timestamp);
        worker.inOffice = true;
        worker.enteredAt = timestamp;
        return "registered";
    }

    string get(string workerId)
    {
        if (workerId !in workers)
        {
            return "";
        }
        return workers[workerId].totalTime().to!string;
    }

    string topNWorkers(long n, string position)
    {
        Worker[] matched;
        foreach (worker; workers.byValue)
        {
            if (worker.position == position)
            {
                matched ~= worker;
            }
        }
        matched.sort!((a, b) {
            auto aTime = a.positionTime(position);
            auto bTime = b.positionTime(position);
            if (aTime != bTime)
            {
                return aTime > bTime;
            }
            return a.workerId < b.workerId;
        });
        auto take = n < matched.length ? cast(size_t) n : matched.length;
        string[] parts;
        foreach (worker; matched[0 .. take])
        {
            parts ~= worker.workerId ~ "(" ~ worker.positionTime(position).to!string ~ ")";
        }
        return parts.join(", ");
    }

    string promote(string workerId, string newPosition, long newCompensation, long startTimestamp)
    {
        if (workerId !in workers)
        {
            return "invalid_request";
        }
        auto worker = workers[workerId];
        if (!worker.pendingPromo.isNull)
        {
            return "invalid_request";
        }
        worker.pendingPromo = Promo(newPosition, newCompensation, startTimestamp);
        return "success";
    }

    string calcSalary(string workerId, long startTimestamp, long endTimestamp)
    {
        if (workerId !in workers)
        {
            return "";
        }
        long total = 0;
        foreach (session; workers[workerId].finished)
        {
            auto lo = session.start > startTimestamp ? session.start : startTimestamp;
            auto hi = session.end < endTimestamp ? session.end : endTimestamp;
            if (hi > lo)
            {
                total += (hi - lo) * session.rate;
            }
        }
        return total.to!string;
    }
}
