unit solution;

{$mode objfpc}{$H+}
{$M+}

interface

uses
  SysUtils, Classes, minijson;

type
  TSnap = class
  public
    Buf: string;
    Pos: Int64;
    constructor Create(const ABuf: string; APos: Int64);
  end;

  Simulation = class
  private
    Buf: string;
    Pos: Int64;
    UndoStack: TList;
    RedoStack: TList;
    SelStart: Int64;
    SelEnd: Int64;
    Clip: string;
    procedure Push;
    procedure ClearList(List: TList);
  public
    constructor Create;
    destructor Destroy; override;
  published
    function Insert(At: Int64; const Text: string): TJsonVal;
    function Erase(At, N: Int64): TJsonVal;
    function GetText: TJsonVal;
    function Length: TJsonVal;
    function Move(At: Int64): TJsonVal;
    function TypeText(const Text: string): TJsonVal;
    function Cursor: TJsonVal;
    function Undo: TJsonVal;
    function Redo: TJsonVal;
    function Select(Start, EndPos: Int64): TJsonVal;
    function Cut: TJsonVal;
    function CopySel: TJsonVal;
    function Paste: TJsonVal;
  end;

function NewTarget: TObject;

implementation

constructor TSnap.Create(const ABuf: string; APos: Int64);
begin
  inherited Create;
  Buf := ABuf;
  Pos := APos;
end;

constructor Simulation.Create;
begin
  inherited Create;
  Buf := '';
  Pos := 0;
  UndoStack := TList.Create;
  RedoStack := TList.Create;
  SelStart := -1;
  SelEnd := -1;
  Clip := '';
end;

procedure Simulation.ClearList(List: TList);
var
  I: Integer;
begin
  for I := 0 to List.Count - 1 do
    TObject(List[I]).Free;
  List.Clear;
end;

destructor Simulation.Destroy;
begin
  ClearList(UndoStack);
  ClearList(RedoStack);
  UndoStack.Free;
  RedoStack.Free;
  inherited Destroy;
end;

procedure Simulation.Push;
begin
  UndoStack.Add(TSnap.Create(Buf, Pos));
  ClearList(RedoStack);
  SelStart := -1;
  SelEnd := -1;
end;

function Simulation.Insert(At: Int64; const Text: string): TJsonVal;
begin
  if (At < 0) or (At > System.Length(Buf)) then
    Exit(JsonStr('invalid_request'));
  Push;
  Buf := Copy(Buf, 1, At) + Text + Copy(Buf, At + 1, MaxInt);
  Result := JsonStr(IntToStr(System.Length(Buf)));
end;

function Simulation.Erase(At, N: Int64): TJsonVal;
var
  Deleted: string;
begin
  if (N <= 0) or (At < 0) or (At + N > System.Length(Buf)) then
    Exit(JsonStr('invalid_request'));
  Push;
  Deleted := Copy(Buf, At + 1, N);
  Buf := Copy(Buf, 1, At) + Copy(Buf, At + N + 1, MaxInt);
  if Pos > System.Length(Buf) then
    Pos := System.Length(Buf);
  Result := JsonStr(Deleted);
end;

function Simulation.GetText: TJsonVal;
begin
  Result := JsonStr(Buf);
end;

function Simulation.Length: TJsonVal;
begin
  Result := JsonStr(IntToStr(System.Length(Buf)));
end;

function Simulation.Move(At: Int64): TJsonVal;
begin
  if (At < 0) or (At > System.Length(Buf)) then
    Exit(JsonStr('invalid_request'));
  Pos := At;
  Result := JsonStr('true');
end;

function Simulation.TypeText(const Text: string): TJsonVal;
var
  At: Int64;
begin
  Push;
  At := Pos;
  Buf := Copy(Buf, 1, At) + Text + Copy(Buf, At + 1, MaxInt);
  Pos := At + System.Length(Text);
  Result := JsonStr(IntToStr(System.Length(Buf)));
end;

function Simulation.Cursor: TJsonVal;
begin
  Result := JsonStr(IntToStr(Pos));
end;

function Simulation.Undo: TJsonVal;
var
  Snap: TSnap;
begin
  if UndoStack.Count = 0 then
    Exit(JsonStr('false'));
  RedoStack.Add(TSnap.Create(Buf, Pos));
  Snap := TSnap(UndoStack[UndoStack.Count - 1]);
  UndoStack.Delete(UndoStack.Count - 1);
  Buf := Snap.Buf;
  Pos := Snap.Pos;
  Snap.Free;
  SelStart := -1;
  SelEnd := -1;
  Result := JsonStr('true');
end;

function Simulation.Redo: TJsonVal;
var
  Snap: TSnap;
begin
  if RedoStack.Count = 0 then
    Exit(JsonStr('false'));
  UndoStack.Add(TSnap.Create(Buf, Pos));
  Snap := TSnap(RedoStack[RedoStack.Count - 1]);
  RedoStack.Delete(RedoStack.Count - 1);
  Buf := Snap.Buf;
  Pos := Snap.Pos;
  Snap.Free;
  SelStart := -1;
  SelEnd := -1;
  Result := JsonStr('true');
end;

function Simulation.Select(Start, EndPos: Int64): TJsonVal;
begin
  if (Start < 0) or (EndPos < 0) or (Start > EndPos) or (EndPos > System.Length(Buf)) then
    Exit(JsonStr('invalid_request'));
  SelStart := Start;
  SelEnd := EndPos;
  Result := JsonStr('true');
end;

function Simulation.Cut: TJsonVal;
var
  Text: string;
begin
  if (SelStart < 0) or (SelStart = SelEnd) then
    Exit(JsonStr('invalid_request'));
  Text := Copy(Buf, SelStart + 1, SelEnd - SelStart);
  Buf := Copy(Buf, 1, SelStart) + Copy(Buf, SelEnd + 1, MaxInt);
  Clip := Text;
  Pos := SelStart;
  SelStart := -1;
  SelEnd := -1;
  Result := JsonStr(Text);
end;

function Simulation.CopySel: TJsonVal;
begin
  if (SelStart < 0) or (SelStart = SelEnd) then
    Exit(JsonStr('invalid_request'));
  Clip := Copy(Buf, SelStart + 1, SelEnd - SelStart);
  Result := JsonStr(Clip);
end;

function Simulation.Paste: TJsonVal;
var
  At: Int64;
begin
  if Clip = '' then
    Exit(JsonStr('invalid_request'));
  At := Pos;
  Buf := Copy(Buf, 1, At) + Clip + Copy(Buf, At + 1, MaxInt);
  Pos := At + System.Length(Clip);
  Result := JsonStr(IntToStr(System.Length(Buf)));
end;

function NewTarget: TObject;
begin
  Result := Simulation.Create;
end;

end.
