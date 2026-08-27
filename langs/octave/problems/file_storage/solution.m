function obj = Simulation()
  files = containers.Map();
  order = {};
  capacity = containers.Map();
  capacity("admin") = NA;
  backups = containers.Map();

  obj.add_file = @add_file;
  obj.get_file_size = @get_file_size;
  obj.delete_file = @delete_file;
  obj.get_n_largest = @get_n_largest;
  obj.add_user = @add_user;
  obj.add_file_by = @add_file_by;
  obj.merge_user = @merge_user;
  obj.backup_user = @backup_user;
  obj.restore_user = @restore_user;

  function total = used_of(user_id)
    total = 0;
    for i = 1:numel(order)
      name = order{i};
      if (files.isKey(name))
        item = files(name);
        if (strcmp(item.owner, user_id))
          total += item.size;
        endif
      endif
    endfor
  endfunction

  function rem = remaining_of(user_id)
    if (!capacity.isKey(user_id))
      rem = [];
      return;
    endif
    cap = capacity(user_id);
    if (isna(cap) || isnan(cap))
      rem = [];
      return;
    endif
    rem = cap - used_of(user_id);
  endfunction

  function add_item(name, size, owner)
    item.name = name;
    item.size = size;
    item.owner = owner;
    files(name) = item;
    order{end + 1} = name;
  endfunction

  function delete_name(name)
    if (files.isKey(name))
      remove(files, name);
    endif
    keep = {};
    for i = 1:numel(order)
      if (!strcmp(order{i}, name))
        keep{end + 1} = order{i};
      endif
    endfor
    order = keep;
  endfunction

  function result = add_file(name, size)
    if (files.isKey(name))
      result = "false";
      return;
    endif
    add_item(name, size, "admin");
    result = "true";
  endfunction

  function result = get_file_size(name)
    if (!files.isKey(name))
      result = "";
      return;
    endif
    item = files(name);
    result = sprintf("%d", item.size);
  endfunction

  function result = delete_file(name)
    if (!files.isKey(name))
      result = "";
      return;
    endif
    item = files(name);
    size = item.size;
    delete_name(name);
    result = sprintf("%d", size);
  endfunction

  function result = get_n_largest(prefix, n)
    matched = {};
    sizes = [];
    names = {};
    for i = 1:numel(order)
      name = order{i};
      if (!files.isKey(name))
        continue;
      endif
      item = files(name);
      if (strncmp(item.name, prefix, length(prefix)))
        matched{end + 1} = item;
        sizes(end + 1) = item.size;
        names{end + 1} = item.name;
      endif
    endfor
    if (isempty(matched) || n <= 0)
      result = "";
      return;
    endif
    for i = 1:numel(matched)
      for j = i + 1:numel(matched)
        if (sizes(j) > sizes(i) || (sizes(j) == sizes(i) && str_lt(names{j}, names{i})))
          tmp_item = matched{i};
          matched{i} = matched{j};
          matched{j} = tmp_item;
          tmp_size = sizes(i);
          sizes(i) = sizes(j);
          sizes(j) = tmp_size;
          tmp_name = names{i};
          names{i} = names{j};
          names{j} = tmp_name;
        endif
      endfor
    endfor
    if (numel(matched) > n)
      matched = matched(1:n);
    endif
    parts = {};
    for i = 1:numel(matched)
      item = matched{i};
      parts{end + 1} = sprintf("%s(%d)", item.name, item.size);
    endfor
    result = strjoin(parts, ", ");
  endfunction

  function yes = str_lt(a, b)
    [ordered, ~] = sort({a, b});
    yes = strcmp(ordered{1}, a) && !strcmp(a, b);
  endfunction

  function result = add_user(user_id, cap)
    if (capacity.isKey(user_id))
      result = "false";
      return;
    endif
    capacity(user_id) = cap;
    result = "true";
  endfunction

  function result = add_file_by(user_id, name, size)
    if (!capacity.isKey(user_id) || files.isKey(name))
      result = "";
      return;
    endif
    left = remaining_of(user_id);
    if (!isempty(left) && size > left)
      result = "";
      return;
    endif
    add_item(name, size, user_id);
    left = remaining_of(user_id);
    if (isempty(left))
      result = "";
      return;
    endif
    result = sprintf("%d", left);
  endfunction

  function result = merge_user(user_id1, user_id2)
    if (strcmp(user_id1, user_id2))
      result = "";
      return;
    endif
    if (!capacity.isKey(user_id1) || !capacity.isKey(user_id2))
      result = "";
      return;
    endif
    cap1 = capacity(user_id1);
    cap2 = capacity(user_id2);
    if (isna(cap1) || isnan(cap1) || isna(cap2) || isnan(cap2))
      result = "";
      return;
    endif
    capacity(user_id1) = cap1 + cap2;
    for i = 1:numel(order)
      name = order{i};
      if (!files.isKey(name))
        continue;
      endif
      item = files(name);
      if (strcmp(item.owner, user_id2))
        item.owner = user_id1;
        files(name) = item;
      endif
    endfor
    remove(capacity, user_id2);
    if (backups.isKey(user_id2))
      remove(backups, user_id2);
    endif
    left = remaining_of(user_id1);
    if (isempty(left))
      result = "";
      return;
    endif
    result = sprintf("%d", left);
  endfunction

  function result = backup_user(user_id)
    if (!capacity.isKey(user_id))
      result = "";
      return;
    endif
    snap = {};
    for i = 1:numel(order)
      name = order{i};
      if (!files.isKey(name))
        continue;
      endif
      item = files(name);
      if (strcmp(item.owner, user_id))
        snap{end + 1} = {name, item.size};
      endif
    endfor
    backups(user_id) = snap;
    result = sprintf("%d", numel(snap));
  endfunction

  function result = restore_user(user_id)
    if (!capacity.isKey(user_id))
      result = "";
      return;
    endif
    keep = {};
    for i = 1:numel(order)
      name = order{i};
      if (!files.isKey(name))
        continue;
      endif
      item = files(name);
      if (strcmp(item.owner, user_id))
        remove(files, name);
      else
        keep{end + 1} = name;
      endif
    endfor
    order = keep;
    if (!backups.isKey(user_id))
      result = "0";
      return;
    endif
    snapshot = backups(user_id);
    restored = 0;
    for i = 1:numel(snapshot)
      row = snapshot{i};
      name = row{1};
      size = row{2};
      if (files.isKey(name))
        continue;
      endif
      left = remaining_of(user_id);
      if (isempty(left) || size <= left)
        add_item(name, size, user_id);
        restored += 1;
      endif
    endfor
    result = sprintf("%d", restored);
  endfunction
endfunction
