function obj = Simulation()
  workers = containers.Map();

  obj.add_worker = @add_worker;
  obj.register = @register;
  obj.get = @get_worker;
  obj.top_n_workers = @top_n_workers;
  obj.promote = @promote;
  obj.calc_salary = @calc_salary;

  function worker = new_worker(worker_id, position, compensation)
    worker.worker_id = worker_id;
    worker.position = position;
    worker.compensation = compensation;
    worker.in_office = false;
    worker.entered_at = [];
    worker.finished = {};
    worker.pending_promo = {};
  endfunction

  function total = worker_total_time(worker)
    total = 0;
    for i = 1:numel(worker.finished)
      row = worker.finished{i};
      total += (row{2} - row{1});
    endfor
  endfunction

  function total = worker_position_time(worker, position)
    total = 0;
    for i = 1:numel(worker.finished)
      row = worker.finished{i};
      if (strcmp(row{4}, position))
        total += (row{2} - row{1});
      endif
    endfor
  endfunction

  function worker = apply_promo_on_enter(worker, timestamp)
    if (isempty(worker.pending_promo))
      return;
    endif
    promo = worker.pending_promo;
    if (timestamp < promo{3})
      return;
    endif
    worker.position = promo{1};
    worker.compensation = promo{2};
    worker.pending_promo = {};
  endfunction

  function result = add_worker(worker_id, position, compensation)
    if (workers.isKey(worker_id))
      result = "false";
      return;
    endif
    workers(worker_id) = new_worker(worker_id, position, compensation);
    result = "true";
  endfunction

  function result = register(worker_id, timestamp)
    if (!workers.isKey(worker_id))
      result = "invalid_request";
      return;
    endif
    worker = workers(worker_id);
    if (worker.in_office)
      worker.finished{end + 1} = {
        worker.entered_at, timestamp, worker.compensation, worker.position
      };
      worker.in_office = false;
      worker.entered_at = [];
      workers(worker_id) = worker;
      result = "registered";
      return;
    endif
    worker = apply_promo_on_enter(worker, timestamp);
    worker.in_office = true;
    worker.entered_at = timestamp;
    workers(worker_id) = worker;
    result = "registered";
  endfunction

  function result = get_worker(worker_id)
    if (!workers.isKey(worker_id))
      result = "";
      return;
    endif
    worker = workers(worker_id);
    result = sprintf("%d", worker_total_time(worker));
  endfunction

  function result = top_n_workers(n, position)
    ids = workers.keys();
    matched = {};
    times = [];
    names = {};
    for i = 1:numel(ids)
      worker = workers(ids{i});
      if (strcmp(worker.position, position))
        matched{end + 1} = worker;
        times(end + 1) = worker_position_time(worker, position);
        names{end + 1} = worker.worker_id;
      endif
    endfor
    if (isempty(matched) || n <= 0)
      result = "";
      return;
    endif
    for i = 1:numel(matched)
      for j = i + 1:numel(matched)
        if (times(j) > times(i) || (times(j) == times(i) && str_lt(names{j}, names{i})))
          tmp_w = matched{i};
          matched{i} = matched{j};
          matched{j} = tmp_w;
          tmp_t = times(i);
          times(i) = times(j);
          times(j) = tmp_t;
          tmp_n = names{i};
          names{i} = names{j};
          names{j} = tmp_n;
        endif
      endfor
    endfor
    if (numel(matched) > n)
      matched = matched(1:n);
    endif
    parts = {};
    for i = 1:numel(matched)
      worker = matched{i};
      parts{end + 1} = sprintf(
        "%s(%d)", worker.worker_id, worker_position_time(worker, position)
      );
    endfor
    result = strjoin(parts, ", ");
  endfunction

  function yes = str_lt(a, b)
    [ordered, ~] = sort({a, b});
    yes = strcmp(ordered{1}, a) && !strcmp(a, b);
  endfunction

  function result = promote(worker_id, new_position, new_compensation, start_timestamp)
    if (!workers.isKey(worker_id))
      result = "invalid_request";
      return;
    endif
    worker = workers(worker_id);
    if (!isempty(worker.pending_promo))
      result = "invalid_request";
      return;
    endif
    worker.pending_promo = {new_position, new_compensation, start_timestamp};
    workers(worker_id) = worker;
    result = "success";
  endfunction

  function result = calc_salary(worker_id, start_timestamp, end_timestamp)
    if (!workers.isKey(worker_id))
      result = "";
      return;
    endif
    worker = workers(worker_id);
    total = 0;
    for i = 1:numel(worker.finished)
      row = worker.finished{i};
      session_start = row{1};
      session_end = row{2};
      rate = row{3};
      lo = max(session_start, start_timestamp);
      hi = min(session_end, end_timestamp);
      if (hi > lo)
        total += (hi - lo) * rate;
      endif
    endfor
    result = sprintf("%d", total);
  endfunction
endfunction
