unit solution;

{$mode objfpc}{$H+}
{$M+}

interface

uses
  SysUtils, Classes, minijson;

type
  TBackend = class
  public
    BackendId: string;
    Health: Boolean;
    Weight: Int64;
    Inflight: Int64;
    constructor Create(const ABackendId: string);
  end;

  Simulation = class
  private
    Backends: TStringList;
    StickyMap: TStringList;
    Cursor: Int64;
    UseLeast: Boolean;
    function FindBackend(const BackendId: string): TBackend;
    procedure ResetCycle;
    function Pick: TBackend;
    function Take: string;
  public
    constructor Create;
    destructor Destroy; override;
  published
    function AddBackend(const BackendId: string): TJsonVal;
    function Route: TJsonVal;
    function SetHealth(const BackendId: string; Flag: Int64): TJsonVal;
    function SetWeight(const BackendId: string; Weight: Int64): TJsonVal;
    function Sticky(const ClientId: string): TJsonVal;
    function Done(const BackendId: string): TJsonVal;
  end;

function NewTarget: TObject;

implementation

constructor TBackend.Create(const ABackendId: string);
begin
  inherited Create;
  BackendId := ABackendId;
  Health := True;
  Weight := 1;
  Inflight := 0;
end;

constructor Simulation.Create;
begin
  inherited Create;
  Backends := TStringList.Create;
  Backends.Duplicates := dupError;
  StickyMap := TStringList.Create;
  StickyMap.NameValueSeparator := '=';
  Cursor := 0;
  UseLeast := False;
end;

destructor Simulation.Destroy;
var
  N: Integer;
begin
  for N := 0 to Backends.Count - 1 do
    Backends.Objects[N].Free;
  Backends.Free;
  StickyMap.Free;
  inherited Destroy;
end;

function Simulation.FindBackend(const BackendId: string): TBackend;
var
  Idx: Integer;
begin
  Idx := Backends.IndexOf(BackendId);
  if Idx < 0 then
    Result := nil
  else
    Result := TBackend(Backends.Objects[Idx]);
end;

procedure Simulation.ResetCycle;
var
  N: Integer;
begin
  Cursor := 0;
  UseLeast := False;
  for N := 0 to Backends.Count - 1 do
    TBackend(Backends.Objects[N]).Inflight := 0;
end;

function Simulation.Pick: TBackend;
var
  Healthy, Pool, Tickets: TList;
  N, I: Integer;
  Item: TBackend;
  Least: Int64;
begin
  Result := nil;
  Healthy := TList.Create;
  Pool := TList.Create;
  Tickets := TList.Create;
  try
    for N := 0 to Backends.Count - 1 do
    begin
      Item := TBackend(Backends.Objects[N]);
      if Item.Health then
        Healthy.Add(Item);
    end;
    if Healthy.Count = 0 then
      Exit;
    if UseLeast then
    begin
      Least := TBackend(Healthy[0]).Inflight;
      for N := 1 to Healthy.Count - 1 do
        if TBackend(Healthy[N]).Inflight < Least then
          Least := TBackend(Healthy[N]).Inflight;
      for N := 0 to Healthy.Count - 1 do
        if TBackend(Healthy[N]).Inflight = Least then
          Pool.Add(Healthy[N]);
    end
    else
      for N := 0 to Healthy.Count - 1 do
        Pool.Add(Healthy[N]);
    for N := 0 to Pool.Count - 1 do
    begin
      Item := TBackend(Pool[N]);
      for I := 1 to Item.Weight do
        Tickets.Add(Item);
    end;
    if Tickets.Count = 0 then
      Exit;
    Result := TBackend(Tickets[Cursor mod Tickets.Count]);
    Cursor := Cursor + 1;
  finally
    Healthy.Free;
    Pool.Free;
    Tickets.Free;
  end;
end;

function Simulation.Take: string;
var
  Item: TBackend;
begin
  Item := Pick;
  if Item = nil then
    Exit('');
  Item.Inflight := Item.Inflight + 1;
  Result := Item.BackendId;
end;

function Simulation.AddBackend(const BackendId: string): TJsonVal;
begin
  if FindBackend(BackendId) <> nil then
    Exit(JsonStr('false'));
  Backends.AddObject(BackendId, TBackend.Create(BackendId));
  Result := JsonStr('true');
end;

function Simulation.Route: TJsonVal;
begin
  Result := JsonStr(Take);
end;

function Simulation.SetHealth(const BackendId: string; Flag: Int64): TJsonVal;
var
  Item: TBackend;
begin
  Item := FindBackend(BackendId);
  if (Item = nil) or ((Flag <> 0) and (Flag <> 1)) then
    Exit(JsonStr('invalid_request'));
  Item.Health := Flag = 1;
  ResetCycle;
  Result := JsonStr('true');
end;

function Simulation.SetWeight(const BackendId: string; Weight: Int64): TJsonVal;
var
  Item: TBackend;
begin
  Item := FindBackend(BackendId);
  if (Item = nil) or (Weight <= 0) then
    Exit(JsonStr('invalid_request'));
  Item.Weight := Weight;
  ResetCycle;
  Result := JsonStr('true');
end;

function Simulation.Sticky(const ClientId: string): TJsonVal;
var
  Bound, Chosen: string;
  Item: TBackend;
begin
  Bound := StickyMap.Values[ClientId];
  if Bound <> '' then
  begin
    Item := FindBackend(Bound);
    if (Item <> nil) and Item.Health then
    begin
      Item.Inflight := Item.Inflight + 1;
      Exit(JsonStr(Item.BackendId));
    end;
  end;
  Chosen := Take;
  if Chosen <> '' then
    StickyMap.Values[ClientId] := Chosen;
  Result := JsonStr(Chosen);
end;

function Simulation.Done(const BackendId: string): TJsonVal;
var
  Item: TBackend;
begin
  Item := FindBackend(BackendId);
  if (Item = nil) or (Item.Inflight <= 0) then
    Exit(JsonStr('invalid_request'));
  Item.Inflight := Item.Inflight - 1;
  UseLeast := True;
  Result := JsonStr('true');
end;

function NewTarget: TObject;
begin
  Result := Simulation.Create;
end;

end.
