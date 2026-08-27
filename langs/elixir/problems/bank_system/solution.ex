defmodule Simulation do
  @cashback_delay 24 * 60 * 60 * 1000

  defstruct accounts: %{}, payment_counter: 0, pending_cashbacks: []

  def new, do: %__MODULE__{}

  def create_account(sim, timestamp, account_id) do
    sim = process_cashbacks(sim, timestamp)

    if Map.has_key?(sim.accounts, account_id) do
      {false, sim}
    else
      acc = new_account(account_id, timestamp)
      {true, %{sim | accounts: Map.put(sim.accounts, account_id, acc)}}
    end
  end

  def deposit(sim, timestamp, account_id, amount) do
    sim = process_cashbacks(sim, timestamp)

    case Map.get(sim.accounts, account_id) do
      nil ->
        {nil, sim}

      acc ->
        acc = credit(acc, amount)
        acc = record_balance(acc, timestamp)
        {acc.balance, put_account(sim, account_id, acc)}
    end
  end

  def transfer(sim, timestamp, source_account_id, target_account_id, amount) do
    sim = process_cashbacks(sim, timestamp)
    source = Map.get(sim.accounts, source_account_id)
    target = Map.get(sim.accounts, target_account_id)

    cond do
      source == nil or target == nil ->
        {nil, sim}

      source_account_id == target_account_id ->
        {nil, sim}

      true ->
        case withdraw(source, amount) do
          :error ->
            {nil, sim}

          {:ok, source} ->
            target = credit(target, amount)
            source = record_balance(source, timestamp)
            target = record_balance(target, timestamp)

            sim =
              sim
              |> put_account(source_account_id, source)
              |> put_account(target_account_id, target)

            {source.balance, sim}
        end
    end
  end

  def top_spenders(sim, timestamp, n) do
    sim = process_cashbacks(sim, timestamp)

    ids =
      sim.accounts
      |> Map.keys()
      |> Enum.sort_by(fn id -> {-sim.accounts[id].outgoing, id} end)
      |> Enum.take(n)

    result = Enum.map(ids, fn id -> "#{id}(#{sim.accounts[id].outgoing})" end)
    {result, sim}
  end

  def pay(sim, timestamp, account_id, amount) do
    sim = process_cashbacks(sim, timestamp)

    case Map.get(sim.accounts, account_id) do
      nil ->
        {nil, sim}

      acc ->
        case withdraw(acc, amount) do
          :error ->
            {nil, sim}

          {:ok, acc} ->
            counter = sim.payment_counter + 1
            payment_id = "payment#{counter}"
            acc = %{acc | payments: Map.put(acc.payments, payment_id, "IN_PROGRESS")}
            acc = record_balance(acc, timestamp)
            cashback = {timestamp + @cashback_delay, account_id, div(amount * 2, 100), payment_id}

            sim = %{
              sim
              | payment_counter: counter,
                pending_cashbacks: sim.pending_cashbacks ++ [cashback]
            }

            {payment_id, put_account(sim, account_id, acc)}
        end
    end
  end

  def get_payment_status(sim, timestamp, account_id, payment) do
    sim = process_cashbacks(sim, timestamp)

    case Map.get(sim.accounts, account_id) do
      nil -> {nil, sim}
      acc -> {Map.get(acc.payments, payment), sim}
    end
  end

  def merge_accounts(sim, timestamp, account_id_1, account_id_2) do
    sim = process_cashbacks(sim, timestamp)
    acc1 = Map.get(sim.accounts, account_id_1)
    acc2 = Map.get(sim.accounts, account_id_2)

    cond do
      account_id_1 == account_id_2 ->
        {false, sim}

      acc1 == nil or acc2 == nil ->
        {false, sim}

      true ->
        history =
          (acc1.balance_history ++ acc2.balance_history)
          |> Enum.sort_by(&elem(&1, 0))

        acc1 = %{
          acc1
          | balance: acc1.balance + acc2.balance,
            outgoing: acc1.outgoing + acc2.outgoing,
            payments: Map.merge(acc1.payments, acc2.payments),
            balance_history: history,
            created_at: min(acc1.created_at, acc2.created_at)
        }

        acc1 = record_balance(acc1, timestamp)

        pending =
          Enum.map(sim.pending_cashbacks, fn
            {ts, ^account_id_2, amount, payment_id} ->
              {ts, account_id_1, amount, payment_id}

            other ->
              other
          end)

        sim = %{
          sim
          | accounts: sim.accounts |> Map.put(account_id_1, acc1) |> Map.delete(account_id_2),
            pending_cashbacks: pending
        }

        {true, sim}
    end
  end

  def get_balance(sim, timestamp, account_id, time_at) do
    sim = process_cashbacks(sim, timestamp)

    case Map.get(sim.accounts, account_id) do
      nil -> {nil, sim}
      acc -> {balance_at(acc, time_at), sim}
    end
  end

  defp new_account(account_id, created_at) do
    %{
      account_id: account_id,
      balance: 0,
      outgoing: 0,
      payments: %{},
      created_at: created_at,
      balance_history: [{created_at, 0}]
    }
  end

  defp put_account(sim, account_id, acc) do
    %{sim | accounts: Map.put(sim.accounts, account_id, acc)}
  end

  defp credit(acc, amount), do: %{acc | balance: acc.balance + amount}

  defp withdraw(acc, amount) do
    if acc.balance < amount do
      :error
    else
      {:ok, %{acc | balance: acc.balance - amount, outgoing: acc.outgoing + amount}}
    end
  end

  defp record_balance(acc, timestamp) do
    %{acc | balance_history: acc.balance_history ++ [{timestamp, acc.balance}]}
  end

  defp balance_at(acc, time_at) do
    if time_at < acc.created_at do
      nil
    else
      Enum.reduce_while(acc.balance_history, nil, fn
        {ts, bal}, _last when ts <= time_at -> {:cont, bal}
        _, last -> {:halt, last}
      end)
    end
  end

  defp process_cashbacks(%{pending_cashbacks: [{cb_ts, account_id, amount, payment_id} | rest]} = sim, timestamp)
       when cb_ts <= timestamp do
    sim = %{sim | pending_cashbacks: rest}

    sim =
      case Map.get(sim.accounts, account_id) do
        nil ->
          sim

        acc ->
          acc = credit(acc, amount)
          acc = %{acc | payments: Map.put(acc.payments, payment_id, "CASHBACK_RECEIVED")}
          acc = record_balance(acc, cb_ts)
          put_account(sim, account_id, acc)
      end

    process_cashbacks(sim, timestamp)
  end

  defp process_cashbacks(sim, _timestamp), do: sim
end
