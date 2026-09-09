function obj = Simulation()
  keys = containers.Map();

  obj.allow = @allow;
  obj.configure = @configure;
  obj.remaining = @remaining;
  obj.allow_weighted = @allow_weighted;

  function item = new_key()
    item.limit = 3;
    item.window = 10;
    item.window_id = NaN;
    item.used = 0;
  endfunction

  function item = state(key)
    if (!keys.isKey(key))
      keys(key) = new_key();
    endif
    item = keys(key);
  endfunction

  function used = used_at(key, timestamp, persist)
    item = state(key);
    window_id = floor(timestamp / item.window);
    if (isnan(item.window_id) || window_id != item.window_id)
      if (persist)
        item.window_id = window_id;
        item.used = 0;
        keys(key) = item;
      endif
      used = 0;
      return;
    endif
    used = item.used;
  endfunction

  function result = allow(key, timestamp)
    result = allow_weighted(key, 1, timestamp);
  endfunction

  function result = configure(key, limit, window)
    if (limit <= 0 || window <= 0)
      result = "invalid_request";
      return;
    endif
    item = state(key);
    item.limit = limit;
    item.window = window;
    item.window_id = NaN;
    item.used = 0;
    keys(key) = item;
    result = "true";
  endfunction

  function result = remaining(key, timestamp)
    item = state(key);
    used = used_at(key, timestamp, false);
    result = sprintf("%d", item.limit - used);
  endfunction

  function result = allow_weighted(key, cost, timestamp)
    if (cost <= 0)
      result = "invalid_request";
      return;
    endif
    used_at(key, timestamp, true);
    item = keys(key);
    if (item.used + cost > item.limit)
      result = "false";
      return;
    endif
    item.used += cost;
    keys(key) = item;
    result = "true";
  endfunction
endfunction
