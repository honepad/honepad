function obj = InMemoryDatabase()
  database = containers.Map();
  backup_timestamps = [];
  backup_states = {};

  obj.set = @set;
  obj.get = @get;
  obj.delete = @delete_field;
  obj.scan = @scan;
  obj.scan_by_prefix = @scan_by_prefix;
  obj.set_at = @set_at;
  obj.set_at_with_ttl = @set_at_with_ttl;
  obj.delete_at = @delete_at;
  obj.get_at = @get_at;
  obj.scan_at = @scan_at;
  obj.scan_by_prefix_at = @scan_by_prefix_at;
  obj.backup = @backup;
  obj.restore = @restore;

  function result = set_internal(key, field, value, expiry)
    if (!database.isKey(key))
      database(key) = containers.Map();
    endif
    fields = database(key);
    fields(field) = {value, expiry};
    database(key) = fields;
    result = "";
  endfunction

  function ok = is_alive(key, field, timestamp)
    if (!database.isKey(key))
      ok = false;
      return;
    endif
    fields = database(key);
    if (!fields.isKey(field))
      ok = false;
      return;
    endif
    entry = fields(field);
    expiry = entry{2};
    if (isempty(expiry))
      ok = true;
      return;
    endif
    ok = timestamp < expiry;
  endfunction

  function result = set(key, field, value)
    result = set_internal(key, field, value, []);
  endfunction

  function result = get(key, field)
    if (!database.isKey(key))
      result = "";
      return;
    endif
    fields = database(key);
    if (!fields.isKey(field))
      result = "";
      return;
    endif
    entry = fields(field);
    result = entry{1};
  endfunction

  function result = delete_field(key, field)
    if (!database.isKey(key))
      result = "false";
      return;
    endif
    fields = database(key);
    if (!fields.isKey(field))
      result = "false";
      return;
    endif
    remove(fields, field);
    database(key) = fields;
    result = "true";
  endfunction

  function names = sorted_fields(key)
    names = {};
    if (!database.isKey(key))
      return;
    endif
    names = database(key).keys();
    names = sort(names);
  endfunction

  function result = scan(key)
    if (!database.isKey(key))
      result = "";
      return;
    endif
    fields = database(key);
    names = sorted_fields(key);
    parts = {};
    for i = 1:numel(names)
      entry = fields(names{i});
      parts{end + 1} = sprintf("%s(%s)", names{i}, entry{1});
    endfor
    result = strjoin(parts, ", ");
  endfunction

  function result = scan_by_prefix(key, prefix)
    if (!database.isKey(key))
      result = "";
      return;
    endif
    fields = database(key);
    names = sorted_fields(key);
    parts = {};
    for i = 1:numel(names)
      if (strncmp(names{i}, prefix, length(prefix)))
        entry = fields(names{i});
        parts{end + 1} = sprintf("%s(%s)", names{i}, entry{1});
      endif
    endfor
    result = strjoin(parts, ", ");
  endfunction

  function result = set_at(key, field, value, timestamp)
    result = set_internal(key, field, value, []);
  endfunction

  function result = set_at_with_ttl(key, field, value, timestamp, ttl)
    result = set_internal(key, field, value, timestamp + ttl);
  endfunction

  function result = delete_at(key, field, timestamp)
    if (!is_alive(key, field, timestamp))
      result = "false";
      return;
    endif
    fields = database(key);
    remove(fields, field);
    database(key) = fields;
    result = "true";
  endfunction

  function result = get_at(key, field, timestamp)
    if (!is_alive(key, field, timestamp))
      result = "";
      return;
    endif
    fields = database(key);
    entry = fields(field);
    result = entry{1};
  endfunction

  function result = scan_at(key, timestamp)
    if (!database.isKey(key))
      result = "";
      return;
    endif
    fields = database(key);
    names = sorted_fields(key);
    parts = {};
    for i = 1:numel(names)
      if (is_alive(key, names{i}, timestamp))
        entry = fields(names{i});
        parts{end + 1} = sprintf("%s(%s)", names{i}, entry{1});
      endif
    endfor
    result = strjoin(parts, ", ");
  endfunction

  function result = scan_by_prefix_at(key, prefix, timestamp)
    if (!database.isKey(key))
      result = "";
      return;
    endif
    fields = database(key);
    names = sorted_fields(key);
    parts = {};
    for i = 1:numel(names)
      if (strncmp(names{i}, prefix, length(prefix)) && is_alive(key, names{i}, timestamp))
        entry = fields(names{i});
        parts{end + 1} = sprintf("%s(%s)", names{i}, entry{1});
      endif
    endfor
    result = strjoin(parts, ", ");
  endfunction

  function result = backup(timestamp)
    state = containers.Map();
    count = 0;
    keys = database.keys();
    for i = 1:numel(keys)
      key = keys{i};
      fields = database(key);
      fnames = fields.keys();
      for j = 1:numel(fnames)
        field = fnames{j};
        if (!is_alive(key, field, timestamp))
          continue;
        endif
        if (!state.isKey(key))
          state(key) = containers.Map();
          count += 1;
        endif
        entry = fields(field);
        expiry = entry{2};
        remaining = [];
        if (!isempty(expiry))
          remaining = expiry - timestamp;
        endif
        snap = state(key);
        snap(field) = {entry{1}, remaining};
        state(key) = snap;
      endfor
    endfor
    backup_timestamps(end + 1) = timestamp;
    backup_states{end + 1} = state;
    result = sprintf("%d", count);
  endfunction

  function result = restore(timestamp, timestamp_to_restore)
    idx = 0;
    for i = 1:numel(backup_timestamps)
      if (backup_timestamps(i) <= timestamp_to_restore)
        idx = i;
      endif
    endfor
    backup_state = backup_states{idx};
    database = containers.Map();
    keys = backup_state.keys();
    for i = 1:numel(keys)
      key = keys{i};
      fields = backup_state(key);
      fnames = fields.keys();
      for j = 1:numel(fnames)
        field = fnames{j};
        entry = fields(field);
        remaining = entry{2};
        expiry = [];
        if (!isempty(remaining))
          expiry = timestamp + remaining;
        endif
        set_internal(key, field, entry{1}, expiry);
      endfor
    endfor
    result = "";
  endfunction
endfunction
