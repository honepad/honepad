{ Simulation stub. Fill methods from the problem spec.
  add_gpu(gpu_id, mem)
  submit_job(job_id, mem)
  status(job_id)
  assign()
  complete(job_id)
  cancel(job_id)
  set_priority(job_id, priority) }

unit solution;

{$mode objfpc}{$H+}
{$M+}

interface

uses
  SysUtils;

type
  Simulation = class
  end;

function NewTarget: TObject;

implementation

function NewTarget: TObject;
begin
  Result := Simulation.Create;
end;

end.
