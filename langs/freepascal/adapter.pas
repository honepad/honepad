program adapter;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes, minijson, solution;

type
  TFnIS = function(A: Int64; const B: string): TJsonVal of object;
  TFnISI = function(A: Int64; const B: string; C: Int64): TJsonVal of object;
  TFnISSI = function(A: Int64; const B, C: string; D: Int64): TJsonVal of object;
  TFnII = function(A, B: Int64): TJsonVal of object;
  TFnISS = function(A: Int64; const B, C: string): TJsonVal of object;
  TFnSI = function(const A: string; B: Int64): TJsonVal of object;
  TFnS = function(const A: string): TJsonVal of object;
  TFnSS = function(const A, B: string): TJsonVal of object;
  TFnSSI = function(const A, B: string; C: Int64): TJsonVal of object;
  TFnSSSI = function(const A, B, C: string; D: Int64): TJsonVal of object;
  TFnSSSII = function(const A, B, C: string; D, E: Int64): TJsonVal of object;
  TFnI = function(A: Int64): TJsonVal of object;
  TFnSII = function(const A: string; B, C: Int64): TJsonVal of object;
  TFnSSS = function(const A, B, C: string): TJsonVal of object;
  TFnSSII = function(const A, B: string; C, D: Int64): TJsonVal of object;
  TFnNone = function: TJsonVal of object;

function Bind(Obj: TObject; const Name, Method: string): TMethod;
begin
  Result.Code := Obj.MethodAddress(Name);
  Result.Data := Obj;
  if Result.Code = nil then
    raise Exception.Create('missing method ' + Method);
end;

function Need(Obj: TJsonVal; const Key: string): TJsonVal;
begin
  Result := Obj.ObjGet(Key);
  if Result = nil then
    raise Exception.Create('missing json key ' + Key);
end;

function DispatchCall(Obj: TObject; const Method: string; Args: TJsonVal): TJsonVal;
var
  M: TMethod;
begin
  if Method = 'create_account' then
  begin
    M := Bind(Obj, 'CreateAccount', Method);
    Exit(TFnIS(M)(ArgInt(Args, 0), ArgStr(Args, 1)));
  end;
  if Method = 'deposit' then
  begin
    M := Bind(Obj, 'Deposit', Method);
    Exit(TFnISI(M)(ArgInt(Args, 0), ArgStr(Args, 1), ArgInt(Args, 2)));
  end;
  if Method = 'transfer' then
  begin
    M := Bind(Obj, 'Transfer', Method);
    Exit(TFnISSI(M)(ArgInt(Args, 0), ArgStr(Args, 1), ArgStr(Args, 2), ArgInt(Args, 3)));
  end;
  if Method = 'top_spenders' then
  begin
    M := Bind(Obj, 'TopSpenders', Method);
    Exit(TFnII(M)(ArgInt(Args, 0), ArgInt(Args, 1)));
  end;
  if Method = 'pay' then
  begin
    M := Bind(Obj, 'Pay', Method);
    Exit(TFnISI(M)(ArgInt(Args, 0), ArgStr(Args, 1), ArgInt(Args, 2)));
  end;
  if Method = 'get_payment_status' then
  begin
    M := Bind(Obj, 'GetPaymentStatus', Method);
    Exit(TFnISS(M)(ArgInt(Args, 0), ArgStr(Args, 1), ArgStr(Args, 2)));
  end;
  if Method = 'merge_accounts' then
  begin
    M := Bind(Obj, 'MergeAccounts', Method);
    Exit(TFnISS(M)(ArgInt(Args, 0), ArgStr(Args, 1), ArgStr(Args, 2)));
  end;
  if Method = 'get_balance' then
  begin
    M := Bind(Obj, 'GetBalance', Method);
    Exit(TFnISI(M)(ArgInt(Args, 0), ArgStr(Args, 1), ArgInt(Args, 2)));
  end;
  if Method = 'add_file' then
  begin
    M := Bind(Obj, 'AddFile', Method);
    Exit(TFnSI(M)(ArgStr(Args, 0), ArgInt(Args, 1)));
  end;
  if Method = 'get_file_size' then
  begin
    M := Bind(Obj, 'GetFileSize', Method);
    Exit(TFnS(M)(ArgStr(Args, 0)));
  end;
  if Method = 'delete_file' then
  begin
    M := Bind(Obj, 'DeleteFile', Method);
    Exit(TFnS(M)(ArgStr(Args, 0)));
  end;
  if Method = 'copy_file' then
  begin
    M := Bind(Obj, 'CopyFile', Method);
    Exit(TFnSS(M)(ArgStr(Args, 0), ArgStr(Args, 1)));
  end;
  if Method = 'get_n_largest' then
  begin
    M := Bind(Obj, 'GetNLargest', Method);
    Exit(TFnSI(M)(ArgStr(Args, 0), ArgInt(Args, 1)));
  end;
  if Method = 'add_user' then
  begin
    M := Bind(Obj, 'AddUser', Method);
    Exit(TFnSI(M)(ArgStr(Args, 0), ArgInt(Args, 1)));
  end;
  if Method = 'add_file_by' then
  begin
    M := Bind(Obj, 'AddFileBy', Method);
    Exit(TFnSSI(M)(ArgStr(Args, 0), ArgStr(Args, 1), ArgInt(Args, 2)));
  end;
  if Method = 'merge_user' then
  begin
    M := Bind(Obj, 'MergeUser', Method);
    Exit(TFnSS(M)(ArgStr(Args, 0), ArgStr(Args, 1)));
  end;
  if Method = 'backup_user' then
  begin
    M := Bind(Obj, 'BackupUser', Method);
    Exit(TFnS(M)(ArgStr(Args, 0)));
  end;
  if Method = 'restore_user' then
  begin
    M := Bind(Obj, 'RestoreUser', Method);
    Exit(TFnS(M)(ArgStr(Args, 0)));
  end;
  if Method = 'add_worker' then
  begin
    M := Bind(Obj, 'AddWorker', Method);
    Exit(TFnSSI(M)(ArgStr(Args, 0), ArgStr(Args, 1), ArgInt(Args, 2)));
  end;
  if Method = 'register' then
  begin
    M := Bind(Obj, 'Register', Method);
    Exit(TFnSI(M)(ArgStr(Args, 0), ArgInt(Args, 1)));
  end;
  if Method = 'get' then
  begin
    if ArgCount(Args) = 1 then
    begin
      M := Bind(Obj, 'Get', Method);
      Exit(TFnS(M)(ArgStr(Args, 0)));
    end;
    M := Bind(Obj, 'Get', Method);
    Exit(TFnSS(M)(ArgStr(Args, 0), ArgStr(Args, 1)));
  end;
  if Method = 'top_n_workers' then
  begin
    M := Bind(Obj, 'TopNWorkers', Method);
    Exit(TFnIS(M)(ArgInt(Args, 0), ArgStr(Args, 1)));
  end;
  if Method = 'promote' then
  begin
    M := Bind(Obj, 'Promote', Method);
    Exit(TFnSSII(M)(ArgStr(Args, 0), ArgStr(Args, 1), ArgInt(Args, 2), ArgInt(Args, 3)));
  end;
  if Method = 'set_double_pay' then
  begin
    M := Bind(Obj, 'SetDoublePay', Method);
    Exit(TFnSII(M)(ArgStr(Args, 0), ArgInt(Args, 1), ArgInt(Args, 2)));
  end;
  if Method = 'create_item' then
  begin
    M := Bind(Obj, 'CreateItem', Method);
    Exit(TFnSS(M)(ArgStr(Args, 0), ArgStr(Args, 1)));
  end;
  if Method = 'allow' then
  begin
    M := Bind(Obj, 'Allow', Method);
    Exit(TFnSI(M)(ArgStr(Args, 0), ArgInt(Args, 1)));
  end;
  if Method = 'configure' then
  begin
    M := Bind(Obj, 'Configure', Method);
    Exit(TFnSII(M)(ArgStr(Args, 0), ArgInt(Args, 1), ArgInt(Args, 2)));
  end;
  if Method = 'remaining' then
  begin
    M := Bind(Obj, 'Remaining', Method);
    Exit(TFnSI(M)(ArgStr(Args, 0), ArgInt(Args, 1)));
  end;
  if Method = 'allow_weighted' then
  begin
    M := Bind(Obj, 'AllowWeighted', Method);
    Exit(TFnSII(M)(ArgStr(Args, 0), ArgInt(Args, 1), ArgInt(Args, 2)));
  end;
  if Method = 'stock' then
  begin
    M := Bind(Obj, 'Stock', Method);
    Exit(TFnSI(M)(ArgStr(Args, 0), ArgInt(Args, 1)));
  end;
  if Method = 'get_qty' then
  begin
    M := Bind(Obj, 'GetQty', Method);
    Exit(TFnS(M)(ArgStr(Args, 0)));
  end;
  if Method = 'list_low' then
  begin
    M := Bind(Obj, 'ListLow', Method);
    Exit(TFnI(M)(ArgInt(Args, 0)));
  end;
  if Method = 'reserve' then
  begin
    M := Bind(Obj, 'Reserve', Method);
    Exit(TFnSI(M)(ArgStr(Args, 0), ArgInt(Args, 1)));
  end;
  if Method = 'release' then
  begin
    M := Bind(Obj, 'Release', Method);
    Exit(TFnSI(M)(ArgStr(Args, 0), ArgInt(Args, 1)));
  end;
  if Method = 'ship' then
  begin
    M := Bind(Obj, 'Ship', Method);
    Exit(TFnSI(M)(ArgStr(Args, 0), ArgInt(Args, 1)));
  end;
  if Method = 'calc_salary' then
  begin
    M := Bind(Obj, 'CalcSalary', Method);
    Exit(TFnSII(M)(ArgStr(Args, 0), ArgInt(Args, 1), ArgInt(Args, 2)));
  end;
  if Method = 'set' then
  begin
    M := Bind(Obj, 'SetField', Method);
    Exit(TFnSSS(M)(ArgStr(Args, 0), ArgStr(Args, 1), ArgStr(Args, 2)));
  end;
  if Method = 'delete' then
  begin
    M := Bind(Obj, 'DeleteField', Method);
    Exit(TFnSS(M)(ArgStr(Args, 0), ArgStr(Args, 1)));
  end;
  if Method = 'scan' then
  begin
    M := Bind(Obj, 'Scan', Method);
    Exit(TFnS(M)(ArgStr(Args, 0)));
  end;
  if Method = 'scan_by_prefix' then
  begin
    M := Bind(Obj, 'ScanByPrefix', Method);
    Exit(TFnSS(M)(ArgStr(Args, 0), ArgStr(Args, 1)));
  end;
  if Method = 'set_at' then
  begin
    M := Bind(Obj, 'SetAt', Method);
    Exit(TFnSSSI(M)(ArgStr(Args, 0), ArgStr(Args, 1), ArgStr(Args, 2), ArgInt(Args, 3)));
  end;
  if Method = 'set_at_with_ttl' then
  begin
    M := Bind(Obj, 'SetAtWithTtl', Method);
    Exit(TFnSSSII(M)(ArgStr(Args, 0), ArgStr(Args, 1), ArgStr(Args, 2),
      ArgInt(Args, 3), ArgInt(Args, 4)));
  end;
  if Method = 'delete_at' then
  begin
    M := Bind(Obj, 'DeleteAt', Method);
    Exit(TFnSSI(M)(ArgStr(Args, 0), ArgStr(Args, 1), ArgInt(Args, 2)));
  end;
  if Method = 'get_at' then
  begin
    M := Bind(Obj, 'GetAt', Method);
    Exit(TFnSSI(M)(ArgStr(Args, 0), ArgStr(Args, 1), ArgInt(Args, 2)));
  end;
  if Method = 'scan_at' then
  begin
    M := Bind(Obj, 'ScanAt', Method);
    Exit(TFnSI(M)(ArgStr(Args, 0), ArgInt(Args, 1)));
  end;
  if Method = 'scan_by_prefix_at' then
  begin
    M := Bind(Obj, 'ScanByPrefixAt', Method);
    Exit(TFnSSI(M)(ArgStr(Args, 0), ArgStr(Args, 1), ArgInt(Args, 2)));
  end;
  if Method = 'backup' then
  begin
    M := Bind(Obj, 'Backup', Method);
    Exit(TFnI(M)(ArgInt(Args, 0)));
  end;
  if Method = 'restore' then
  begin
    M := Bind(Obj, 'Restore', Method);
    Exit(TFnII(M)(ArgInt(Args, 0), ArgInt(Args, 1)));
  end;
  if Method = 'add_gpu' then
  begin
    M := Bind(Obj, 'AddGpu', Method);
    Exit(TFnSI(M)(ArgStr(Args, 0), ArgInt(Args, 1)));
  end;
  if Method = 'submit_job' then
  begin
    M := Bind(Obj, 'SubmitJob', Method);
    Exit(TFnSI(M)(ArgStr(Args, 0), ArgInt(Args, 1)));
  end;
  if Method = 'status' then
  begin
    M := Bind(Obj, 'Status', Method);
    Exit(TFnS(M)(ArgStr(Args, 0)));
  end;
  if Method = 'assign' then
  begin
    M := Bind(Obj, 'Assign', Method);
    Exit(TFnNone(M)());
  end;
  if Method = 'complete' then
  begin
    M := Bind(Obj, 'Complete', Method);
    Exit(TFnS(M)(ArgStr(Args, 0)));
  end;
  if Method = 'cancel' then
  begin
    M := Bind(Obj, 'Cancel', Method);
    Exit(TFnS(M)(ArgStr(Args, 0)));
  end;
  if Method = 'set_priority' then
  begin
    M := Bind(Obj, 'SetPriority', Method);
    Exit(TFnSI(M)(ArgStr(Args, 0), ArgInt(Args, 1)));
  end;
  if Method = 'add_backend' then
  begin
    M := Bind(Obj, 'AddBackend', Method);
    Exit(TFnS(M)(ArgStr(Args, 0)));
  end;
  if Method = 'route' then
  begin
    M := Bind(Obj, 'Route', Method);
    Exit(TFnNone(M)());
  end;
  if Method = 'set_health' then
  begin
    M := Bind(Obj, 'SetHealth', Method);
    Exit(TFnSI(M)(ArgStr(Args, 0), ArgInt(Args, 1)));
  end;
  if Method = 'set_weight' then
  begin
    M := Bind(Obj, 'SetWeight', Method);
    Exit(TFnSI(M)(ArgStr(Args, 0), ArgInt(Args, 1)));
  end;
  if Method = 'sticky' then
  begin
    M := Bind(Obj, 'Sticky', Method);
    Exit(TFnS(M)(ArgStr(Args, 0)));
  end;
  if Method = 'done' then
  begin
    M := Bind(Obj, 'Done', Method);
    Exit(TFnS(M)(ArgStr(Args, 0)));
  end;
  if Method = 'subscribe' then
  begin
    M := Bind(Obj, 'Subscribe', Method);
    Exit(TFnSS(M)(ArgStr(Args, 0), ArgStr(Args, 1)));
  end;
  if Method = 'unsubscribe' then
  begin
    M := Bind(Obj, 'Unsubscribe', Method);
    Exit(TFnSS(M)(ArgStr(Args, 0), ArgStr(Args, 1)));
  end;
  if Method = 'publish' then
  begin
    M := Bind(Obj, 'Publish', Method);
    Exit(TFnSS(M)(ArgStr(Args, 0), ArgStr(Args, 1)));
  end;
  if Method = 'inbox' then
  begin
    M := Bind(Obj, 'Inbox', Method);
    Exit(TFnS(M)(ArgStr(Args, 0)));
  end;
  if Method = 'list_topics' then
  begin
    M := Bind(Obj, 'ListTopics', Method);
    Exit(TFnNone(M)());
  end;
  if Method = 'subscribers' then
  begin
    M := Bind(Obj, 'Subscribers', Method);
    Exit(TFnS(M)(ArgStr(Args, 0)));
  end;
  if Method = 'peek' then
  begin
    M := Bind(Obj, 'Peek', Method);
    Exit(TFnS(M)(ArgStr(Args, 0)));
  end;
  if Method = 'ack' then
  begin
    M := Bind(Obj, 'Ack', Method);
    Exit(TFnSI(M)(ArgStr(Args, 0), ArgInt(Args, 1)));
  end;
  if Method = 'retain' then
  begin
    M := Bind(Obj, 'Retain', Method);
    Exit(TFnSS(M)(ArgStr(Args, 0), ArgStr(Args, 1)));
  end;
  if Method = 'insert' then
  begin
    M := Bind(Obj, 'Insert', Method);
    Exit(TFnIS(M)(ArgInt(Args, 0), ArgStr(Args, 1)));
  end;
  if Method = 'erase' then
  begin
    M := Bind(Obj, 'Erase', Method);
    Exit(TFnII(M)(ArgInt(Args, 0), ArgInt(Args, 1)));
  end;
  if Method = 'get_text' then
  begin
    M := Bind(Obj, 'GetText', Method);
    Exit(TFnNone(M)());
  end;
  if Method = 'length' then
  begin
    M := Bind(Obj, 'Length', Method);
    Exit(TFnNone(M)());
  end;
  if Method = 'move' then
  begin
    M := Bind(Obj, 'Move', Method);
    Exit(TFnI(M)(ArgInt(Args, 0)));
  end;
  if Method = 'type_text' then
  begin
    M := Bind(Obj, 'TypeText', Method);
    Exit(TFnS(M)(ArgStr(Args, 0)));
  end;
  if Method = 'cursor' then
  begin
    M := Bind(Obj, 'Cursor', Method);
    Exit(TFnNone(M)());
  end;
  if Method = 'undo' then
  begin
    M := Bind(Obj, 'Undo', Method);
    Exit(TFnNone(M)());
  end;
  if Method = 'redo' then
  begin
    M := Bind(Obj, 'Redo', Method);
    Exit(TFnNone(M)());
  end;
  if Method = 'select' then
  begin
    M := Bind(Obj, 'Select', Method);
    Exit(TFnII(M)(ArgInt(Args, 0), ArgInt(Args, 1)));
  end;
  if Method = 'cut' then
  begin
    M := Bind(Obj, 'Cut', Method);
    Exit(TFnNone(M)());
  end;
  if Method = 'copy_sel' then
  begin
    M := Bind(Obj, 'CopySel', Method);
    Exit(TFnNone(M)());
  end;
  if Method = 'paste' then
  begin
    M := Bind(Obj, 'Paste', Method);
    Exit(TFnNone(M)());
  end;
  raise Exception.Create('unknown method ' + Method);
end;

function FailRow(const CaseId: string; Index: Integer; const Method: string;
  Expected, Actual: TJsonVal): TJsonVal;
begin
  Result := JsonObj;
  Result.ObjPut('case', JsonStr(CaseId));
  Result.ObjPut('index', JsonInt(Index));
  Result.ObjPut('method', JsonStr(Method));
  Result.ObjPut('expected', JsonClone(Expected));
  Result.ObjPut('actual', Actual);
end;

function ReadAll(const Path: string): string;
var
  F: TFileStream;
begin
  F := TFileStream.Create(Path, fmOpenRead or fmShareDenyNone);
  try
    SetLength(Result, F.Size);
    if F.Size > 0 then
      F.ReadBuffer(Result[1], F.Size);
  finally
    F.Free;
  end;
end;

var
  Cases: TJsonVal;
  Failed: TJsonVal;
  Passed: Integer;
  C, I: Integer;
  Row, Calls, Call, Expected, Args, Actual, Report: TJsonVal;
  Obj: TObject;
  CaseId, Method, Got, Want: string;
  Ok: Boolean;
begin
  if ParamCount < 1 then
  begin
    WriteLn(StdErr, 'usage: adapter cases.json');
    Halt(2);
  end;
  Cases := JsonParse(ReadAll(ParamStr(1)));
  if Cases.Kind <> jkArr then
  begin
    WriteLn(StdErr, 'cases.json must be a JSON list');
    Halt(2);
  end;
  Failed := JsonArr;
  Passed := 0;
  for C := 0 to High(Cases.Arr) do
  begin
    Row := Cases.Arr[C];
    Obj := NewTarget;
    CaseId := Need(Row, 'id').S;
    Calls := Need(Row, 'calls');
    Ok := True;
    for I := 0 to High(Calls.Arr) do
    begin
      Call := Calls.Arr[I];
      Method := Need(Call, 'm').S;
      Expected := Need(Call, 'e');
      Args := Need(Call, 'a');
      try
        Actual := DispatchCall(Obj, Method, Args);
      except
        on E: Exception do
        begin
          Failed.ArrAdd(FailRow(CaseId, I, Method, Expected, JsonStr('exc:' + E.Message)));
          Ok := False;
          Break;
        end;
      end;
      Got := JsonStringify(Actual);
      Want := JsonStringify(Expected);
      if Got <> Want then
      begin
        Failed.ArrAdd(FailRow(CaseId, I, Method, Expected, Actual));
        Ok := False;
        Break;
      end;
      Actual.Free;
    end;
    Obj.Free;
    if Ok then
      Inc(Passed);
  end;
  Report := JsonObj;
  Report.ObjPut('passed', JsonInt(Passed));
  Report.ObjPut('failed', Failed);
  WriteLn(JsonStringify(Report));
  if Length(Failed.Arr) > 0 then
    Halt(1);
end.
