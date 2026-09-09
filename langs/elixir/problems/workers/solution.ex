defmodule Simulation do
  defstruct workers: %{}

  def new, do: %__MODULE__{}

  def add_worker(sim, worker_id, position, compensation) do
    if Map.has_key?(sim.workers, worker_id) do
      {"false", sim}
    else
      worker = new_worker(worker_id, position, compensation)
      {"true", %{sim | workers: Map.put(sim.workers, worker_id, worker)}}
    end
  end

  def register(sim, worker_id, timestamp) do
    case Map.get(sim.workers, worker_id) do
      nil ->
        {"invalid_request", sim}

      %{in_office: true} = worker ->
        session = {worker.entered_at, timestamp, worker.compensation, worker.position}

        worker = %{
          worker
          | finished: worker.finished ++ [session],
            in_office: false,
            entered_at: nil
        }

        {"registered", put_worker(sim, worker_id, worker)}

      worker ->
        worker = apply_promo_on_enter(worker, timestamp)
        worker = %{worker | in_office: true, entered_at: timestamp}
        {"registered", put_worker(sim, worker_id, worker)}
    end
  end

  def get(sim, worker_id) do
    case Map.get(sim.workers, worker_id) do
      nil -> {"", sim}
      worker -> {Integer.to_string(total_time(worker)), sim}
    end
  end

  def top_n_workers(sim, n, position) do
    result =
      sim.workers
      |> Map.values()
      |> Enum.filter(fn w -> w.position == position end)
      |> Enum.sort_by(fn w -> {-position_time(w, position), w.worker_id} end)
      |> Enum.take(n)
      |> Enum.map_join(", ", fn w -> "#{w.worker_id}(#{position_time(w, position)})" end)

    {result, sim}
  end

  def promote(sim, worker_id, new_position, new_compensation, start_timestamp) do
    case Map.get(sim.workers, worker_id) do
      nil ->
        {"invalid_request", sim}

      %{pending_promo: promo} when promo != nil ->
        {"invalid_request", sim}

      worker ->
        worker = %{worker | pending_promo: {new_position, new_compensation, start_timestamp}}
        {"success", put_worker(sim, worker_id, worker)}
    end
  end

  def set_double_pay(sim, worker_id, interval_begin, interval_end) do
    case Map.get(sim.workers, worker_id) do
      nil ->
        {"invalid_request", sim}

      _worker when interval_end <= interval_begin ->
        {"invalid_request", sim}

      worker ->
        worker = %{worker | double_pay: worker.double_pay ++ [{interval_begin, interval_end}]}
        {"true", put_worker(sim, worker_id, worker)}
    end
  end

  def calc_salary(sim, worker_id, start_timestamp, end_timestamp) do
    case Map.get(sim.workers, worker_id) do
      nil ->
        {"", sim}

      worker ->
        total =
          Enum.reduce(worker.finished, 0, fn {session_start, session_end, rate, _pos}, acc ->
            lo = max(session_start, start_timestamp)
            hi = min(session_end, end_timestamp)

            if hi > lo do
              bonus = bonus_overlap(lo, hi, worker.double_pay)
              acc + (hi - lo - bonus) * rate + bonus * rate * 2
            else
              acc
            end
          end)

        {Integer.to_string(total), sim}
    end
  end

  defp new_worker(worker_id, position, compensation) do
    %{
      worker_id: worker_id,
      position: position,
      compensation: compensation,
      in_office: false,
      entered_at: nil,
      finished: [],
      pending_promo: nil,
      double_pay: []
    }
  end

  defp put_worker(sim, worker_id, worker) do
    %{sim | workers: Map.put(sim.workers, worker_id, worker)}
  end

  defp total_time(worker) do
    Enum.reduce(worker.finished, 0, fn {start_ts, end_ts, _rate, _pos}, acc ->
      acc + (end_ts - start_ts)
    end)
  end

  defp position_time(worker, position) do
    Enum.reduce(worker.finished, 0, fn
      {start_ts, end_ts, _rate, ^position}, acc -> acc + (end_ts - start_ts)
      _, acc -> acc
    end)
  end

  defp apply_promo_on_enter(%{pending_promo: nil} = worker, _timestamp), do: worker

  defp apply_promo_on_enter(%{pending_promo: {new_pos, new_comp, start_ts}} = worker, timestamp)
       when timestamp >= start_ts do
    %{worker | position: new_pos, compensation: new_comp, pending_promo: nil}
  end

  defp apply_promo_on_enter(worker, _timestamp), do: worker

  defp bonus_overlap(lo, hi, windows) do
    segs =
      windows
      |> Enum.map(fn {begin_ts, end_ts} -> {max(lo, begin_ts), min(hi, end_ts)} end)
      |> Enum.filter(fn {start_ts, stop_ts} -> stop_ts > start_ts end)
      |> Enum.sort()

    merged =
      Enum.reduce(segs, [], fn {start_ts, stop_ts}, acc ->
        case acc do
          [] ->
            [{start_ts, stop_ts}]

          _ ->
            {prev_start, prev_end} = List.last(acc)

            if start_ts >= prev_end do
              acc ++ [{start_ts, stop_ts}]
            else
              List.replace_at(acc, -1, {prev_start, max(prev_end, stop_ts)})
            end
        end
      end)

    Enum.reduce(merged, 0, fn {start_ts, stop_ts}, acc -> acc + (stop_ts - start_ts) end)
  end
end
