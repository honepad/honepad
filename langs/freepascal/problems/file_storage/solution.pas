unit solution;

{$mode objfpc}{$H+}
{$M+}

interface

uses
  SysUtils, Classes, minijson;

type
  TStoredFile = class
  public
    Name: string;
    Size: Int64;
    Owner: string;
    constructor Create(const AName: string; ASize: Int64; const AOwner: string);
  end;

  TCap = class
  public
    Unlimited: Boolean;
    Value: Int64;
    constructor CreateUnlimited;
    constructor CreateValue(AValue: Int64);
  end;

  TSnapshot = class(TStringList)
  public
    constructor Create;
    destructor Destroy; override;
  end;

  TBoxInt = class
  public
    Value: Int64;
    constructor Create(AValue: Int64);
  end;

  Simulation = class
  private
    Files: TStringList;
    Capacity: TStringList;
    Backups: TStringList;
    function FindFile(const Name: string): TStoredFile;
    function FindCap(const UserId: string): TCap;
    function Used(const UserId: string): Int64;
    function Remaining(const UserId: string; out Left: Int64): Boolean;
  public
    constructor Create;
    destructor Destroy; override;
  published
    function AddFile(const Name: string; Size: Int64): TJsonVal;
    function CopyFile(const Source, Dest: string): TJsonVal;
    function GetFileSize(const Name: string): TJsonVal;
    function DeleteFile(const Name: string): TJsonVal;
    function GetNLargest(const Prefix: string; N: Int64): TJsonVal;
    function AddUser(const UserId: string; Cap: Int64): TJsonVal;
    function AddFileBy(const UserId, Name: string; Size: Int64): TJsonVal;
    function MergeUser(const UserId1, UserId2: string): TJsonVal;
    function BackupUser(const UserId: string): TJsonVal;
    function RestoreUser(const UserId: string): TJsonVal;
  end;

function NewTarget: TObject;

implementation

constructor TStoredFile.Create(const AName: string; ASize: Int64; const AOwner: string);
begin
  inherited Create;
  Name := AName;
  Size := ASize;
  Owner := AOwner;
end;

constructor TCap.CreateUnlimited;
begin
  inherited Create;
  Unlimited := True;
  Value := 0;
end;

constructor TCap.CreateValue(AValue: Int64);
begin
  inherited Create;
  Unlimited := False;
  Value := AValue;
end;

constructor TBoxInt.Create(AValue: Int64);
begin
  inherited Create;
  Value := AValue;
end;

constructor TSnapshot.Create;
begin
  inherited Create;
  Sorted := True;
  Duplicates := dupIgnore;
end;

destructor TSnapshot.Destroy;
var
  N: Integer;
begin
  for N := 0 to Count - 1 do
    Objects[N].Free;
  inherited Destroy;
end;

constructor Simulation.Create;
begin
  inherited Create;
  Files := TStringList.Create;
  Files.Sorted := True;
  Files.Duplicates := dupIgnore;
  Capacity := TStringList.Create;
  Capacity.Sorted := True;
  Capacity.Duplicates := dupIgnore;
  Backups := TStringList.Create;
  Backups.Sorted := True;
  Backups.Duplicates := dupIgnore;
  Capacity.AddObject('admin', TCap.CreateUnlimited);
end;

destructor Simulation.Destroy;
var
  N: Integer;
begin
  for N := 0 to Files.Count - 1 do
    Files.Objects[N].Free;
  Files.Free;
  for N := 0 to Capacity.Count - 1 do
    Capacity.Objects[N].Free;
  Capacity.Free;
  for N := 0 to Backups.Count - 1 do
    Backups.Objects[N].Free;
  Backups.Free;
  inherited Destroy;
end;

function Simulation.FindFile(const Name: string): TStoredFile;
var
  Idx: Integer;
begin
  Idx := Files.IndexOf(Name);
  if Idx < 0 then
    Result := nil
  else
    Result := TStoredFile(Files.Objects[Idx]);
end;

function Simulation.FindCap(const UserId: string): TCap;
var
  Idx: Integer;
begin
  Idx := Capacity.IndexOf(UserId);
  if Idx < 0 then
    Result := nil
  else
    Result := TCap(Capacity.Objects[Idx]);
end;

function Simulation.Used(const UserId: string): Int64;
var
  N: Integer;
  Item: TStoredFile;
begin
  Result := 0;
  for N := 0 to Files.Count - 1 do
  begin
    Item := TStoredFile(Files.Objects[N]);
    if Item.Owner = UserId then
      Result := Result + Item.Size;
  end;
end;

function Simulation.Remaining(const UserId: string; out Left: Int64): Boolean;
var
  Cap: TCap;
begin
  Cap := FindCap(UserId);
  if (Cap = nil) or Cap.Unlimited then
  begin
    Left := 0;
    Exit(False);
  end;
  Left := Cap.Value - Used(UserId);
  Result := True;
end;

function Simulation.AddFile(const Name: string; Size: Int64): TJsonVal;
begin
  if FindFile(Name) <> nil then
    Exit(JsonStr('false'));
  Files.AddObject(Name, TStoredFile.Create(Name, Size, 'admin'));
  Result := JsonStr('true');
end;

function Simulation.CopyFile(const Source, Dest: string): TJsonVal;
var
  Src, DestItem: TStoredFile;
  Owner: string;
  Extra, Left: Int64;
begin
  Src := FindFile(Source);
  if Src = nil then
    Exit(JsonStr(''));
  if Source = Dest then
    Exit(JsonStr(IntToStr(Src.Size)));
  DestItem := FindFile(Dest);
  if DestItem = nil then
  begin
    Owner := Src.Owner;
    Extra := Src.Size;
  end
  else
  begin
    Owner := DestItem.Owner;
    Extra := Src.Size - DestItem.Size;
  end;
  if Remaining(Owner, Left) and (Extra > Left) then
    Exit(JsonStr(''));
  if DestItem = nil then
    Files.AddObject(Dest, TStoredFile.Create(Dest, Src.Size, Owner))
  else
    DestItem.Size := Src.Size;
  Result := JsonStr(IntToStr(Src.Size));
end;

function Simulation.GetFileSize(const Name: string): TJsonVal;
var
  Item: TStoredFile;
begin
  Item := FindFile(Name);
  if Item = nil then
    Exit(JsonStr(''));
  Result := JsonStr(IntToStr(Item.Size));
end;

function Simulation.DeleteFile(const Name: string): TJsonVal;
var
  Idx: Integer;
  Item: TStoredFile;
begin
  Idx := Files.IndexOf(Name);
  if Idx < 0 then
    Exit(JsonStr(''));
  Item := TStoredFile(Files.Objects[Idx]);
  Result := JsonStr(IntToStr(Item.Size));
  Item.Free;
  Files.Delete(Idx);
end;

function Simulation.GetNLargest(const Prefix: string; N: Int64): TJsonVal;
var
  Matched: array of TStoredFile;
  I, J, Take: Integer;
  Item, Tmp: TStoredFile;
  Parts: string;
begin
  SetLength(Matched, 0);
  for I := 0 to Files.Count - 1 do
  begin
    Item := TStoredFile(Files.Objects[I]);
    if Copy(Item.Name, 1, Length(Prefix)) = Prefix then
    begin
      SetLength(Matched, Length(Matched) + 1);
      Matched[High(Matched)] := Item;
    end;
  end;
  for I := 0 to High(Matched) - 1 do
    for J := I + 1 to High(Matched) do
      if (Matched[J].Size > Matched[I].Size) or
        ((Matched[J].Size = Matched[I].Size) and (Matched[J].Name < Matched[I].Name)) then
      begin
        Tmp := Matched[I];
        Matched[I] := Matched[J];
        Matched[J] := Tmp;
      end;
  Take := Length(Matched);
  if N < Take then
    Take := Integer(N);
  Parts := '';
  for I := 0 to Take - 1 do
  begin
    if I > 0 then
      Parts := Parts + ', ';
    Parts := Parts + Matched[I].Name + '(' + IntToStr(Matched[I].Size) + ')';
  end;
  Result := JsonStr(Parts);
end;

function Simulation.AddUser(const UserId: string; Cap: Int64): TJsonVal;
begin
  if FindCap(UserId) <> nil then
    Exit(JsonStr('false'));
  Capacity.AddObject(UserId, TCap.CreateValue(Cap));
  Result := JsonStr('true');
end;

function Simulation.AddFileBy(const UserId, Name: string; Size: Int64): TJsonVal;
var
  Left: Int64;
  HasLeft: Boolean;
begin
  if (FindCap(UserId) = nil) or (FindFile(Name) <> nil) then
    Exit(JsonStr(''));
  HasLeft := Remaining(UserId, Left);
  if HasLeft and (Size > Left) then
    Exit(JsonStr(''));
  Files.AddObject(Name, TStoredFile.Create(Name, Size, UserId));
  if not Remaining(UserId, Left) then
    Exit(JsonStr(''));
  Result := JsonStr(IntToStr(Left));
end;

function Simulation.MergeUser(const UserId1, UserId2: string): TJsonVal;
var
  Cap1, Cap2: TCap;
  I, Idx: Integer;
  Item: TStoredFile;
  Left: Int64;
begin
  if UserId1 = UserId2 then
    Exit(JsonStr(''));
  Cap1 := FindCap(UserId1);
  Cap2 := FindCap(UserId2);
  if (Cap1 = nil) or (Cap2 = nil) then
    Exit(JsonStr(''));
  if Cap1.Unlimited or Cap2.Unlimited then
    Exit(JsonStr(''));
  Cap1.Value := Cap1.Value + Cap2.Value;
  for I := 0 to Files.Count - 1 do
  begin
    Item := TStoredFile(Files.Objects[I]);
    if Item.Owner = UserId2 then
      Item.Owner := UserId1;
  end;
  Idx := Capacity.IndexOf(UserId2);
  Capacity.Objects[Idx].Free;
  Capacity.Delete(Idx);
  Idx := Backups.IndexOf(UserId2);
  if Idx >= 0 then
  begin
    Backups.Objects[Idx].Free;
    Backups.Delete(Idx);
  end;
  if not Remaining(UserId1, Left) then
    Exit(JsonStr(''));
  Result := JsonStr(IntToStr(Left));
end;

function Simulation.BackupUser(const UserId: string): TJsonVal;
var
  Snap: TSnapshot;
  I, Idx: Integer;
  Item: TStoredFile;
begin
  if FindCap(UserId) = nil then
    Exit(JsonStr(''));
  Snap := TSnapshot.Create;
  for I := 0 to Files.Count - 1 do
  begin
    Item := TStoredFile(Files.Objects[I]);
    if Item.Owner = UserId then
      Snap.AddObject(Item.Name, TBoxInt.Create(Item.Size));
  end;
  Idx := Backups.IndexOf(UserId);
  if Idx >= 0 then
  begin
    Backups.Objects[Idx].Free;
    Backups.Objects[Idx] := Snap;
  end
  else
    Backups.AddObject(UserId, Snap);
  Result := JsonStr(IntToStr(Snap.Count));
end;

function Simulation.RestoreUser(const UserId: string): TJsonVal;
var
  I, Idx: Integer;
  Item: TStoredFile;
  Snap: TSnapshot;
  Left: Int64;
  Size: Int64;
  Restored: Integer;
begin
  if FindCap(UserId) = nil then
    Exit(JsonStr(''));
  I := 0;
  while I < Files.Count do
  begin
    Item := TStoredFile(Files.Objects[I]);
    if Item.Owner = UserId then
    begin
      Item.Free;
      Files.Delete(I);
    end
    else
      Inc(I);
  end;
  Idx := Backups.IndexOf(UserId);
  if Idx < 0 then
    Exit(JsonStr('0'));
  Snap := TSnapshot(Backups.Objects[Idx]);
  Restored := 0;
  for I := 0 to Snap.Count - 1 do
  begin
    if FindFile(Snap[I]) <> nil then
      Continue;
    Size := TBoxInt(Snap.Objects[I]).Value;
    if Remaining(UserId, Left) and (Size > Left) then
      Continue;
    Files.AddObject(Snap[I], TStoredFile.Create(Snap[I], Size, UserId));
    Inc(Restored);
  end;
  Result := JsonStr(IntToStr(Restored));
end;

function NewTarget: TObject;
begin
  Result := Simulation.Create;
end;

end.
