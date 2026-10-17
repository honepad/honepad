1;
more off;
page_screen_output(0);

function items = as_cell_list(value)
  if (isempty(value) && !isstruct(value) && !iscell(value))
    items = {};
    return;
  endif
  if (iscell(value))
    items = value(:).';
    return;
  endif
  if (isstruct(value))
    items = cell(1, numel(value));
    for i = 1:numel(value)
      items{i} = value(i);
    endfor
    return;
  endif
  items = {value};
endfunction

function args = as_args(value)
  if (iscell(value))
    args = value(:).';
    return;
  endif
  if (isempty(value))
    args = {};
    return;
  endif
  args = cell(1, numel(value));
  for i = 1:numel(value)
    args{i} = value(i);
  endfor
endfunction

function bad = contains_nonfinite(value)
  bad = false;
  if (isnumeric(value))
    bad = any(isnan(value(:))) || any(isinf(value(:)));
    return;
  endif
  if (iscell(value))
    for i = 1:numel(value)
      if (contains_nonfinite(value{i}))
        bad = true;
        return;
      endif
    endfor
    return;
  endif
  if (isstruct(value))
    names = fieldnames(value);
    for s = 1:numel(value)
      for f = 1:numel(names)
        if (contains_nonfinite(value(s).(names{f})))
          bad = true;
          return;
        endif
      endfor
    endfor
  endif
endfunction

function value = tag_nonfinite(value)
  if (isnumeric(value))
    if (isscalar(value))
      if (isnan(value))
        value = "NaN";
      elseif (isinf(value))
        if (value > 0)
          value = "Infinity";
        else
          value = "-Infinity";
        endif
      endif
      return;
    endif
    tagged = cell(1, numel(value));
    for i = 1:numel(value)
      tagged{i} = tag_nonfinite(value(i));
    endfor
    value = tagged;
    return;
  endif
  if (iscell(value))
    for i = 1:numel(value)
      value{i} = tag_nonfinite(value{i});
    endfor
    return;
  endif
  if (isstruct(value))
    names = fieldnames(value);
    for s = 1:numel(value)
      for f = 1:numel(names)
        name = names{f};
        value(s).(name) = tag_nonfinite(value(s).(name));
      endfor
    endfor
  endif
endfunction

function row = fail_row(case_id, index, method, expected, actual)
  row.case = case_id;
  row.index = index;
  row.method = method;
  row.expected = expected;
  row.actual = actual;
endfunction

args = argv();
src = args{1};
class_name = args{2};
cases_path = args{3};

report_fid = fopen("/dev/stdout", "w");
null_fid = fopen("/dev/null", "w");
dup2(null_fid, stdout);

tmpdir = tempname();
mkdir(tmpdir);
copyfile(src, fullfile(tmpdir, [class_name ".m"]));
addpath(tmpdir);
if (exist(class_name) == 0)
  error("missing class %s", class_name);
endif

cases = as_cell_list(jsondecode(fileread(cases_path)));
failed = {};
passed = 0;

for ci = 1:numel(cases)
  case_row = cases{ci};
  obj = feval(class_name);
  ok = true;
  calls = {};
  if (isfield(case_row, "calls"))
    calls = as_cell_list(case_row.calls);
  endif
  for i = 1:numel(calls)
    call = calls{i};
    method = call.m;
    call_args = {};
    if (isfield(call, "a"))
      call_args = as_args(call.a);
    endif
    expected = [];
    if (isfield(call, "e"))
      expected = call.e;
    endif
    if (!isstruct(obj) || !isfield(obj, method) || !is_function_handle(obj.(method)))
      failed{end + 1} = fail_row(case_row.id, i - 1, method, expected, "exc:missing_method");
      ok = false;
      break;
    endif
    try
      actual = obj.(method)(call_args{:});
    catch err
      msg = strtrim(err.message);
      failed{end + 1} = fail_row(case_row.id, i - 1, method, expected, ["exc:" msg]);
      ok = false;
      break;
    end_try_catch
    if (contains_nonfinite(actual) || !strcmp(jsonencode(actual), jsonencode(expected)))
      shown = actual;
      if (contains_nonfinite(actual))
        shown = tag_nonfinite(actual);
      endif
      failed{end + 1} = fail_row(case_row.id, i - 1, method, expected, shown);
      ok = false;
      break;
    endif
  endfor
  if (ok)
    passed += 1;
  endif
endfor

payload.passed = passed;
payload.failed = failed;
fputs(report_fid, [jsonencode(payload) "\n"]);
fflush(report_fid);
rmpath(tmpdir);
confirm_recursive_rmdir(0);
rmdir(tmpdir, "s");
if (numel(failed) > 0)
  exit(1);
endif
exit(0);
