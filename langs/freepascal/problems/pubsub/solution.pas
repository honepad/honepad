unit solution;

{$mode objfpc}{$H+}
{$M+}

interface

uses
  SysUtils, Classes, minijson;

type
  Simulation = class
  private
    Subs: TStringList;
    Inboxes: TStringList;
    Retained: TStringList;
    function TopicClients(const Topic: string; CreateIfMissing: Boolean): TStringList;
    function ClientInbox(const Client: string; CreateIfMissing: Boolean): TStringList;
    function JoinList(List: TStringList): string;
  public
    constructor Create;
    destructor Destroy; override;
  published
    function Subscribe(const Topic, Client: string): TJsonVal;
    function Unsubscribe(const Topic, Client: string): TJsonVal;
    function Publish(const Topic, Message: string): TJsonVal;
    function Inbox(const Client: string): TJsonVal;
    function ListTopics: TJsonVal;
    function Subscribers(const Topic: string): TJsonVal;
    function Peek(const Client: string): TJsonVal;
    function Ack(const Client: string; N: Int64): TJsonVal;
    function Retain(const Topic, Message: string): TJsonVal;
  end;

function NewTarget: TObject;

implementation

constructor Simulation.Create;
begin
  inherited Create;
  Subs := TStringList.Create;
  Subs.Sorted := False;
  Inboxes := TStringList.Create;
  Retained := TStringList.Create;
end;

destructor Simulation.Destroy;
var
  I: Integer;
begin
  for I := 0 to Subs.Count - 1 do
    Subs.Objects[I].Free;
  for I := 0 to Inboxes.Count - 1 do
    Inboxes.Objects[I].Free;
  Subs.Free;
  Inboxes.Free;
  Retained.Free;
  inherited Destroy;
end;

function Simulation.TopicClients(const Topic: string; CreateIfMissing: Boolean): TStringList;
var
  Idx: Integer;
begin
  Idx := Subs.IndexOf(Topic);
  if Idx >= 0 then
    Exit(TStringList(Subs.Objects[Idx]));
  if not CreateIfMissing then
    Exit(nil);
  Result := TStringList.Create;
  Subs.AddObject(Topic, Result);
end;

function Simulation.ClientInbox(const Client: string; CreateIfMissing: Boolean): TStringList;
var
  Idx: Integer;
begin
  Idx := Inboxes.IndexOf(Client);
  if Idx >= 0 then
    Exit(TStringList(Inboxes.Objects[Idx]));
  if not CreateIfMissing then
    Exit(nil);
  Result := TStringList.Create;
  Inboxes.AddObject(Client, Result);
end;

function Simulation.JoinList(List: TStringList): string;
var
  I: Integer;
begin
  Result := '';
  if List = nil then
    Exit;
  for I := 0 to List.Count - 1 do
  begin
    if I > 0 then
      Result := Result + ', ';
    Result := Result + List[I];
  end;
end;

function Simulation.Subscribe(const Topic, Client: string): TJsonVal;
var
  Clients: TStringList;
  Kept: string;
begin
  Clients := TopicClients(Topic, True);
  if Clients.IndexOf(Client) >= 0 then
    Exit(JsonStr('false'));
  Clients.Add(Client);
  if Retained.IndexOfName(Topic) >= 0 then
  begin
    Kept := Retained.Values[Topic];
    ClientInbox(Client, True).Add(Topic + ':' + Kept);
  end;
  Result := JsonStr('true');
end;

function Simulation.Unsubscribe(const Topic, Client: string): TJsonVal;
var
  Clients: TStringList;
  Idx: Integer;
begin
  Clients := TopicClients(Topic, False);
  if (Clients = nil) or (Clients.IndexOf(Client) < 0) then
    Exit(JsonStr('false'));
  Clients.Delete(Clients.IndexOf(Client));
  if Clients.Count = 0 then
  begin
    Idx := Subs.IndexOf(Topic);
    Subs.Objects[Idx].Free;
    Subs.Delete(Idx);
  end;
  Result := JsonStr('true');
end;

function Simulation.Publish(const Topic, Message: string): TJsonVal;
var
  Clients: TStringList;
  Payload: string;
  I: Integer;
begin
  Clients := TopicClients(Topic, False);
  if Clients = nil then
    Exit(JsonStr('0'));
  Payload := Topic + ':' + Message;
  for I := 0 to Clients.Count - 1 do
    ClientInbox(Clients[I], True).Add(Payload);
  Result := JsonStr(IntToStr(Clients.Count));
end;

function Simulation.Inbox(const Client: string): TJsonVal;
begin
  Result := JsonStr(JoinList(ClientInbox(Client, False)));
end;

function Simulation.ListTopics: TJsonVal;
var
  Topics: TStringList;
  I: Integer;
begin
  Topics := TStringList.Create;
  try
    Topics.Sorted := True;
    Topics.Duplicates := dupIgnore;
    for I := 0 to Subs.Count - 1 do
      Topics.Add(Subs[I]);
    Result := JsonStr(JoinList(Topics));
  finally
    Topics.Free;
  end;
end;

function Simulation.Subscribers(const Topic: string): TJsonVal;
var
  Clients, Ordered: TStringList;
  I: Integer;
begin
  Clients := TopicClients(Topic, False);
  if Clients = nil then
    Exit(JsonStr(''));
  Ordered := TStringList.Create;
  try
    Ordered.Sorted := True;
    Ordered.Duplicates := dupAccept;
    for I := 0 to Clients.Count - 1 do
      Ordered.Add(Clients[I]);
    Result := JsonStr(JoinList(Ordered));
  finally
    Ordered.Free;
  end;
end;

function Simulation.Peek(const Client: string): TJsonVal;
var
  Items: TStringList;
begin
  Items := ClientInbox(Client, False);
  if (Items = nil) or (Items.Count = 0) then
    Exit(JsonStr(''));
  Result := JsonStr(Items[0]);
end;

function Simulation.Ack(const Client: string; N: Int64): TJsonVal;
var
  Items: TStringList;
  I: Integer;
begin
  Items := ClientInbox(Client, False);
  if (N <= 0) or (Items = nil) then
    Exit(JsonStr('invalid_request'));
  if N > Items.Count then
    Exit(JsonStr('invalid_request'));
  for I := 1 to Integer(N) do
    Items.Delete(0);
  Result := JsonStr(IntToStr(Items.Count));
end;

function Simulation.Retain(const Topic, Message: string): TJsonVal;
begin
  Retained.Values[Topic] := Message;
  Result := JsonStr('');
end;

function NewTarget: TObject;
begin
  Result := Simulation.Create;
end;

end.
