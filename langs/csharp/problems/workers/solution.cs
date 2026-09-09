class WorkSession
{
    public int Start;
    public int End;
    public int Rate;
    public string Position;

    public WorkSession(int start, int end, int rate, string position)
    {
        Start = start;
        End = end;
        Rate = rate;
        Position = position;
    }
}

class Promo
{
    public string Position;
    public int Compensation;
    public int StartTimestamp;

    public Promo(string position, int compensation, int startTimestamp)
    {
        Position = position;
        Compensation = compensation;
        StartTimestamp = startTimestamp;
    }
}

class Worker
{
    public string WorkerId;
    public string Position;
    public int Compensation;
    public bool InOffice;
    public int? EnteredAt;
    public List<WorkSession> Finished = new();
    public Promo? PendingPromo;
    public List<int[]> DoublePay = new();

    public Worker(string workerId, string position, int compensation)
    {
        WorkerId = workerId;
        Position = position;
        Compensation = compensation;
    }

    public int TotalTime()
    {
        int sum = 0;
        foreach (WorkSession session in Finished)
        {
            sum += session.End - session.Start;
        }
        return sum;
    }

    public int PositionTime(string pos)
    {
        int sum = 0;
        foreach (WorkSession session in Finished)
        {
            if (session.Position == pos)
            {
                sum += session.End - session.Start;
            }
        }
        return sum;
    }

    public void ApplyPromoOnEnter(int timestamp)
    {
        if (PendingPromo == null)
        {
            return;
        }
        if (timestamp >= PendingPromo.StartTimestamp)
        {
            Position = PendingPromo.Position;
            Compensation = PendingPromo.Compensation;
            PendingPromo = null;
        }
    }
}

public class Simulation
{
    readonly Dictionary<string, Worker> workers = new();

    public Simulation() { }

    public string AddWorker(string workerId, string position, int compensation)
    {
        if (workers.ContainsKey(workerId))
        {
            return "false";
        }
        workers[workerId] = new Worker(workerId, position, compensation);
        return "true";
    }

    public string Register(string workerId, int timestamp)
    {
        if (!workers.TryGetValue(workerId, out Worker? worker))
        {
            return "invalid_request";
        }
        if (worker.InOffice)
        {
            worker.Finished.Add(
                new WorkSession(worker.EnteredAt!.Value, timestamp, worker.Compensation, worker.Position)
            );
            worker.InOffice = false;
            worker.EnteredAt = null;
            return "registered";
        }
        worker.ApplyPromoOnEnter(timestamp);
        worker.InOffice = true;
        worker.EnteredAt = timestamp;
        return "registered";
    }

    public string Get(string workerId)
    {
        if (!workers.TryGetValue(workerId, out Worker? worker))
        {
            return "";
        }
        return worker.TotalTime().ToString();
    }

    public string TopNWorkers(int n, string position)
    {
        List<Worker> matched = workers.Values.Where(worker => worker.Position == position).ToList();
        matched.Sort(
            (a, b) =>
            {
                int d = b.PositionTime(position).CompareTo(a.PositionTime(position));
                return d != 0 ? d : string.CompareOrdinal(a.WorkerId, b.WorkerId);
            }
        );
        if (n < matched.Count)
        {
            matched = matched.GetRange(0, n);
        }
        return string.Join(", ", matched.Select(worker => worker.WorkerId + "(" + worker.PositionTime(position) + ")"));
    }

    public string Promote(string workerId, string newPosition, int newCompensation, int startTimestamp)
    {
        if (!workers.TryGetValue(workerId, out Worker? worker) || worker.PendingPromo != null)
        {
            return "invalid_request";
        }
        worker.PendingPromo = new Promo(newPosition, newCompensation, startTimestamp);
        return "success";
    }

    public string SetDoublePay(string workerId, int intervalBegin, int intervalEnd)
    {
        if (!workers.TryGetValue(workerId, out Worker? worker) || intervalEnd <= intervalBegin)
        {
            return "invalid_request";
        }
        worker.DoublePay.Add(new[] { intervalBegin, intervalEnd });
        return "true";
    }

    public string CalcSalary(string workerId, int startTimestamp, int endTimestamp)
    {
        if (!workers.TryGetValue(workerId, out Worker? worker))
        {
            return "";
        }
        long total = 0;
        foreach (WorkSession session in worker.Finished)
        {
            int lo = Math.Max(session.Start, startTimestamp);
            int hi = Math.Min(session.End, endTimestamp);
            if (hi > lo)
            {
                int bonus = BonusOverlap(lo, hi, worker.DoublePay);
                total += (long)(hi - lo - bonus) * session.Rate + (long)bonus * session.Rate * 2;
            }
        }
        return total.ToString();
    }

    static int BonusOverlap(int lo, int hi, List<int[]> windows)
    {
        List<int[]> segs = new();
        foreach (int[] window in windows)
        {
            int start = Math.Max(lo, window[0]);
            int stop = Math.Min(hi, window[1]);
            if (stop > start)
            {
                segs.Add(new[] { start, stop });
            }
        }
        segs.Sort((a, b) => a[0].CompareTo(b[0]));
        List<int[]> merged = new();
        foreach (int[] seg in segs)
        {
            if (merged.Count == 0 || seg[0] >= merged[^1][1])
            {
                merged.Add(new[] { seg[0], seg[1] });
            }
            else
            {
                merged[^1][1] = Math.Max(merged[^1][1], seg[1]);
            }
        }
        int sum = 0;
        foreach (int[] seg in merged)
        {
            sum += seg[1] - seg[0];
        }
        return sum;
    }
}
