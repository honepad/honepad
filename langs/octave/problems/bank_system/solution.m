function obj = Simulation()
  accounts = containers.Map();
  payment_counter = 0;
  pending_cashbacks = {};
  cashback_delay = 24 * 60 * 60 * 1000;

  obj.create_account = @create_account;
  obj.deposit = @deposit;
  obj.transfer = @transfer;
  obj.top_spenders = @top_spenders;
  obj.pay = @pay;
  obj.get_payment_status = @get_payment_status;
  obj.merge_accounts = @merge_accounts;
  obj.get_balance = @get_balance;

  function process_cashbacks(timestamp)
    while (numel(pending_cashbacks) > 0 && pending_cashbacks{1}{1} <= timestamp)
      row = pending_cashbacks{1};
      pending_cashbacks(1) = [];
      if (accounts.isKey(row{2}))
        acc = accounts(row{2});
        acc.balance += row{3};
        acc.payments(row{4}) = "CASHBACK_RECEIVED";
        acc.balance_history{end + 1} = [row{1}, acc.balance];
        accounts(row{2}) = acc;
      endif
    endwhile
  endfunction

  function acc = new_account(account_id, created_at)
    acc.account_id = account_id;
    acc.balance = 0;
    acc.outgoing = 0;
    acc.payments = containers.Map();
    acc.created_at = created_at;
    acc.balance_history = {[created_at, 0]};
  endfunction

  function result = create_account(timestamp, account_id)
    process_cashbacks(timestamp);
    if (accounts.isKey(account_id))
      result = false;
      return;
    endif
    accounts(account_id) = new_account(account_id, timestamp);
    result = true;
  endfunction

  function result = deposit(timestamp, account_id, amount)
    process_cashbacks(timestamp);
    if (!accounts.isKey(account_id))
      result = [];
      return;
    endif
    acc = accounts(account_id);
    acc.balance += amount;
    acc.balance_history{end + 1} = [timestamp, acc.balance];
    accounts(account_id) = acc;
    result = acc.balance;
  endfunction

  function result = transfer(timestamp, source_account_id, target_account_id, amount)
    process_cashbacks(timestamp);
    if (!accounts.isKey(source_account_id) || !accounts.isKey(target_account_id))
      result = [];
      return;
    endif
    if (strcmp(source_account_id, target_account_id))
      result = [];
      return;
    endif
    source = accounts(source_account_id);
    target = accounts(target_account_id);
    if (source.balance < amount)
      result = [];
      return;
    endif
    source.balance -= amount;
    source.outgoing += amount;
    target.balance += amount;
    source.balance_history{end + 1} = [timestamp, source.balance];
    target.balance_history{end + 1} = [timestamp, target.balance];
    accounts(source_account_id) = source;
    accounts(target_account_id) = target;
    result = source.balance;
  endfunction

  function result = top_spenders(timestamp, n)
    process_cashbacks(timestamp);
    ids = accounts.keys();
    if (isempty(ids) || n <= 0)
      result = {};
      return;
    endif
    outs = zeros(1, numel(ids));
    for i = 1:numel(ids)
      acc = accounts(ids{i});
      outs(i) = acc.outgoing;
    endfor
    for i = 1:numel(ids)
      for j = i + 1:numel(ids)
        if (outs(j) > outs(i) || (outs(j) == outs(i) && str_lt(ids{j}, ids{i})))
          tmp_id = ids{i};
          ids{i} = ids{j};
          ids{j} = tmp_id;
          tmp_out = outs(i);
          outs(i) = outs(j);
          outs(j) = tmp_out;
        endif
      endfor
    endfor
    if (numel(ids) > n)
      ids = ids(1:n);
    endif
    result = cell(1, numel(ids));
    for i = 1:numel(ids)
      acc = accounts(ids{i});
      result{i} = sprintf("%s(%d)", ids{i}, acc.outgoing);
    endfor
  endfunction

  function result = pay(timestamp, account_id, amount)
    process_cashbacks(timestamp);
    if (!accounts.isKey(account_id))
      result = [];
      return;
    endif
    acc = accounts(account_id);
    if (acc.balance < amount)
      result = [];
      return;
    endif
    acc.balance -= amount;
    acc.outgoing += amount;
    payment_counter += 1;
    payment_id = sprintf("payment%d", payment_counter);
    acc.payments(payment_id) = "IN_PROGRESS";
    acc.balance_history{end + 1} = [timestamp, acc.balance];
    accounts(account_id) = acc;
    cashback_amount = fix(amount * 2 / 100);
    pending_cashbacks{end + 1} = {
      timestamp + cashback_delay, account_id, cashback_amount, payment_id
    };
    result = payment_id;
  endfunction

  function result = get_payment_status(timestamp, account_id, payment)
    process_cashbacks(timestamp);
    if (!accounts.isKey(account_id))
      result = [];
      return;
    endif
    acc = accounts(account_id);
    if (!acc.payments.isKey(payment))
      result = [];
      return;
    endif
    result = acc.payments(payment);
  endfunction

  function result = merge_accounts(timestamp, account_id_1, account_id_2)
    process_cashbacks(timestamp);
    if (strcmp(account_id_1, account_id_2))
      result = false;
      return;
    endif
    if (!accounts.isKey(account_id_1) || !accounts.isKey(account_id_2))
      result = false;
      return;
    endif
    acc1 = accounts(account_id_1);
    acc2 = accounts(account_id_2);
    acc1.balance += acc2.balance;
    acc1.outgoing += acc2.outgoing;
    pkeys = acc2.payments.keys();
    for i = 1:numel(pkeys)
      acc1.payments(pkeys{i}) = acc2.payments(pkeys{i});
    endfor
    acc1.balance_history = [acc1.balance_history, acc2.balance_history];
    ts = zeros(1, numel(acc1.balance_history));
    for i = 1:numel(acc1.balance_history)
      ts(i) = acc1.balance_history{i}(1);
    endfor
    [~, idx] = sort(ts);
    acc1.balance_history = acc1.balance_history(idx);
    if (acc2.created_at < acc1.created_at)
      acc1.created_at = acc2.created_at;
    endif
    acc1.balance_history{end + 1} = [timestamp, acc1.balance];
    accounts(account_id_1) = acc1;
    for i = 1:numel(pending_cashbacks)
      if (strcmp(pending_cashbacks{i}{2}, account_id_2))
        pending_cashbacks{i}{2} = account_id_1;
      endif
    endfor
    remove(accounts, account_id_2);
    result = true;
  endfunction

  function yes = str_lt(a, b)
    [ordered, ~] = sort({a, b});
    yes = strcmp(ordered{1}, a) && !strcmp(a, b);
  endfunction

  function result = get_balance(timestamp, account_id, time_at)
    process_cashbacks(timestamp);
    if (!accounts.isKey(account_id))
      result = [];
      return;
    endif
    acc = accounts(account_id);
    if (time_at < acc.created_at)
      result = [];
      return;
    endif
    result = [];
    for i = 1:numel(acc.balance_history)
      row = acc.balance_history{i};
      if (row(1) > time_at)
        break;
      endif
      result = row(2);
    endfor
  endfunction
endfunction
