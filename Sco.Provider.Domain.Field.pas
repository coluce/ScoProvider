unit Sco.Provider.Domain.Field;

interface

uses
  Sco.Provider;

type

  TField = class(TInterfacedObject, IField)
  private
    FIndex: integer;
    FPrimaryKey: Boolean;
    FNotNull: Boolean;
    FName: string;
    FFieldType: string;
    FFieldSize: integer;
    FCharacterSet: string;
    FObs: string;
  public
    constructor Create;
    class function New: IField;

    function Index: integer; overload;
    function Index(const Value: integer): IField; overload;

    function PrimaryKey: Boolean; overload;
    function PrimaryKey(const Value: Boolean): IField; overload;

    function NotNull: Boolean; overload;
    function NotNull(const Value: Boolean): IField; overload;

    function Name: string; overload;
    function Name(const Value: string): IField; overload;

    function FieldType: string; overload;
    function FieldType(const Value: string): IField; overload;

    function FieldSize: integer; overload;
    function FieldSize(const Value: integer): IField; overload;

    function CharacterSet: string; overload;
    function CharacterSet(const Value: string): IField; overload;

    function Obs: string; overload;
    function Obs(const Value: string): IField; overload;

  end;

implementation

uses
  System.SysUtils, System.StrUtils;

{ TField }

constructor TField.Create;
begin
  FIndex := -1;
  FPrimaryKey := False;
  FName := EmptyStr;
  FNotNull := False;
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

function TField.Index: integer;
begin
  Result := FIndex;
end;

function TField.Index(const Value: integer): IField;
begin
  Result := Self;
  FIndex := Value;
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

function TField.NotNull(const Value: Boolean): IField;
begin
  Result := Self;
  FNotNull := Value;
end;

function TField.NotNull: Boolean;
begin
  Result := FNotNull;
end;

function TField.Name: string;
begin
  Result := FName;
end;

function TField.Name(const Value: string): IField;
begin
  Result := Self;
  FName := trim(ReplaceStr(Value, '"', ''));
end;

function TField.CharacterSet(const Value: string): IField;
begin
  Result := Self;
  FCharacterSet := Value;
end;

function TField.CharacterSet: string;
begin
  Result := FCharacterSet;
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

end.
