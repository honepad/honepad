defmodule Simulation do
  defstruct gpus: %{}, gpu_order: [], jobs: %{}, next_seq: 0

  def new, do: %__MODULE__{}

  def add_gpu(sim, gpu_id, mem) do
    cond do
      mem <= 0 ->
        {"invalid_request", sim}

      Map.has_key?(sim.gpus, gpu_id) ->
        {"false", sim}

      true ->
        gpu = %{gpu_id: gpu_id, mem: mem, job_id: nil}

        {"true",
         %{sim | gpus: Map.put(sim.gpus, gpu_id, gpu), gpu_order: sim.gpu_order ++ [gpu_id]}}
    end
  end

  def submit_job(sim, job_id, mem) do
    cond do
      mem <= 0 ->
        {"invalid_request", sim}

      Map.has_key?(sim.jobs, job_id) ->
        {"false", sim}

      true ->
        job = %{
          job_id: job_id,
          mem: mem,
          seq: sim.next_seq,
          priority: 0,
          state: "queued",
          gpu_id: nil
        }

        {"true", %{sim | jobs: Map.put(sim.jobs, job_id, job), next_seq: sim.next_seq + 1}}
    end
  end

  def status(sim, job_id) do
    case Map.get(sim.jobs, job_id) do
      nil -> {"", sim}
      job -> {job.state, sim}
    end
  end

  def assign(sim) do
    queued =
      sim.jobs
      |> Map.values()
      |> Enum.filter(&(&1.state == "queued"))
      |> Enum.sort_by(&{-&1.priority, &1.seq})

    Enum.reduce_while(queued, {"", sim}, fn job, acc ->
      case place_job(elem(acc, 1), job) do
        nil -> {:cont, acc}
        {job_id, nxt} -> {:halt, {job_id, nxt}}
      end
    end)
  end

  def complete(sim, job_id) do
    case Map.get(sim.jobs, job_id) do
      %{state: "running", gpu_id: gpu_id} = job when gpu_id != nil ->
        gpu = Map.fetch!(sim.gpus, gpu_id)
        job = %{job | gpu_id: nil, state: "done"}
        gpu = %{gpu | job_id: nil}
        {"true", put_gpu(put_job(sim, job), gpu)}

      _ ->
        {"invalid_request", sim}
    end
  end

  def cancel(sim, job_id) do
    case Map.get(sim.jobs, job_id) do
      nil ->
        {"invalid_request", sim}

      %{state: "done"} ->
        {"invalid_request", sim}

      job ->
        sim =
          if job.state == "running" and job.gpu_id != nil do
            gpu = Map.fetch!(sim.gpus, job.gpu_id)
            put_gpu(sim, %{gpu | job_id: nil})
          else
            sim
          end

        sim = %{sim | jobs: Map.delete(sim.jobs, job_id)}

        sim =
          if job.state == "running" do
            {_, nxt} = assign(sim)
            nxt
          else
            sim
          end

        {"true", sim}
    end
  end

  def set_priority(sim, job_id, priority) do
    case Map.get(sim.jobs, job_id) do
      %{state: "queued"} = job ->
        {"true", put_job(sim, %{job | priority: priority})}

      _ ->
        {"invalid_request", sim}
    end
  end

  defp place_job(sim, job) do
    Enum.find_value(sim.gpu_order, fn gpu_id ->
      gpu = Map.fetch!(sim.gpus, gpu_id)

      if gpu.job_id == nil and gpu.mem >= job.mem do
        job = %{job | state: "running", gpu_id: gpu_id}
        gpu = %{gpu | job_id: job.job_id}
        {job.job_id, put_gpu(put_job(sim, job), gpu)}
      end
    end)
  end

  defp put_job(sim, job), do: %{sim | jobs: Map.put(sim.jobs, job.job_id, job)}
  defp put_gpu(sim, gpu), do: %{sim | gpus: Map.put(sim.gpus, gpu.gpu_id, gpu)}
end
