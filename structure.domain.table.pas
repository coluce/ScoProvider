unit structure.domain.table;

interface

uses
  System.Generics.Collections,
  provider;

type

  TTable = class(TInterfacedObject, ITable)
  private
    FID: string;
    FName: string;
    FFields: TDictionary<string, IField>;
  public

    constructor Create;
    destructor Destroy; override;

    function ID: string; overload;
    function ID(const Value: string): ITable; overload;

    function Name: string; overload;
    function Name(const Value: string): ITable; overload;

    function Fields: TDictionary<string, IField>;

  end;

implementation

uses
  system.strutils, System.SysUtils;

{ TTable }

constructor TTable.Create;
begin
  FID := TGUID.NewGuid.ToString;
  FFields := TDictionary<string, IField>.Create;
end;

destructor TTable.Destroy;
begin
  FFields.Free;
  inherited;
end;

function TTable.Fields: TDictionary<string, IField>;
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

function TTable.Name: string;
begin
  Result := FName;
end;

end.
