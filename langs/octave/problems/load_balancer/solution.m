function obj = Simulation()
  backends = {};
  by_id = containers.Map();
  cursor = 0;
  sticky_map = containers.Map();
  use_least = false;

  obj.add_backend = @add_backend;
  obj.route = @route;
  obj.set_health = @set_health;
  obj.set_weight = @set_weight;
  obj.sticky = @sticky;
  obj.done = @done;

  function reset_cycle()
    cursor = 0;
    use_least = false;
    for i = 1:numel(backends)
      item = backends{i};
      item.inflight = 0;
      backends{i} = item;
      by_id(item.backend_id) = i;
    endfor
  endfunction

  function tickets = make_tickets(items)
    tickets = {};
    for i = 1:numel(items)
      item = items{i};
      for w = 1:item.weight
        tickets{end + 1} = item;
      endfor
    endfor
  endfunction

  function item = pick()
    healthy = {};
    for i = 1:numel(backends)
      cand = backends{i};
      if (cand.health)
        healthy{end + 1} = cand;
      endif
    endfor
    if (numel(healthy) == 0)
      item = [];
      return;
    endif
    pool = healthy;
    if (use_least)
      least = healthy{1}.inflight;
      for i = 1:numel(healthy)
        if (healthy{i}.inflight < least)
          least = healthy{i}.inflight;
        endif
      endfor
      pool = {};
      for i = 1:numel(healthy)
        if (healthy{i}.inflight == least)
          pool{end + 1} = healthy{i};
        endif
      endfor
    endif
    tickets = make_tickets(pool);
    if (numel(tickets) == 0)
      item = [];
      return;
    endif
    idx = mod(cursor, numel(tickets)) + 1;
    cursor += 1;
    item = tickets{idx};
  endfunction

  function result = take()
    item = pick();
    if (isempty(item))
      result = "";
      return;
    endif
    idx = by_id(item.backend_id);
    stored = backends{idx};
    stored.inflight += 1;
    backends{idx} = stored;
    result = stored.backend_id;
  endfunction

  function result = add_backend(backend_id)
    if (by_id.isKey(backend_id))
      result = "false";
      return;
    endif
    item.backend_id = backend_id;
    item.health = true;
    item.weight = 1;
    item.inflight = 0;
    backends{end + 1} = item;
    by_id(backend_id) = numel(backends);
    result = "true";
  endfunction

  function result = set_health(backend_id, flag)
    if (!by_id.isKey(backend_id) || (flag != 0 && flag != 1))
      result = "invalid_request";
      return;
    endif
    idx = by_id(backend_id);
    item = backends{idx};
    item.health = flag == 1;
    backends{idx} = item;
    reset_cycle();
    result = "true";
  endfunction

  function result = set_weight(backend_id, weight)
    if (!by_id.isKey(backend_id) || weight <= 0)
      result = "invalid_request";
      return;
    endif
    idx = by_id(backend_id);
    item = backends{idx};
    item.weight = weight;
    backends{idx} = item;
    reset_cycle();
    result = "true";
  endfunction

  function result = route()
    result = take();
  endfunction

  function result = sticky(client_id)
    if (sticky_map.isKey(client_id))
      bound = sticky_map(client_id);
      if (by_id.isKey(bound))
        idx = by_id(bound);
        item = backends{idx};
        if (item.health)
          item.inflight += 1;
          backends{idx} = item;
          result = item.backend_id;
          return;
        endif
      endif
    endif
    chosen = take();
    if (!isempty(chosen))
      sticky_map(client_id) = chosen;
    endif
    result = chosen;
  endfunction

  function result = done(backend_id)
    if (!by_id.isKey(backend_id))
      result = "invalid_request";
      return;
    endif
    idx = by_id(backend_id);
    item = backends{idx};
    if (item.inflight <= 0)
      result = "invalid_request";
      return;
    endif
    item.inflight -= 1;
    backends{idx} = item;
    use_least = true;
    result = "true";
  endfunction
endfunction
