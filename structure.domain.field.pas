unit structure.domain.field;

interface

uses
  provider;

type

  TField = class(TInterfacedObject, IField)
  private
    FID: integer;
    FPrimaryKey: Boolean;
    FName: string;
    FFieldType: string;
    FFieldSize: integer;
    FObs: string;
    constructor Create;
  public

    class function New: IField;

    function ID: integer; overload;
    function ID(const Value: integer): IField; overload;

    function PrimaryKey: Boolean; overload;
    function PrimaryKey(const Value: Boolean): IField; overload;

    function Name: string; overload;
    function Name(const Value: string): IField; overload;

    function FieldType: string; overload;
    function FieldType(const Value: string): IField; overload;

    function FieldSize: integer; overload;
    function FieldSize(const Value: integer): IField; overload;

    function Obs: string; overload;
    function Obs(const Value: string): IField; overload;

  end;

implementation

uses
  system.sysutils,
  system.strutils;

{ TField }

constructor TField.Create;
begin
  FID := -1;
  FPrimaryKey := False;
  FName := EmptyStr;
  FFieldType := EmptyStr;
  FFieldSize := -1;
  FObs := EmptyStr;
end;

class function TField.New: IField;
begin
  Result := Self.Create;
end;

function TField.FieldType: string;
begin
  Result := FFieldType.Trim;
end;

function TField.FieldSize(const Value: integer): IField;
begin
  Result := Self;
  FFieldSize := Value;
end;

function TField.FieldSize: integer;
begin
  Result := FFieldSize;
end;

function TField.FieldType(const Value: string): IField;
begin
  Result := Self;
  FFieldType := Value.trim;
end;

function TField.ID: integer;
begin
  Result := FID;
end;

function TField.ID(const Value: integer): IField;
begin
  Result := Self;
  FID := Value;
end;

function TField.Name(const Value: string): IField;
begin
  Result := Self;
  FName := trim(ReplaceStr(Value, '"', ''));
end;

function TField.Obs(const Value: string): IField;
begin
  Result := Self;
  FObs := Value;
end;

function TField.Obs: string;
begin
  Result := FObs;
end;

function TField.PrimaryKey(const Value: Boolean): IField;
begin
  Result := Self;
  FPrimaryKey := Value;
end;

function TField.PrimaryKey: Boolean;
begin
  Result := FPrimaryKey;
end;

function TField.Name: string;
begin
  Result := FName;
end;

end.
