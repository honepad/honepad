{ Simulation stub. Fill methods from the problem spec.
  add_backend(backend_id)
  route()
  set_health(backend_id, flag)
  set_weight(backend_id, weight)
  sticky(client_id)
  done(backend_id) }

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
