function obj = Simulation()
  items = containers.Map();

  obj.create_item = @create_item;
  obj.stock = @stock;
  obj.get_qty = @get_qty;
  obj.list_low = @list_low;
  obj.reserve = @reserve;
  obj.release = @release;
  obj.ship = @ship;

  function item = new_item(sku, name)
    item.sku = sku;
    item.name = name;
    item.qty = 0;
    item.reserved = 0;
  endfunction

  function result = create_item(sku, name)
    if (items.isKey(sku))
      result = "false";
      return;
    endif
    items(sku) = new_item(sku, name);
    result = "true";
  endfunction

  function result = stock(sku, delta)
    if (!items.isKey(sku))
      result = "";
      return;
    endif
    item = items(sku);
    nxt = item.qty + delta;
    if (nxt < item.reserved)
      result = "invalid_request";
      return;
    endif
    item.qty = nxt;
    items(sku) = item;
    result = sprintf("%d", item.qty);
  endfunction

  function result = get_qty(sku)
    if (!items.isKey(sku))
      result = "";
      return;
    endif
    item = items(sku);
    result = sprintf("%d", item.qty);
  endfunction

  function yes = str_lt(a, b)
    [ordered, ~] = sort({a, b});
    yes = strcmp(ordered{1}, a) && !strcmp(a, b);
  endfunction

  function result = list_low(threshold)
    ids = items.keys();
    matched = {};
    qtys = [];
    names = {};
    for i = 1:numel(ids)
      item = items(ids{i});
      if (item.qty <= threshold)
        matched{end + 1} = item;
        qtys(end + 1) = item.qty;
        names{end + 1} = item.sku;
      endif
    endfor
    if (isempty(matched))
      result = "";
      return;
    endif
    for i = 1:numel(matched)
      for j = i + 1:numel(matched)
        if (qtys(j) < qtys(i) || (qtys(j) == qtys(i) && str_lt(names{j}, names{i})))
          tmp_w = matched{i};
          matched{i} = matched{j};
          matched{j} = tmp_w;
          tmp_t = qtys(i);
          qtys(i) = qtys(j);
          qtys(j) = tmp_t;
          tmp_n = names{i};
          names{i} = names{j};
          names{j} = tmp_n;
        endif
      endfor
    endfor
    parts = {};
    for i = 1:numel(matched)
      item = matched{i};
      parts{end + 1} = sprintf("%s(%d)", item.sku, item.qty);
    endfor
    result = strjoin(parts, ", ");
  endfunction

  function result = reserve(sku, n)
    if (!items.isKey(sku))
      result = "invalid_request";
      return;
    endif
    item = items(sku);
    if (n <= 0 || item.reserved + n > item.qty)
      result = "invalid_request";
      return;
    endif
    item.reserved += n;
    items(sku) = item;
    result = "true";
  endfunction

  function result = release(sku, n)
    if (!items.isKey(sku))
      result = "invalid_request";
      return;
    endif
    item = items(sku);
    if (n <= 0 || n > item.reserved)
      result = "invalid_request";
      return;
    endif
    item.reserved -= n;
    items(sku) = item;
    result = "true";
  endfunction

  function result = ship(sku, n)
    if (!items.isKey(sku))
      result = "invalid_request";
      return;
    endif
    item = items(sku);
    if (n <= 0 || n > item.reserved)
      result = "invalid_request";
      return;
    endif
    item.reserved -= n;
    item.qty -= n;
    items(sku) = item;
    result = "true";
  endfunction
endfunction
