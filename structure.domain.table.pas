unit structure.domain.table;

interface

uses
  System.Generics.Collections,
  provider;

type

  TTable = class(TInterfacedObject, ITable)
  private
    FName: string;
    FFields: TDictionary<string, IField>;
  public

    constructor Create;
    destructor Destroy; override;

    function Name: string; overload;
    function Name(const Value: string): ITable; overload;

    function Fields: TDictionary<string, IField>;

  end;

implementation

uses
  system.strutils;

{ TTable }

constructor TTable.Create;
begin
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
