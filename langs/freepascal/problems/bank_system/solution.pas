unit solution;

{$mode objfpc}{$H+}
{$M+}

interface

uses
  SysUtils, Classes, minijson;

type
  TBalancePoint = record
    Timestamp: Int64;
    Balance: Int64;
  end;

  TCashback = record
    Timestamp: Int64;
    AccountId: string;
    Amount: Int64;
    PaymentId: string;
  end;

  TAccount = class
  public
    AccountId: string;
    Balance: Int64;
    Outgoing: Int64;
    Payments: TStringList;
    CreatedAt: Int64;
    History: array of TBalancePoint;
    constructor Create(const AId: string; ACreatedAt: Int64);
    destructor Destroy; override;
    procedure RecordBalance(Timestamp: Int64);
    function DepositAmount(Amount: Int64): Int64;
    function Withdraw(Amount: Int64): Boolean;
    function GetBalanceAt(TimeAt: Int64): TJsonVal;
  end;

  Simulation = class
  private
    Accounts: TStringList;
    PaymentCounter: Integer;
    Pending: array of TCashback;
    function FindAccount(const AccountId: string): TAccount;
    procedure ProcessCashbacks(Timestamp: Int64);
  public
    constructor Create;
    destructor Destroy; override;
  published
    function CreateAccount(Timestamp: Int64; const AccountId: string): TJsonVal;
    function Deposit(Timestamp: Int64; const AccountId: string; Amount: Int64): TJsonVal;
    function Transfer(Timestamp: Int64; const SourceAccountId, TargetAccountId: string;
      Amount: Int64): TJsonVal;
    function TopSpenders(Timestamp, N: Int64): TJsonVal;
    function Pay(Timestamp: Int64; const AccountId: string; Amount: Int64): TJsonVal;
    function GetPaymentStatus(Timestamp: Int64; const AccountId, Payment: string): TJsonVal;
    function MergeAccounts(Timestamp: Int64; const AccountId1, AccountId2: string): TJsonVal;
    function GetBalance(Timestamp: Int64; const AccountId: string; TimeAt: Int64): TJsonVal;
  end;

function NewTarget: TObject;

implementation

const
  CashbackDelay: Int64 = Int64(24) * 60 * 60 * 1000;

constructor TAccount.Create(const AId: string; ACreatedAt: Int64);
begin
  inherited Create;
  AccountId := AId;
  CreatedAt := ACreatedAt;
  Payments := TStringList.Create;
  Payments.NameValueSeparator := '=';
  SetLength(History, 1);
  History[0].Timestamp := ACreatedAt;
  History[0].Balance := 0;
end;

destructor TAccount.Destroy;
begin
  Payments.Free;
  inherited Destroy;
end;

procedure TAccount.RecordBalance(Timestamp: Int64);
begin
  SetLength(History, Length(History) + 1);
  History[High(History)].Timestamp := Timestamp;
  History[High(History)].Balance := Balance;
end;

function TAccount.DepositAmount(Amount: Int64): Int64;
begin
  Balance := Balance + Amount;
  Result := Balance;
end;

function TAccount.Withdraw(Amount: Int64): Boolean;
begin
  if Balance < Amount then
    Exit(False);
  Balance := Balance - Amount;
  Outgoing := Outgoing + Amount;
  Result := True;
end;

function TAccount.GetBalanceAt(TimeAt: Int64): TJsonVal;
var
  N: Integer;
  Found: Boolean;
  Value: Int64;
begin
  if TimeAt < CreatedAt then
    Exit(JsonNull);
  Found := False;
  Value := 0;
  for N := 0 to High(History) do
  begin
    if History[N].Timestamp <= TimeAt then
    begin
      Found := True;
      Value := History[N].Balance;
    end
    else
      Break;
  end;
  if Found then
    Result := JsonInt(Value)
  else
    Result := JsonNull;
end;

constructor Simulation.Create;
begin
  inherited Create;
  Accounts := TStringList.Create;
  Accounts.Sorted := True;
  Accounts.Duplicates := dupIgnore;
end;

destructor Simulation.Destroy;
var
  N: Integer;
begin
  for N := 0 to Accounts.Count - 1 do
    Accounts.Objects[N].Free;
  Accounts.Free;
  inherited Destroy;
end;

function Simulation.FindAccount(const AccountId: string): TAccount;
var
  Idx: Integer;
begin
  Idx := Accounts.IndexOf(AccountId);
  if Idx < 0 then
    Result := nil
  else
    Result := TAccount(Accounts.Objects[Idx]);
end;

procedure Simulation.ProcessCashbacks(Timestamp: Int64);
var
  Cb: TCashback;
  Account: TAccount;
begin
  while Length(Pending) > 0 do
  begin
    Cb := Pending[0];
    if Cb.Timestamp > Timestamp then
      Break;
    Delete(Pending, 0, 1);
    Account := FindAccount(Cb.AccountId);
    if Account <> nil then
    begin
      Account.DepositAmount(Cb.Amount);
      Account.Payments.Values[Cb.PaymentId] := 'CASHBACK_RECEIVED';
      Account.RecordBalance(Cb.Timestamp);
    end;
  end;
end;

function Simulation.CreateAccount(Timestamp: Int64; const AccountId: string): TJsonVal;
begin
  ProcessCashbacks(Timestamp);
  if FindAccount(AccountId) <> nil then
    Exit(JsonBool(False));
  Accounts.AddObject(AccountId, TAccount.Create(AccountId, Timestamp));
  Result := JsonBool(True);
end;

function Simulation.Deposit(Timestamp: Int64; const AccountId: string; Amount: Int64): TJsonVal;
var
  Account: TAccount;
begin
  ProcessCashbacks(Timestamp);
  Account := FindAccount(AccountId);
  if Account = nil then
    Exit(JsonNull);
  Result := JsonInt(Account.DepositAmount(Amount));
  Account.RecordBalance(Timestamp);
end;

function Simulation.Transfer(Timestamp: Int64; const SourceAccountId, TargetAccountId: string;
  Amount: Int64): TJsonVal;
var
  Source, Target: TAccount;
begin
  ProcessCashbacks(Timestamp);
  Source := FindAccount(SourceAccountId);
  Target := FindAccount(TargetAccountId);
  if (Source = nil) or (Target = nil) or (SourceAccountId = TargetAccountId) then
    Exit(JsonNull);
  if not Source.Withdraw(Amount) then
    Exit(JsonNull);
  Target.DepositAmount(Amount);
  Source.RecordBalance(Timestamp);
  Target.RecordBalance(Timestamp);
  Result := JsonInt(Source.Balance);
end;

function Simulation.TopSpenders(Timestamp, N: Int64): TJsonVal;
var
  Ids: array of string;
  I, J, Take: Integer;
  Tmp: string;
begin
  ProcessCashbacks(Timestamp);
  SetLength(Ids, Accounts.Count);
  for I := 0 to Accounts.Count - 1 do
    Ids[I] := Accounts[I];
  for I := 0 to High(Ids) - 1 do
    for J := I + 1 to High(Ids) do
      if (FindAccount(Ids[J]).Outgoing > FindAccount(Ids[I]).Outgoing) or
        ((FindAccount(Ids[J]).Outgoing = FindAccount(Ids[I]).Outgoing) and (Ids[J] < Ids[I])) then
      begin
        Tmp := Ids[I];
        Ids[I] := Ids[J];
        Ids[J] := Tmp;
      end;
  Take := Length(Ids);
  if N < Take then
    Take := Integer(N);
  Result := JsonArr;
  for I := 0 to Take - 1 do
    Result.ArrAdd(JsonStr(Ids[I] + '(' + IntToStr(FindAccount(Ids[I]).Outgoing) + ')'));
end;

function Simulation.Pay(Timestamp: Int64; const AccountId: string; Amount: Int64): TJsonVal;
var
  Account: TAccount;
  PaymentId: string;
  Cb: TCashback;
begin
  ProcessCashbacks(Timestamp);
  Account := FindAccount(AccountId);
  if Account = nil then
    Exit(JsonNull);
  if not Account.Withdraw(Amount) then
    Exit(JsonNull);
  Inc(PaymentCounter);
  PaymentId := 'payment' + IntToStr(PaymentCounter);
  Account.Payments.Values[PaymentId] := 'IN_PROGRESS';
  Account.RecordBalance(Timestamp);
  Cb.Timestamp := Timestamp + CashbackDelay;
  Cb.AccountId := AccountId;
  Cb.Amount := (Amount * 2) div 100;
  Cb.PaymentId := PaymentId;
  SetLength(Pending, Length(Pending) + 1);
  Pending[High(Pending)] := Cb;
  Result := JsonStr(PaymentId);
end;

function Simulation.GetPaymentStatus(Timestamp: Int64; const AccountId, Payment: string): TJsonVal;
var
  Account: TAccount;
  Idx: Integer;
begin
  ProcessCashbacks(Timestamp);
  Account := FindAccount(AccountId);
  if Account = nil then
    Exit(JsonNull);
  Idx := Account.Payments.IndexOfName(Payment);
  if Idx < 0 then
    Exit(JsonNull);
  Result := JsonStr(Account.Payments.ValueFromIndex[Idx]);
end;

function Simulation.MergeAccounts(Timestamp: Int64; const AccountId1, AccountId2: string): TJsonVal;
var
  Account1, Account2: TAccount;
  I, Idx: Integer;
  Points: array of TBalancePoint;
  SwapPoint: TBalancePoint;
begin
  ProcessCashbacks(Timestamp);
  if AccountId1 = AccountId2 then
    Exit(JsonBool(False));
  Account1 := FindAccount(AccountId1);
  Account2 := FindAccount(AccountId2);
  if (Account1 = nil) or (Account2 = nil) then
    Exit(JsonBool(False));
  Account1.Balance := Account1.Balance + Account2.Balance;
  Account1.Outgoing := Account1.Outgoing + Account2.Outgoing;
  for I := 0 to Account2.Payments.Count - 1 do
    Account1.Payments.Values[Account2.Payments.Names[I]] := Account2.Payments.ValueFromIndex[I];
  SetLength(Points, Length(Account1.History) + Length(Account2.History));
  for I := 0 to High(Account1.History) do
    Points[I] := Account1.History[I];
  for I := 0 to High(Account2.History) do
    Points[Length(Account1.History) + I] := Account2.History[I];
  for I := 0 to High(Points) - 1 do
    for Idx := I + 1 to High(Points) do
      if Points[Idx].Timestamp < Points[I].Timestamp then
      begin
        SwapPoint := Points[I];
        Points[I] := Points[Idx];
        Points[Idx] := SwapPoint;
      end;
  Account1.History := Points;
  if Account2.CreatedAt < Account1.CreatedAt then
    Account1.CreatedAt := Account2.CreatedAt;
  Account1.RecordBalance(Timestamp);
  for I := 0 to High(Pending) do
    if Pending[I].AccountId = AccountId2 then
      Pending[I].AccountId := AccountId1;
  Idx := Accounts.IndexOf(AccountId2);
  Account2.Free;
  Accounts.Delete(Idx);
  Result := JsonBool(True);
end;

function Simulation.GetBalance(Timestamp: Int64; const AccountId: string; TimeAt: Int64): TJsonVal;
var
  Account: TAccount;
begin
  ProcessCashbacks(Timestamp);
  Account := FindAccount(AccountId);
  if Account = nil then
    Exit(JsonNull);
  Result := Account.GetBalanceAt(TimeAt);
end;

function NewTarget: TObject;
begin
  Result := Simulation.Create;
end;

end.
