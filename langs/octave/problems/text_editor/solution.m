function obj = Simulation()
  buf = "";
  pos = 0;
  undo_buf = {};
  undo_pos = [];
  redo_buf = {};
  redo_pos = [];
  sel_start = -1;
  sel_end = -1;
  clip = "";

  obj.insert = @insert;
  obj.erase = @erase;
  obj.get_text = @get_text;
  obj.length = @length;
  obj.move = @move;
  obj.type_text = @type_text;
  obj.cursor = @cursor;
  obj.undo = @undo;
  obj.redo = @redo;
  obj.select = @select;
  obj.cut = @cut;
  obj.copy_sel = @copy_sel;
  obj.paste = @paste;

  function push()
    undo_buf{end + 1} = buf;
    undo_pos(end + 1) = pos;
    redo_buf = {};
    redo_pos = [];
    sel_start = -1;
    sel_end = -1;
  endfunction

  function result = insert(at, text)
    if (at < 0 || at > length(buf))
      result = "invalid_request";
      return;
    endif
    push();
    buf = [buf(1:at), text, buf(at + 1:end)];
    result = sprintf("%d", length(buf));
  endfunction

  function result = erase(at, n)
    if (n <= 0 || at < 0 || at + n > length(buf))
      result = "invalid_request";
      return;
    endif
    push();
    deleted = buf(at + 1:at + n);
    buf = [buf(1:at), buf(at + n + 1:end)];
    if (pos > length(buf))
      pos = length(buf);
    endif
    result = deleted;
  endfunction

  function result = get_text()
    result = buf;
  endfunction

  function result = length_()
    result = sprintf("%d", length(buf));
  endfunction
  obj.length = @length_;

  function result = move(at)
    if (at < 0 || at > length(buf))
      result = "invalid_request";
      return;
    endif
    pos = at;
    result = "true";
  endfunction

  function result = type_text(text)
    push();
    at = pos;
    buf = [buf(1:at), text, buf(at + 1:end)];
    pos = at + length(text);
    result = sprintf("%d", length(buf));
  endfunction

  function result = cursor()
    result = sprintf("%d", pos);
  endfunction

  function result = undo()
    if (isempty(undo_buf))
      result = "false";
      return;
    endif
    redo_buf{end + 1} = buf;
    redo_pos(end + 1) = pos;
    buf = undo_buf{end};
    pos = undo_pos(end);
    undo_buf(end) = [];
    undo_pos(end) = [];
    sel_start = -1;
    sel_end = -1;
    result = "true";
  endfunction

  function result = redo()
    if (isempty(redo_buf))
      result = "false";
      return;
    endif
    undo_buf{end + 1} = buf;
    undo_pos(end + 1) = pos;
    buf = redo_buf{end};
    pos = redo_pos(end);
    redo_buf(end) = [];
    redo_pos(end) = [];
    sel_start = -1;
    sel_end = -1;
    result = "true";
  endfunction

  function result = select(start, last)
    if (start < 0 || last < 0 || start > last || last > length(buf))
      result = "invalid_request";
      return;
    endif
    sel_start = start;
    sel_end = last;
    result = "true";
  endfunction

  function result = cut()
    if (sel_start < 0 || sel_start == sel_end)
      result = "invalid_request";
      return;
    endif
    text = buf(sel_start + 1:sel_end);
    buf = [buf(1:sel_start), buf(sel_end + 1:end)];
    clip = text;
    pos = sel_start;
    sel_start = -1;
    sel_end = -1;
    result = text;
  endfunction

  function result = copy_sel()
    if (sel_start < 0 || sel_start == sel_end)
      result = "invalid_request";
      return;
    endif
    clip = buf(sel_start + 1:sel_end);
    result = clip;
  endfunction

  function result = paste()
    if (strcmp(clip, ""))
      result = "invalid_request";
      return;
    endif
    at = pos;
    buf = [buf(1:at), clip, buf(at + 1:end)];
    pos = at + length(clip);
    result = sprintf("%d", length(buf));
  endfunction
endfunction
