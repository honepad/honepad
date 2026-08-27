unit minijson;

{$mode objfpc}{$H+}

interface

uses
  SysUtils;

type
  TJsonKind = (jkNull, jkBool, jkInt, jkStr, jkArr, jkObj);

  TJsonVal = class
  public
    Kind: TJsonKind;
    B: Boolean;
    I: Int64;
    S: string;
    Arr: array of TJsonVal;
    Keys: array of string;
    Vals: array of TJsonVal;
    destructor Destroy; override;
    procedure ArrAdd(V: TJsonVal);
    procedure ObjPut(const Key: string; V: TJsonVal);
    function ObjGet(const Key: string): TJsonVal;
  end;

function JsonNull: TJsonVal;
function JsonBool(V: Boolean): TJsonVal;
function JsonInt(V: Int64): TJsonVal;
function JsonStr(const V: string): TJsonVal;
function JsonArr: TJsonVal;
function JsonObj: TJsonVal;
function JsonStrs(const Items: array of string): TJsonVal;
function JsonParse(const Text: string): TJsonVal;
function JsonStringify(V: TJsonVal): string;
function JsonClone(V: TJsonVal): TJsonVal;
function ArgInt(Args: TJsonVal; Index: Integer): Int64;
function ArgStr(Args: TJsonVal; Index: Integer): string;
function ArgCount(Args: TJsonVal): Integer;

implementation

destructor TJsonVal.Destroy;
var
  N: Integer;
begin
  for N := 0 to High(Arr) do
    Arr[N].Free;
  for N := 0 to High(Vals) do
    Vals[N].Free;
  inherited Destroy;
end;

procedure TJsonVal.ArrAdd(V: TJsonVal);
begin
  SetLength(Arr, Length(Arr) + 1);
  Arr[High(Arr)] := V;
end;

procedure TJsonVal.ObjPut(const Key: string; V: TJsonVal);
begin
  SetLength(Keys, Length(Keys) + 1);
  SetLength(Vals, Length(Vals) + 1);
  Keys[High(Keys)] := Key;
  Vals[High(Vals)] := V;
end;

function TJsonVal.ObjGet(const Key: string): TJsonVal;
var
  N: Integer;
begin
  Result := nil;
  for N := 0 to High(Keys) do
    if Keys[N] = Key then
      Exit(Vals[N]);
end;

function JsonNull: TJsonVal;
begin
  Result := TJsonVal.Create;
  Result.Kind := jkNull;
end;

function JsonBool(V: Boolean): TJsonVal;
begin
  Result := TJsonVal.Create;
  Result.Kind := jkBool;
  Result.B := V;
end;

function JsonInt(V: Int64): TJsonVal;
begin
  Result := TJsonVal.Create;
  Result.Kind := jkInt;
  Result.I := V;
end;

function JsonStr(const V: string): TJsonVal;
begin
  Result := TJsonVal.Create;
  Result.Kind := jkStr;
  Result.S := V;
end;

function JsonArr: TJsonVal;
begin
  Result := TJsonVal.Create;
  Result.Kind := jkArr;
end;

function JsonObj: TJsonVal;
begin
  Result := TJsonVal.Create;
  Result.Kind := jkObj;
end;

function JsonStrs(const Items: array of string): TJsonVal;
var
  N: Integer;
begin
  Result := JsonArr;
  for N := 0 to High(Items) do
    Result.ArrAdd(JsonStr(Items[N]));
end;

function JsonClone(V: TJsonVal): TJsonVal;
var
  N: Integer;
begin
  if V = nil then
    Exit(JsonNull);
  case V.Kind of
    jkNull:
      Result := JsonNull;
    jkBool:
      Result := JsonBool(V.B);
    jkInt:
      Result := JsonInt(V.I);
    jkStr:
      Result := JsonStr(V.S);
    jkArr:
    begin
      Result := JsonArr;
      for N := 0 to High(V.Arr) do
        Result.ArrAdd(JsonClone(V.Arr[N]));
    end;
    jkObj:
    begin
      Result := JsonObj;
      for N := 0 to High(V.Keys) do
        Result.ObjPut(V.Keys[N], JsonClone(V.Vals[N]));
    end;
  end;
end;

function Escape(const Text: string): string;
var
  N: Integer;
  Ch: Char;
begin
  Result := '';
  for N := 1 to Length(Text) do
  begin
    Ch := Text[N];
    case Ch of
      '"':
        Result := Result + '\"';
      '\':
        Result := Result + '\\';
      #8:
        Result := Result + '\b';
      #12:
        Result := Result + '\f';
      #10:
        Result := Result + '\n';
      #13:
        Result := Result + '\r';
      #9:
        Result := Result + '\t';
      else
        if Ord(Ch) < 32 then
          Result := Result + '\u00' + IntToHex(Ord(Ch), 2)
        else
          Result := Result + Ch;
    end;
  end;
end;

function JsonStringify(V: TJsonVal): string;
var
  N: Integer;
begin
  if V = nil then
    Exit('null');
  case V.Kind of
    jkNull:
      Result := 'null';
    jkBool:
      if V.B then
        Result := 'true'
      else
        Result := 'false';
    jkInt:
      Result := IntToStr(V.I);
    jkStr:
      Result := '"' + Escape(V.S) + '"';
    jkArr:
    begin
      Result := '[';
      for N := 0 to High(V.Arr) do
      begin
        if N > 0 then
          Result := Result + ',';
        Result := Result + JsonStringify(V.Arr[N]);
      end;
      Result := Result + ']';
    end;
    jkObj:
    begin
      Result := '{';
      for N := 0 to High(V.Keys) do
      begin
        if N > 0 then
          Result := Result + ',';
        Result := Result + '"' + Escape(V.Keys[N]) + '":' + JsonStringify(V.Vals[N]);
      end;
      Result := Result + '}';
    end;
  end;
end;

type
  TParser = class
    Text: string;
    Pos: Integer;
    procedure SkipWs;
    function Peek: Char;
    function Nextc: Char;
    function Expect(Ch: Char): Boolean;
    function ParseLiteral(const Lit: string): Boolean;
    function ParseString: string;
    function ParseNumber: TJsonVal;
    function ParseValue: TJsonVal;
    function ParseArray: TJsonVal;
    function ParseObject: TJsonVal;
    function Done: Boolean;
  end;

procedure TParser.SkipWs;
begin
  while Pos <= Length(Text) do
    case Text[Pos] of
      ' ', #9, #10, #13:
        Inc(Pos);
      else
        Break;
    end;
end;

function TParser.Done: Boolean;
begin
  SkipWs;
  Result := Pos > Length(Text);
end;

function TParser.Peek: Char;
begin
  SkipWs;
  if Pos > Length(Text) then
    Result := #0
  else
    Result := Text[Pos];
end;

function TParser.Nextc: Char;
begin
  SkipWs;
  if Pos > Length(Text) then
    raise Exception.Create('unexpected end of json');
  Result := Text[Pos];
  Inc(Pos);
end;

function TParser.Expect(Ch: Char): Boolean;
begin
  Result := Nextc = Ch;
  if not Result then
    raise Exception.Create('expected token');
end;

function TParser.ParseLiteral(const Lit: string): Boolean;
var
  N: Integer;
begin
  SkipWs;
  for N := 1 to Length(Lit) do
  begin
    if (Pos > Length(Text)) or (Text[Pos] <> Lit[N]) then
      raise Exception.Create('expected literal');
    Inc(Pos);
  end;
  Result := True;
end;

function HexVal(Ch: Char): Integer;
begin
  case Ch of
    '0'..'9':
      Result := Ord(Ch) - Ord('0');
    'a'..'f':
      Result := Ord(Ch) - Ord('a') + 10;
    'A'..'F':
      Result := Ord(Ch) - Ord('A') + 10;
    else
      raise Exception.Create('bad unicode escape');
  end;
end;

function TParser.ParseString: string;
var
  Ch: Char;
  Code: Integer;
  N: Integer;
begin
  Result := '';
  Expect('"');
  while Pos <= Length(Text) do
  begin
    Ch := Text[Pos];
    Inc(Pos);
    if Ch = '"' then
      Exit;
    if Ch <> '\' then
    begin
      Result := Result + Ch;
      Continue;
    end;
    if Pos > Length(Text) then
      raise Exception.Create('unterminated escape');
    Ch := Text[Pos];
    Inc(Pos);
    case Ch of
      '"', '\', '/':
        Result := Result + Ch;
      'b':
        Result := Result + #8;
      'f':
        Result := Result + #12;
      'n':
        Result := Result + #10;
      'r':
        Result := Result + #13;
      't':
        Result := Result + #9;
      'u':
      begin
        Code := 0;
        for N := 1 to 4 do
        begin
          if Pos > Length(Text) then
            raise Exception.Create('bad unicode escape');
          Code := (Code shl 4) + HexVal(Text[Pos]);
          Inc(Pos);
        end;
        if Code < $80 then
          Result := Result + Char(Code)
        else if Code < $800 then
          Result := Result + Char($C0 or (Code shr 6)) + Char($80 or (Code and $3F))
        else
          Result := Result + Char($E0 or (Code shr 12)) +
            Char($80 or ((Code shr 6) and $3F)) + Char($80 or (Code and $3F));
      end;
      else
        raise Exception.Create('bad escape');
    end;
  end;
  raise Exception.Create('unterminated string');
end;

function TParser.ParseNumber: TJsonVal;
var
  Start: Integer;
  Raw: string;
  Frac: Boolean;
begin
  SkipWs;
  Start := Pos;
  Frac := False;
  if (Pos <= Length(Text)) and (Text[Pos] = '-') then
    Inc(Pos);
  while (Pos <= Length(Text)) and (Text[Pos] in ['0'..'9']) do
    Inc(Pos);
  if (Pos <= Length(Text)) and (Text[Pos] = '.') then
  begin
    Frac := True;
    Inc(Pos);
    while (Pos <= Length(Text)) and (Text[Pos] in ['0'..'9']) do
      Inc(Pos);
  end;
  if (Pos <= Length(Text)) and (Text[Pos] in ['e', 'E']) then
  begin
    Frac := True;
    Inc(Pos);
    if (Pos <= Length(Text)) and (Text[Pos] in ['+', '-']) then
      Inc(Pos);
    while (Pos <= Length(Text)) and (Text[Pos] in ['0'..'9']) do
      Inc(Pos);
  end;
  Raw := Copy(Text, Start, Pos - Start);
  if Frac then
    Result := JsonInt(Trunc(StrToFloat(Raw)))
  else
    Result := JsonInt(StrToInt64(Raw));
end;

function TParser.ParseObject: TJsonVal;
var
  Key: string;
  Val: TJsonVal;
  Ch: Char;
begin
  Expect('{');
  Result := JsonObj;
  try
    if Peek = '}' then
    begin
      Inc(Pos);
      Exit;
    end;
    while True do
    begin
      Key := ParseString;
      Expect(':');
      Val := ParseValue;
      Result.ObjPut(Key, Val);
      Ch := Nextc;
      if Ch = '}' then
        Exit;
      if Ch <> ',' then
        raise Exception.Create('expected comma');
    end;
  except
    Result.Free;
    raise;
  end;
end;

function TParser.ParseArray: TJsonVal;
var
  Ch: Char;
begin
  Expect('[');
  Result := JsonArr;
  try
    if Peek = ']' then
    begin
      Inc(Pos);
      Exit;
    end;
    while True do
    begin
      Result.ArrAdd(ParseValue);
      Ch := Nextc;
      if Ch = ']' then
        Exit;
      if Ch <> ',' then
        raise Exception.Create('expected comma');
    end;
  except
    Result.Free;
    raise;
  end;
end;

function TParser.ParseValue: TJsonVal;
var
  Ch: Char;
begin
  Ch := Peek;
  case Ch of
    '{':
      Result := ParseObject;
    '[':
      Result := ParseArray;
    '"':
      Result := JsonStr(ParseString);
    't':
    begin
      ParseLiteral('true');
      Result := JsonBool(True);
    end;
    'f':
    begin
      ParseLiteral('false');
      Result := JsonBool(False);
    end;
    'n':
    begin
      ParseLiteral('null');
      Result := JsonNull;
    end;
    '-', '0'..'9':
      Result := ParseNumber;
    else
      raise Exception.Create('bad json');
  end;
end;

function JsonParse(const Text: string): TJsonVal;
var
  P: TParser;
begin
  P := TParser.Create;
  try
    P.Text := Text;
    P.Pos := 1;
    Result := P.ParseValue;
    if not P.Done then
    begin
      Result.Free;
      raise Exception.Create('trailing json');
    end;
  finally
    P.Free;
  end;
end;

function ArgCount(Args: TJsonVal): Integer;
begin
  if (Args = nil) or (Args.Kind <> jkArr) then
    Result := 0
  else
    Result := Length(Args.Arr);
end;

function ArgInt(Args: TJsonVal; Index: Integer): Int64;
begin
  if (Args = nil) or (Args.Kind <> jkArr) or (Index < 0) or (Index > High(Args.Arr)) then
    raise Exception.Create('expected integer argument');
  if Args.Arr[Index].Kind <> jkInt then
    raise Exception.Create('expected integer argument');
  Result := Args.Arr[Index].I;
end;

function ArgStr(Args: TJsonVal; Index: Integer): string;
begin
  if (Args = nil) or (Args.Kind <> jkArr) or (Index < 0) or (Index > High(Args.Arr)) then
    raise Exception.Create('expected string argument');
  if Args.Arr[Index].Kind <> jkStr then
    raise Exception.Create('expected string argument');
  Result := Args.Arr[Index].S;
end;

end.
