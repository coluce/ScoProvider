unit Sco.Provider.Domain.Table;

interface

uses
  System.Generics.Collections, Sco.Provider;

type

  TTableForeignKey = class(TInterfacedObject, ITableForeignKey)
  private
    FName: string;
    FKeys: string;
    FRefrenceTable: string;
    FRefrenceKeys: string;
    FOnDelete: TTableForeignKeyType;
    FOnUpdate: TTableForeignKeyType;
  public
    constructor Create;
    class function New: ITableForeignKey;

    function Name: string; overload;
    function Name(const Value: string): ITableForeignKey; overload;

    function Keys: string; overload;
    function Keys(const Value: string): ITableForeignKey; overload;

    function RefrenceTable: string; overload;
    function ReferenceTable(const Value: string): ITableForeignKey; overload;

    function RefrenceKeys: string; overload;
    function ReferenceKeys(const Value: string): ITableForeignKey; overload;

    function OnDelete: TTableForeignKeyType; overload;
    function OnDelete(const Value: TTableForeignKeyType): ITableForeignKey; overload;

    function OnUpdate: TTableForeignKeyType; overload;
    function OnUpdate(const Value: TTableForeignKeyType): ITableForeignKey; overload;

  end;

  TTable = class(TInterfacedObject, ITable)
  private
    FID: string;
    FName: string;
    FFields: TTableFields;
    FForeignKeys: TTableForeignKeys;
    FObs: string;
  public
    constructor Create;
    destructor Destroy; override;
    class function New: ITable;

    function ID: string; overload;
    function ID(const Value: string): ITable; overload;

    function Name: string; overload;
    function Name(const Value: string): ITable; overload;

    function Fields: TTableFields;
    function ForeignKeys: TTableForeignKeys;

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
  FForeignKeys := TTableForeignKeys.Create;
  FObs := EmptyStr;
end;

class function TTable.New: ITable;
begin
  Result := Self.Create;
end;

destructor TTable.Destroy;
begin
  FFields.Free;
  FForeignKeys.Free;
  inherited;
end;

function TTable.Fields: TTableFields;
begin
  Result := FFields;
end;

function TTable.ForeignKeys: TTableForeignKeys;
begin
  Result := FForeignKeys;
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

{ TTableForeignKey }

class function TTableForeignKey.New: ITableForeignKey;
begin
  Result := Self.Create;
end;

constructor TTableForeignKey.Create;
begin
  FOnDelete := None;
  FOnUpdate := None;
end;

function TTableForeignKey.Keys(const Value: string): ITableForeignKey;
begin
  Result := Self;
  FKeys := Value;
end;

function TTableForeignKey.Keys: string;
begin
  Result := FKeys;
end;

function TTableForeignKey.Name: string;
begin
  Result := FName;
end;

function TTableForeignKey.Name(const Value: string): ITableForeignKey;
begin
  Result := Self;
  FName := Value;
end;

function TTableForeignKey.OnDelete: TTableForeignKeyType;
begin
  Result := FOnDelete;
end;

function TTableForeignKey.OnDelete(const Value: TTableForeignKeyType): ITableForeignKey;
begin
  Result := Self;
  FOnDelete := Value;
end;

function TTableForeignKey.OnUpdate: TTableForeignKeyType;
begin
  Result := FOnUpdate;
end;

function TTableForeignKey.OnUpdate(const Value: TTableForeignKeyType): ITableForeignKey;
begin
  Result := Self;
  FOnUpdate := Value;
end;

function TTableForeignKey.ReferenceKeys(const Value: string): ITableForeignKey;
begin
  Result := Self;
  FRefrenceKeys := Value;
end;

function TTableForeignKey.ReferenceTable(const Value: string): ITableForeignKey;
begin
  Result := Self;
  FRefrenceTable := Value;
end;

function TTableForeignKey.RefrenceKeys: string;
begin
  Result := FRefrenceKeys;
end;

function TTableForeignKey.RefrenceTable: string;
begin
  Result := FRefrenceTable;
end;

end.
