unit solution;

{$mode objfpc}{$H+}
{$M+}

interface

uses
  SysUtils, Classes, minijson;

type
  TKeyState = class
  public
    Limit: Int64;
    Window: Int64;
    WindowId: Int64;
    HasWindow: Boolean;
    Used: Int64;
    constructor Create;
  end;

  Simulation = class
  private
    Keys: TStringList;
    function State(const Key: string): TKeyState;
    function UsedAt(Item: TKeyState; Timestamp: Int64; Persist: Boolean): Int64;
  public
    constructor Create;
    destructor Destroy; override;
  published
    function Allow(const Key: string; Timestamp: Int64): TJsonVal;
    function Configure(const Key: string; Limit, Window: Int64): TJsonVal;
    function Remaining(const Key: string; Timestamp: Int64): TJsonVal;
    function AllowWeighted(const Key: string; Cost, Timestamp: Int64): TJsonVal;
  end;

function NewTarget: TObject;

implementation

constructor TKeyState.Create;
begin
  inherited Create;
  Limit := 3;
  Window := 10;
  WindowId := 0;
  HasWindow := False;
  Used := 0;
end;

constructor Simulation.Create;
begin
  inherited Create;
  Keys := TStringList.Create;
  Keys.Sorted := True;
  Keys.Duplicates := dupIgnore;
end;

destructor Simulation.Destroy;
var
  N: Integer;
begin
  for N := 0 to Keys.Count - 1 do
    Keys.Objects[N].Free;
  Keys.Free;
  inherited Destroy;
end;

function Simulation.State(const Key: string): TKeyState;
var
  Idx: Integer;
begin
  Idx := Keys.IndexOf(Key);
  if Idx < 0 then
  begin
    Result := TKeyState.Create;
    Keys.AddObject(Key, Result);
  end
  else
    Result := TKeyState(Keys.Objects[Idx]);
end;

function Simulation.UsedAt(Item: TKeyState; Timestamp: Int64; Persist: Boolean): Int64;
var
  WindowId: Int64;
begin
  WindowId := Timestamp div Item.Window;
  if (not Item.HasWindow) or (WindowId <> Item.WindowId) then
  begin
    if Persist then
    begin
      Item.WindowId := WindowId;
      Item.HasWindow := True;
      Item.Used := 0;
    end;
    Exit(0);
  end;
  Result := Item.Used;
end;

function Simulation.Allow(const Key: string; Timestamp: Int64): TJsonVal;
begin
  Result := AllowWeighted(Key, 1, Timestamp);
end;

function Simulation.Configure(const Key: string; Limit, Window: Int64): TJsonVal;
var
  Item: TKeyState;
begin
  if (Limit <= 0) or (Window <= 0) then
    Exit(JsonStr('invalid_request'));
  Item := State(Key);
  Item.Limit := Limit;
  Item.Window := Window;
  Item.HasWindow := False;
  Item.Used := 0;
  Result := JsonStr('true');
end;

function Simulation.Remaining(const Key: string; Timestamp: Int64): TJsonVal;
var
  Item: TKeyState;
  Used: Int64;
begin
  Item := State(Key);
  Used := UsedAt(Item, Timestamp, False);
  Result := JsonStr(IntToStr(Item.Limit - Used));
end;

function Simulation.AllowWeighted(const Key: string; Cost, Timestamp: Int64): TJsonVal;
var
  Item: TKeyState;
begin
  if Cost <= 0 then
    Exit(JsonStr('invalid_request'));
  Item := State(Key);
  UsedAt(Item, Timestamp, True);
  if Item.Used + Cost > Item.Limit then
    Exit(JsonStr('false'));
  Item.Used := Item.Used + Cost;
  Result := JsonStr('true');
end;

function NewTarget: TObject;
begin
  Result := Simulation.Create;
end;

end.
