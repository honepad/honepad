unit solution;

{$mode objfpc}{$H+}
{$M+}

interface

uses
  SysUtils, Classes, minijson;

type
  TFieldVal = class
  public
    Value: string;
    HasExpiry: Boolean;
    Expiry: Int64;
    constructor Create(const AValue: string; AHasExpiry: Boolean; AExpiry: Int64);
  end;

  TFieldMap = class(TStringList)
  public
    constructor Create;
    destructor Destroy; override;
    function GetField(const Field: string): TFieldVal;
    procedure PutField(const Field: string; Item: TFieldVal);
    procedure RemoveField(const Field: string);
  end;

  InMemoryDatabase = class
  private
    Database: TStringList;
    BackupTs: array of Int64;
    BackupStates: array of TStringList;
    function FieldsOf(const Key: string; CreateIfMissing: Boolean): TFieldMap;
    function IsAlive(const Key, Field: string; Timestamp: Int64): Boolean;
    function SetInternal(const Key, Field, Value: string; HasExpiry: Boolean;
      Expiry: Int64): TJsonVal;
    function ScanFiltered(const Key, Prefix: string; UseTime: Boolean;
      Timestamp: Int64): TJsonVal;
  public
    constructor Create;
    destructor Destroy; override;
  published
    function SetField(const Key, Field, Value: string): TJsonVal;
    function Get(const Key, Field: string): TJsonVal;
    function DeleteField(const Key, Field: string): TJsonVal;
    function Scan(const Key: string): TJsonVal;
    function ScanByPrefix(const Key, Prefix: string): TJsonVal;
    function SetAt(const Key, Field, Value: string; Timestamp: Int64): TJsonVal;
    function SetAtWithTtl(const Key, Field, Value: string; Timestamp, Ttl: Int64): TJsonVal;
    function DeleteAt(const Key, Field: string; Timestamp: Int64): TJsonVal;
    function GetAt(const Key, Field: string; Timestamp: Int64): TJsonVal;
    function ScanAt(const Key: string; Timestamp: Int64): TJsonVal;
    function ScanByPrefixAt(const Key, Prefix: string; Timestamp: Int64): TJsonVal;
    function Backup(Timestamp: Int64): TJsonVal;
    function Restore(Timestamp, TimestampToRestore: Int64): TJsonVal;
  end;

function NewTarget: TObject;

implementation

constructor TFieldVal.Create(const AValue: string; AHasExpiry: Boolean; AExpiry: Int64);
begin
  inherited Create;
  Value := AValue;
  HasExpiry := AHasExpiry;
  Expiry := AExpiry;
end;

constructor TFieldMap.Create;
begin
  inherited Create;
  Sorted := True;
  Duplicates := dupIgnore;
end;

destructor TFieldMap.Destroy;
var
  N: Integer;
begin
  for N := 0 to Count - 1 do
    Objects[N].Free;
  inherited Destroy;
end;

function TFieldMap.GetField(const Field: string): TFieldVal;
var
  Idx: Integer;
begin
  Idx := IndexOf(Field);
  if Idx < 0 then
    Result := nil
  else
    Result := TFieldVal(Objects[Idx]);
end;

procedure TFieldMap.PutField(const Field: string; Item: TFieldVal);
var
  Idx: Integer;
begin
  Idx := IndexOf(Field);
  if Idx >= 0 then
  begin
    Objects[Idx].Free;
    Objects[Idx] := Item;
  end
  else
    AddObject(Field, Item);
end;

procedure TFieldMap.RemoveField(const Field: string);
var
  Idx: Integer;
begin
  Idx := IndexOf(Field);
  if Idx >= 0 then
  begin
    Objects[Idx].Free;
    Delete(Idx);
  end;
end;

constructor InMemoryDatabase.Create;
begin
  inherited Create;
  Database := TStringList.Create;
  Database.Sorted := True;
  Database.Duplicates := dupIgnore;
end;

destructor InMemoryDatabase.Destroy;
var
  N: Integer;
begin
  for N := 0 to Database.Count - 1 do
    Database.Objects[N].Free;
  Database.Free;
  for N := 0 to High(BackupStates) do
  begin
    { owned field maps }
    BackupStates[N].OwnsObjects := False;
    while BackupStates[N].Count > 0 do
    begin
      BackupStates[N].Objects[0].Free;
      BackupStates[N].Delete(0);
    end;
    BackupStates[N].Free;
  end;
  inherited Destroy;
end;

function InMemoryDatabase.FieldsOf(const Key: string; CreateIfMissing: Boolean): TFieldMap;
var
  Idx: Integer;
begin
  Idx := Database.IndexOf(Key);
  if Idx >= 0 then
    Exit(TFieldMap(Database.Objects[Idx]));
  if not CreateIfMissing then
    Exit(nil);
  Result := TFieldMap.Create;
  Database.AddObject(Key, Result);
end;

function InMemoryDatabase.IsAlive(const Key, Field: string; Timestamp: Int64): Boolean;
var
  Fields: TFieldMap;
  Item: TFieldVal;
begin
  Fields := FieldsOf(Key, False);
  if Fields = nil then
    Exit(False);
  Item := Fields.GetField(Field);
  if Item = nil then
    Exit(False);
  if not Item.HasExpiry then
    Exit(True);
  Result := Timestamp < Item.Expiry;
end;

function InMemoryDatabase.SetInternal(const Key, Field, Value: string; HasExpiry: Boolean;
  Expiry: Int64): TJsonVal;
var
  Fields: TFieldMap;
begin
  Fields := FieldsOf(Key, True);
  Fields.PutField(Field, TFieldVal.Create(Value, HasExpiry, Expiry));
  Result := JsonStr('');
end;

function InMemoryDatabase.SetField(const Key, Field, Value: string): TJsonVal;
begin
  Result := SetInternal(Key, Field, Value, False, 0);
end;

function InMemoryDatabase.Get(const Key, Field: string): TJsonVal;
var
  Fields: TFieldMap;
  Item: TFieldVal;
begin
  Fields := FieldsOf(Key, False);
  if Fields = nil then
    Exit(JsonStr(''));
  Item := Fields.GetField(Field);
  if Item = nil then
    Exit(JsonStr(''));
  Result := JsonStr(Item.Value);
end;

function InMemoryDatabase.DeleteField(const Key, Field: string): TJsonVal;
var
  Fields: TFieldMap;
begin
  Fields := FieldsOf(Key, False);
  if (Fields = nil) or (Fields.GetField(Field) = nil) then
    Exit(JsonStr('false'));
  Fields.RemoveField(Field);
  Result := JsonStr('true');
end;

function InMemoryDatabase.ScanFiltered(const Key, Prefix: string; UseTime: Boolean;
  Timestamp: Int64): TJsonVal;
var
  Fields: TFieldMap;
  Names: array of string;
  I, J: Integer;
  Tmp: string;
  Item: TFieldVal;
begin
  Fields := FieldsOf(Key, False);
  if Fields = nil then
    Exit(JsonStr(''));
  SetLength(Names, 0);
  for I := 0 to Fields.Count - 1 do
  begin
    if (Prefix <> '') and (Copy(Fields[I], 1, Length(Prefix)) <> Prefix) then
      Continue;
    if UseTime and not IsAlive(Key, Fields[I], Timestamp) then
      Continue;
    SetLength(Names, Length(Names) + 1);
    Names[High(Names)] := Fields[I];
  end;
  for I := 0 to High(Names) - 1 do
    for J := I + 1 to High(Names) do
      if Names[J] < Names[I] then
      begin
        Tmp := Names[I];
        Names[I] := Names[J];
        Names[J] := Tmp;
      end;
  Result := JsonStr('');
  for I := 0 to High(Names) do
  begin
    Item := Fields.GetField(Names[I]);
    if I > 0 then
      Result.S := Result.S + ', ';
    Result.S := Result.S + Names[I] + '(' + Item.Value + ')';
  end;
end;

function InMemoryDatabase.Scan(const Key: string): TJsonVal;
begin
  Result := ScanFiltered(Key, '', False, 0);
end;

function InMemoryDatabase.ScanByPrefix(const Key, Prefix: string): TJsonVal;
begin
  Result := ScanFiltered(Key, Prefix, False, 0);
end;

function InMemoryDatabase.SetAt(const Key, Field, Value: string; Timestamp: Int64): TJsonVal;
begin
  Result := SetInternal(Key, Field, Value, False, 0);
end;

function InMemoryDatabase.SetAtWithTtl(const Key, Field, Value: string;
  Timestamp, Ttl: Int64): TJsonVal;
begin
  Result := SetInternal(Key, Field, Value, True, Timestamp + Ttl);
end;

function InMemoryDatabase.DeleteAt(const Key, Field: string; Timestamp: Int64): TJsonVal;
var
  Fields: TFieldMap;
begin
  if not IsAlive(Key, Field, Timestamp) then
    Exit(JsonStr('false'));
  Fields := FieldsOf(Key, False);
  Fields.RemoveField(Field);
  Result := JsonStr('true');
end;

function InMemoryDatabase.GetAt(const Key, Field: string; Timestamp: Int64): TJsonVal;
var
  Fields: TFieldMap;
  Item: TFieldVal;
begin
  if not IsAlive(Key, Field, Timestamp) then
    Exit(JsonStr(''));
  Fields := FieldsOf(Key, False);
  Item := Fields.GetField(Field);
  Result := JsonStr(Item.Value);
end;

function InMemoryDatabase.ScanAt(const Key: string; Timestamp: Int64): TJsonVal;
begin
  Result := ScanFiltered(Key, '', True, Timestamp);
end;

function InMemoryDatabase.ScanByPrefixAt(const Key, Prefix: string; Timestamp: Int64): TJsonVal;
begin
  Result := ScanFiltered(Key, Prefix, True, Timestamp);
end;

function InMemoryDatabase.Backup(Timestamp: Int64): TJsonVal;
var
  State: TStringList;
  I, J: Integer;
  Fields, Copied: TFieldMap;
  Item: TFieldVal;
  Remaining: Int64;
  HasRem: Boolean;
begin
  State := TStringList.Create;
  State.Sorted := True;
  State.Duplicates := dupIgnore;
  for I := 0 to Database.Count - 1 do
  begin
    Fields := TFieldMap(Database.Objects[I]);
    Copied := TFieldMap.Create;
    for J := 0 to Fields.Count - 1 do
    begin
      if not IsAlive(Database[I], Fields[J], Timestamp) then
        Continue;
      Item := TFieldVal(Fields.Objects[J]);
      HasRem := Item.HasExpiry;
      Remaining := 0;
      if HasRem then
        Remaining := Item.Expiry - Timestamp;
      Copied.PutField(Fields[J], TFieldVal.Create(Item.Value, HasRem, Remaining));
    end;
    if Copied.Count > 0 then
      State.AddObject(Database[I], Copied)
    else
      Copied.Free;
  end;
  SetLength(BackupTs, Length(BackupTs) + 1);
  BackupTs[High(BackupTs)] := Timestamp;
  SetLength(BackupStates, Length(BackupStates) + 1);
  BackupStates[High(BackupStates)] := State;
  Result := JsonStr(IntToStr(State.Count));
end;

function InMemoryDatabase.Restore(Timestamp, TimestampToRestore: Int64): TJsonVal;
var
  Idx, I, J: Integer;
  State: TStringList;
  Fields: TFieldMap;
  Item: TFieldVal;
  Expiry: Int64;
  HasExpiry: Boolean;
begin
  Idx := -1;
  for I := 0 to High(BackupTs) do
    if BackupTs[I] <= TimestampToRestore then
      Idx := I;
  State := BackupStates[Idx];
  for I := 0 to Database.Count - 1 do
    Database.Objects[I].Free;
  Database.Clear;
  for I := 0 to State.Count - 1 do
  begin
    Fields := TFieldMap(State.Objects[I]);
    for J := 0 to Fields.Count - 1 do
    begin
      Item := TFieldVal(Fields.Objects[J]);
      HasExpiry := Item.HasExpiry;
      Expiry := 0;
      if HasExpiry then
        Expiry := Timestamp + Item.Expiry;
      SetInternal(State[I], Fields[J], Item.Value, HasExpiry, Expiry).Free;
    end;
  end;
  Result := JsonStr('');
end;

function NewTarget: TObject;
begin
  Result := InMemoryDatabase.Create;
end;

end.
