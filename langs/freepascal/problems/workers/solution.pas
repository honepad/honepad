unit solution;

{$mode objfpc}{$H+}
{$M+}

interface

uses
  SysUtils, Classes, minijson;

type
  TWorkSession = record
    StartTs: Int64;
    EndTs: Int64;
    Rate: Int64;
    Position: string;
  end;

  TPromo = record
    Position: string;
    Compensation: Int64;
    StartTimestamp: Int64;
  end;

  TWorker = class
  public
    WorkerId: string;
    Position: string;
    Compensation: Int64;
    InOffice: Boolean;
    EnteredAt: Int64;
    Finished: array of TWorkSession;
    HasPromo: Boolean;
    Promo: TPromo;
    constructor Create(const AId, APosition: string; ACompensation: Int64);
    function TotalTime: Int64;
    function PositionTime(const Pos: string): Int64;
    procedure ApplyPromoOnEnter(Timestamp: Int64);
  end;

  Simulation = class
  private
    Workers: TStringList;
    function FindWorker(const WorkerId: string): TWorker;
  public
    constructor Create;
    destructor Destroy; override;
  published
    function AddWorker(const WorkerId, Position: string; Compensation: Int64): TJsonVal;
    function Register(const WorkerId: string; Timestamp: Int64): TJsonVal;
    function Get(const WorkerId: string): TJsonVal;
    function TopNWorkers(N: Int64; const Position: string): TJsonVal;
    function Promote(const WorkerId, NewPosition: string; NewCompensation,
      StartTimestamp: Int64): TJsonVal;
    function CalcSalary(const WorkerId: string; StartTimestamp, EndTimestamp: Int64): TJsonVal;
  end;

function NewTarget: TObject;

implementation

constructor TWorker.Create(const AId, APosition: string; ACompensation: Int64);
begin
  inherited Create;
  WorkerId := AId;
  Position := APosition;
  Compensation := ACompensation;
end;

function TWorker.TotalTime: Int64;
var
  N: Integer;
begin
  Result := 0;
  for N := 0 to High(Finished) do
    Result := Result + (Finished[N].EndTs - Finished[N].StartTs);
end;

function TWorker.PositionTime(const Pos: string): Int64;
var
  N: Integer;
begin
  Result := 0;
  for N := 0 to High(Finished) do
    if Finished[N].Position = Pos then
      Result := Result + (Finished[N].EndTs - Finished[N].StartTs);
end;

procedure TWorker.ApplyPromoOnEnter(Timestamp: Int64);
begin
  if not HasPromo then
    Exit;
  if Timestamp >= Promo.StartTimestamp then
  begin
    Position := Promo.Position;
    Compensation := Promo.Compensation;
    HasPromo := False;
  end;
end;

constructor Simulation.Create;
begin
  inherited Create;
  Workers := TStringList.Create;
  Workers.Sorted := True;
  Workers.Duplicates := dupIgnore;
end;

destructor Simulation.Destroy;
var
  N: Integer;
begin
  for N := 0 to Workers.Count - 1 do
    Workers.Objects[N].Free;
  Workers.Free;
  inherited Destroy;
end;

function Simulation.FindWorker(const WorkerId: string): TWorker;
var
  Idx: Integer;
begin
  Idx := Workers.IndexOf(WorkerId);
  if Idx < 0 then
    Result := nil
  else
    Result := TWorker(Workers.Objects[Idx]);
end;

function Simulation.AddWorker(const WorkerId, Position: string; Compensation: Int64): TJsonVal;
begin
  if FindWorker(WorkerId) <> nil then
    Exit(JsonStr('false'));
  Workers.AddObject(WorkerId, TWorker.Create(WorkerId, Position, Compensation));
  Result := JsonStr('true');
end;

function Simulation.Register(const WorkerId: string; Timestamp: Int64): TJsonVal;
var
  Worker: TWorker;
  Session: TWorkSession;
begin
  Worker := FindWorker(WorkerId);
  if Worker = nil then
    Exit(JsonStr('invalid_request'));
  if Worker.InOffice then
  begin
    Session.StartTs := Worker.EnteredAt;
    Session.EndTs := Timestamp;
    Session.Rate := Worker.Compensation;
    Session.Position := Worker.Position;
    SetLength(Worker.Finished, Length(Worker.Finished) + 1);
    Worker.Finished[High(Worker.Finished)] := Session;
    Worker.InOffice := False;
    Worker.EnteredAt := 0;
    Exit(JsonStr('registered'));
  end;
  Worker.ApplyPromoOnEnter(Timestamp);
  Worker.InOffice := True;
  Worker.EnteredAt := Timestamp;
  Result := JsonStr('registered');
end;

function Simulation.Get(const WorkerId: string): TJsonVal;
var
  Worker: TWorker;
begin
  Worker := FindWorker(WorkerId);
  if Worker = nil then
    Exit(JsonStr(''));
  Result := JsonStr(IntToStr(Worker.TotalTime));
end;

function Simulation.TopNWorkers(N: Int64; const Position: string): TJsonVal;
var
  Matched: array of TWorker;
  I, J, Take: Integer;
  Worker, Tmp: TWorker;
  Parts: string;
  ATime, BTime: Int64;
begin
  SetLength(Matched, 0);
  for I := 0 to Workers.Count - 1 do
  begin
    Worker := TWorker(Workers.Objects[I]);
    if Worker.Position = Position then
    begin
      SetLength(Matched, Length(Matched) + 1);
      Matched[High(Matched)] := Worker;
    end;
  end;
  for I := 0 to High(Matched) - 1 do
    for J := I + 1 to High(Matched) do
    begin
      ATime := Matched[I].PositionTime(Position);
      BTime := Matched[J].PositionTime(Position);
      if (BTime > ATime) or ((BTime = ATime) and (Matched[J].WorkerId < Matched[I].WorkerId)) then
      begin
        Tmp := Matched[I];
        Matched[I] := Matched[J];
        Matched[J] := Tmp;
      end;
    end;
  Take := Length(Matched);
  if N < Take then
    Take := Integer(N);
  Parts := '';
  for I := 0 to Take - 1 do
  begin
    if I > 0 then
      Parts := Parts + ', ';
    Parts := Parts + Matched[I].WorkerId + '(' +
      IntToStr(Matched[I].PositionTime(Position)) + ')';
  end;
  Result := JsonStr(Parts);
end;

function Simulation.Promote(const WorkerId, NewPosition: string; NewCompensation,
  StartTimestamp: Int64): TJsonVal;
var
  Worker: TWorker;
begin
  Worker := FindWorker(WorkerId);
  if Worker = nil then
    Exit(JsonStr('invalid_request'));
  if Worker.HasPromo then
    Exit(JsonStr('invalid_request'));
  Worker.Promo.Position := NewPosition;
  Worker.Promo.Compensation := NewCompensation;
  Worker.Promo.StartTimestamp := StartTimestamp;
  Worker.HasPromo := True;
  Result := JsonStr('success');
end;

function Simulation.CalcSalary(const WorkerId: string; StartTimestamp, EndTimestamp: Int64): TJsonVal;
var
  Worker: TWorker;
  N: Integer;
  Lo, Hi, Total: Int64;
begin
  Worker := FindWorker(WorkerId);
  if Worker = nil then
    Exit(JsonStr(''));
  Total := 0;
  for N := 0 to High(Worker.Finished) do
  begin
    Lo := Worker.Finished[N].StartTs;
    if StartTimestamp > Lo then
      Lo := StartTimestamp;
    Hi := Worker.Finished[N].EndTs;
    if EndTimestamp < Hi then
      Hi := EndTimestamp;
    if Hi > Lo then
      Total := Total + (Hi - Lo) * Worker.Finished[N].Rate;
  end;
  Result := JsonStr(IntToStr(Total));
end;

function NewTarget: TObject;
begin
  Result := Simulation.Create;
end;

end.
