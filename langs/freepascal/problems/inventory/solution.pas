unit solution;

{$mode objfpc}{$H+}
{$M+}

interface

uses
  SysUtils, Classes, minijson;

type
  TItem = class
  public
    Sku: string;
    Name: string;
    Qty: Int64;
    Reserved: Int64;
    constructor Create(const ASku, AName: string);
  end;

  Simulation = class
  private
    Items: TStringList;
    function FindItem(const Sku: string): TItem;
  public
    constructor Create;
    destructor Destroy; override;
  published
    function CreateItem(const Sku, Name: string): TJsonVal;
    function Stock(const Sku: string; Delta: Int64): TJsonVal;
    function GetQty(const Sku: string): TJsonVal;
    function ListLow(Threshold: Int64): TJsonVal;
    function Reserve(const Sku: string; N: Int64): TJsonVal;
    function Release(const Sku: string; N: Int64): TJsonVal;
    function Ship(const Sku: string; N: Int64): TJsonVal;
  end;

function NewTarget: TObject;

implementation

constructor TItem.Create(const ASku, AName: string);
begin
  inherited Create;
  Sku := ASku;
  Name := AName;
  Qty := 0;
  Reserved := 0;
end;

constructor Simulation.Create;
begin
  inherited Create;
  Items := TStringList.Create;
  Items.Sorted := True;
  Items.Duplicates := dupIgnore;
end;

destructor Simulation.Destroy;
var
  N: Integer;
begin
  for N := 0 to Items.Count - 1 do
    Items.Objects[N].Free;
  Items.Free;
  inherited Destroy;
end;

function Simulation.FindItem(const Sku: string): TItem;
var
  Idx: Integer;
begin
  Idx := Items.IndexOf(Sku);
  if Idx < 0 then
    Result := nil
  else
    Result := TItem(Items.Objects[Idx]);
end;

function Simulation.CreateItem(const Sku, Name: string): TJsonVal;
begin
  if FindItem(Sku) <> nil then
    Exit(JsonStr('false'));
  Items.AddObject(Sku, TItem.Create(Sku, Name));
  Result := JsonStr('true');
end;

function Simulation.Stock(const Sku: string; Delta: Int64): TJsonVal;
var
  Item: TItem;
  Nxt: Int64;
begin
  Item := FindItem(Sku);
  if Item = nil then
    Exit(JsonStr(''));
  Nxt := Item.Qty + Delta;
  if Nxt < Item.Reserved then
    Exit(JsonStr('invalid_request'));
  Item.Qty := Nxt;
  Result := JsonStr(IntToStr(Item.Qty));
end;

function Simulation.GetQty(const Sku: string): TJsonVal;
var
  Item: TItem;
begin
  Item := FindItem(Sku);
  if Item = nil then
    Exit(JsonStr(''));
  Result := JsonStr(IntToStr(Item.Qty));
end;

function Simulation.ListLow(Threshold: Int64): TJsonVal;
var
  Matched: array of TItem;
  Count, I, J: Integer;
  Item, Tmp: TItem;
  Parts: string;
begin
  Count := 0;
  SetLength(Matched, Items.Count);
  for I := 0 to Items.Count - 1 do
  begin
    Item := TItem(Items.Objects[I]);
    if Item.Qty <= Threshold then
    begin
      Matched[Count] := Item;
      Inc(Count);
    end;
  end;
  for I := 0 to Count - 2 do
    for J := I + 1 to Count - 1 do
      if (Matched[J].Qty < Matched[I].Qty) or
        ((Matched[J].Qty = Matched[I].Qty) and (Matched[J].Sku < Matched[I].Sku)) then
      begin
        Tmp := Matched[I];
        Matched[I] := Matched[J];
        Matched[J] := Tmp;
      end;
  Parts := '';
  for I := 0 to Count - 1 do
  begin
    if I > 0 then
      Parts := Parts + ', ';
    Parts := Parts + Matched[I].Sku + '(' + IntToStr(Matched[I].Qty) + ')';
  end;
  Result := JsonStr(Parts);
end;

function Simulation.Reserve(const Sku: string; N: Int64): TJsonVal;
var
  Item: TItem;
begin
  Item := FindItem(Sku);
  if (Item = nil) or (N <= 0) or (Item.Reserved + N > Item.Qty) then
    Exit(JsonStr('invalid_request'));
  Item.Reserved := Item.Reserved + N;
  Result := JsonStr('true');
end;

function Simulation.Release(const Sku: string; N: Int64): TJsonVal;
var
  Item: TItem;
begin
  Item := FindItem(Sku);
  if (Item = nil) or (N <= 0) or (N > Item.Reserved) then
    Exit(JsonStr('invalid_request'));
  Item.Reserved := Item.Reserved - N;
  Result := JsonStr('true');
end;

function Simulation.Ship(const Sku: string; N: Int64): TJsonVal;
var
  Item: TItem;
begin
  Item := FindItem(Sku);
  if (Item = nil) or (N <= 0) or (N > Item.Reserved) then
    Exit(JsonStr('invalid_request'));
  Item.Reserved := Item.Reserved - N;
  Item.Qty := Item.Qty - N;
  Result := JsonStr('true');
end;

function NewTarget: TObject;
begin
  Result := Simulation.Create;
end;

end.
