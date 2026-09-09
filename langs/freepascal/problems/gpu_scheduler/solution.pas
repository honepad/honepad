unit solution;

{$mode objfpc}{$H+}
{$M+}

interface

uses
  SysUtils, Classes, minijson;

type
  TGpu = class
  public
    GpuId: string;
    Mem: Int64;
    JobId: string;
    constructor Create(const AGpuId: string; AMem: Int64);
  end;

  TJob = class
  public
    JobId: string;
    Mem: Int64;
    Seq: Int64;
    Priority: Int64;
    State: string;
    GpuId: string;
    constructor Create(const AJobId: string; AMem, ASeq: Int64);
  end;

  Simulation = class
  private
    Gpus: TStringList;
    Jobs: TStringList;
    NextSeq: Int64;
    function FindGpu(const GpuId: string): TGpu;
    function FindJob(const JobId: string): TJob;
    procedure Place(Job: TJob; Gpu: TGpu);
    procedure FreeGpu(Job: TJob);
    procedure RemoveJob(const JobId: string);
  public
    constructor Create;
    destructor Destroy; override;
  published
    function AddGpu(const GpuId: string; Mem: Int64): TJsonVal;
    function SubmitJob(const JobId: string; Mem: Int64): TJsonVal;
    function Status(const JobId: string): TJsonVal;
    function Assign: TJsonVal;
    function Complete(const JobId: string): TJsonVal;
    function Cancel(const JobId: string): TJsonVal;
    function SetPriority(const JobId: string; Priority: Int64): TJsonVal;
  end;

function NewTarget: TObject;

implementation

constructor TGpu.Create(const AGpuId: string; AMem: Int64);
begin
  inherited Create;
  GpuId := AGpuId;
  Mem := AMem;
  JobId := '';
end;

constructor TJob.Create(const AJobId: string; AMem, ASeq: Int64);
begin
  inherited Create;
  JobId := AJobId;
  Mem := AMem;
  Seq := ASeq;
  Priority := 0;
  State := 'queued';
  GpuId := '';
end;

constructor Simulation.Create;
begin
  inherited Create;
  Gpus := TStringList.Create;
  Gpus.Duplicates := dupError;
  Jobs := TStringList.Create;
  Jobs.Sorted := True;
  Jobs.Duplicates := dupError;
  NextSeq := 0;
end;

destructor Simulation.Destroy;
var
  N: Integer;
begin
  for N := 0 to Gpus.Count - 1 do
    Gpus.Objects[N].Free;
  for N := 0 to Jobs.Count - 1 do
    Jobs.Objects[N].Free;
  Gpus.Free;
  Jobs.Free;
  inherited Destroy;
end;

function Simulation.FindGpu(const GpuId: string): TGpu;
var
  Idx: Integer;
begin
  Idx := Gpus.IndexOf(GpuId);
  if Idx < 0 then
    Result := nil
  else
    Result := TGpu(Gpus.Objects[Idx]);
end;

function Simulation.FindJob(const JobId: string): TJob;
var
  Idx: Integer;
begin
  Idx := Jobs.IndexOf(JobId);
  if Idx < 0 then
    Result := nil
  else
    Result := TJob(Jobs.Objects[Idx]);
end;

procedure Simulation.Place(Job: TJob; Gpu: TGpu);
begin
  Job.State := 'running';
  Job.GpuId := Gpu.GpuId;
  Gpu.JobId := Job.JobId;
end;

procedure Simulation.FreeGpu(Job: TJob);
var
  Gpu: TGpu;
begin
  if Job.GpuId = '' then
    Exit;
  Gpu := FindGpu(Job.GpuId);
  if Gpu <> nil then
    Gpu.JobId := '';
end;

procedure Simulation.RemoveJob(const JobId: string);
var
  Idx: Integer;
begin
  Idx := Jobs.IndexOf(JobId);
  if Idx < 0 then
    Exit;
  Jobs.Objects[Idx].Free;
  Jobs.Delete(Idx);
end;

function Simulation.AddGpu(const GpuId: string; Mem: Int64): TJsonVal;
begin
  if Mem <= 0 then
    Exit(JsonStr('invalid_request'));
  if FindGpu(GpuId) <> nil then
    Exit(JsonStr('false'));
  Gpus.AddObject(GpuId, TGpu.Create(GpuId, Mem));
  Result := JsonStr('true');
end;

function Simulation.SubmitJob(const JobId: string; Mem: Int64): TJsonVal;
begin
  if Mem <= 0 then
    Exit(JsonStr('invalid_request'));
  if FindJob(JobId) <> nil then
    Exit(JsonStr('false'));
  Jobs.AddObject(JobId, TJob.Create(JobId, Mem, NextSeq));
  NextSeq := NextSeq + 1;
  Result := JsonStr('true');
end;

function Simulation.Status(const JobId: string): TJsonVal;
var
  Job: TJob;
begin
  Job := FindJob(JobId);
  if Job = nil then
    Exit(JsonStr(''));
  Result := JsonStr(Job.State);
end;

function Simulation.Assign: TJsonVal;
var
  Queued: TList;
  I, G: Integer;
  Job: TJob;
  Gpu: TGpu;
begin
  Queued := TList.Create;
  try
    for I := 0 to Jobs.Count - 1 do
    begin
      Job := TJob(Jobs.Objects[I]);
      if Job.State = 'queued' then
        Queued.Add(Job);
    end;
    for I := 0 to Queued.Count - 2 do
      for G := I + 1 to Queued.Count - 1 do
        if (TJob(Queued[G]).Priority > TJob(Queued[I]).Priority) or
          ((TJob(Queued[G]).Priority = TJob(Queued[I]).Priority) and
           (TJob(Queued[G]).Seq < TJob(Queued[I]).Seq)) then
          Queued.Exchange(I, G);
    for I := 0 to Queued.Count - 1 do
    begin
      Job := TJob(Queued[I]);
      for G := 0 to Gpus.Count - 1 do
      begin
        Gpu := TGpu(Gpus.Objects[G]);
        if (Gpu.JobId = '') and (Gpu.Mem >= Job.Mem) then
        begin
          Place(Job, Gpu);
          Exit(JsonStr(Job.JobId));
        end;
      end;
    end;
    Result := JsonStr('');
  finally
    Queued.Free;
  end;
end;

function Simulation.Complete(const JobId: string): TJsonVal;
var
  Job: TJob;
begin
  Job := FindJob(JobId);
  if (Job = nil) or (Job.State <> 'running') or (Job.GpuId = '') then
    Exit(JsonStr('invalid_request'));
  FreeGpu(Job);
  Job.GpuId := '';
  Job.State := 'done';
  Result := JsonStr('true');
end;

function Simulation.Cancel(const JobId: string): TJsonVal;
var
  Job: TJob;
  Running: Boolean;
  Ignored: TJsonVal;
begin
  Job := FindJob(JobId);
  if (Job = nil) or (Job.State = 'done') then
    Exit(JsonStr('invalid_request'));
  Running := Job.State = 'running';
  if Running then
    FreeGpu(Job);
  RemoveJob(JobId);
  if Running then
  begin
    Ignored := Assign;
    Ignored.Free;
  end;
  Result := JsonStr('true');
end;

function Simulation.SetPriority(const JobId: string; Priority: Int64): TJsonVal;
var
  Job: TJob;
begin
  Job := FindJob(JobId);
  if (Job = nil) or (Job.State <> 'queued') then
    Exit(JsonStr('invalid_request'));
  Job.Priority := Priority;
  Result := JsonStr('true');
end;

function NewTarget: TObject;
begin
  Result := Simulation.Create;
end;

end.
