unit Sco.Provider.Domain.Table;

interface

uses
  System.Generics.Collections, Sco.Provider;

type

  TTable = class(TInterfacedObject, ITable)
  private
    FID: string;
    FName: string;
    FFields: TTableFields;
    FObs: string;
  public
    constructor Create;
    class function New: ITable;
    destructor Destroy; override;

    function ID: string; overload;
    function ID(const Value: string): ITable; overload;

    function Name: string; overload;
    function Name(const Value: string): ITable; overload;

    function Fields: TTableFields;

    function Obs: string; overload;
    function Obs(const Value: string): ITable; overload;

  end;

implementation

uses
  system.strutils, System.SysUtils;

{ TTable }

constructor TTable.Create;
begin
  FID := TGUID.NewGuid.ToString;
  FFields := TTableFields.Create;
  FObs := EmptyStr;
end;

class function TTable.New: ITable;
begin
  Result := Self.Create;
end;

destructor TTable.Destroy;
begin
  FFields.Free;
  inherited;
end;

function TTable.Fields: TTableFields;
begin
  Result := FFields;
end;

function TTable.ID(const Value: string): ITable;
begin
  Result := Self;
  FID := Value;
end;

function TTable.ID: string;
begin
  Result := FID;
end;

function TTable.Name(const Value: string): ITable;
begin
  Result := Self;
  FName := ReplaceStr(Value, '"', '');
end;

function TTable.Obs(const Value: string): ITable;
begin
  Result := Self;
  FObs := Value;
end;

function TTable.Obs: string;
begin
  Result := FObs;
end;

function TTable.Name: string;
begin
  Result := FName;
end;

end.
