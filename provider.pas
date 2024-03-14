unit provider;

interface

uses
  Data.DB,
  FireDAC.Comp.Client,
  System.Classes,
  System.Generics.Collections;

type

  TProviderQuery = class(TFDQuery)
  end;

  TProviderTable = class(TFDTable)
  end;

  TProviderMemTable = class(TFDMemTable)
  end;

  IField = interface
    ['{29D1BC0C-62BA-4016-A621-6219141961FA}']

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

  TTableFields = class(TDictionary<string, IField>)
  public
    function PrimaryKeys: TArray<IField>;
    function PrimaryKeyCount: integer;
    function HasPrimaryKey: Boolean;
    function OrderedByIndex: TArray<IField>;
    procedure AddField(const AField: IField);
  end;

  ITable = interface
    ['{AEF9F64E-33D2-4433-A999-C3A8C8EF3F03}']

    function ID: string; overload;
    function ID(const Value: string): ITable; overload;

    function Name: string; overload;
    function Name(const Value: string): ITable; overload;

    function Fields: TTableFields;

    function Obs: string; overload;
    function Obs(const Value: string): ITable; overload;

  end;

  TDatabaseInfo = record
    Server: string;
    Port: integer;
    FileName: string;
    UserName: string;
    Password: string;
  end;

  IProviderDatabase = interface
    ['{678D3DF1-4417-44EB-A88C-76D74F63B3E5}']

    function SetIniFilePath(const AIniFilePath: string): IProviderDatabase;
    function SetDatabaseInfo(AInfo: TDatabaseInfo): IProviderDatabase;

    function FillTableNames(const AList: TStrings): IProviderDatabase;
    function FillFieldNames(const ATableName: string; AList: TStrings): IProviderDatabase;
    function FillFields(const ATable: ITable): IProviderDatabase;
    function FillIndexNames(const ATableName: string; AList: TStrings): IProviderDatabase;
    function FillPrimaryKeys(const ATableName: string; AList: TStrings): IProviderDatabase;
    function FillForeignKeys(const ATableName: string; AList: TStrings): IProviderDatabase;
    function FillSequences(const AList: TStrings): IProviderDatabase;
    function FillTriggers(const ATableName: string; AList: TStrings): IProviderDatabase;

    function CreateTable(const ATable: ITable): IProviderDatabase; overload;
    function CreateTable(const ATable: ITable; const ADropIfExists: Boolean): IProviderDatabase; overload;
    function FieldExists(const ATableName, AFieldName: string): boolean;
    function TableExists(const ATableName: string): boolean;

    function ConnectionString: string;

    function Clear: IProviderDatabase;
    function SetSQL(const ASql: string): IProviderDatabase; overload;
    function SetSQL(const ASql: TStrings): IProviderDatabase; overload;
    function SetDateTimeParam(const AName: string; const AValue: TDateTime): IProviderDatabase;
    function SetDateParam(const AName: string; const AValue: TDate): IProviderDatabase;
    function SetTimeParam(const AName: string; const AValue: TTime): IProviderDatabase;
    function SetStringParam(const AName: string; const AValue: string): IProviderDatabase;
    function SetIntegerParam(const AName: string; const AValue: integer): IProviderDatabase;
    function SetFloatParam(const AName: string; const AValue: Double): IProviderDatabase;
    function SetCurrencyParam(const AName: string; const AValue: Currency): IProviderDatabase;
    function SetBooleanParam(const AName: string; const AValue: Boolean): IProviderDatabase;
    function SetDataset(var ADataSet: TProviderMemTable): IProviderDatabase;
    function Open: IProviderDatabase;
    function Execute: IProviderDatabase; overload;
    function Execute(out ARowsAffected: integer): IProviderDatabase; overload;

    function StartTransaction: IProviderDatabase;
    function InTransaction: Boolean;
    function Commit: IProviderDatabase;
    function Rollback: IProviderDatabase;

  end;

  TProvider = class
  strict private
    class var FInstance: IProviderDatabase;
  public
    class function Firebird: IProviderDatabase;
    class function Instance: IProviderDatabase;
  end;

  TStructureDomain = class
  public
    class function Table: ITable;
    class function Field: IField;
  end;

implementation

uses
  structure.domain.field,
  structure.domain.table,
  provider.firebird,
  System.SysUtils,
  System.Generics.Defaults;

{ TProvider }

class function TProvider.Firebird: IProviderDatabase;
begin
  Result := TProviderFirebird.Create;
end;

class function TProvider.Instance: IProviderDatabase;
begin
  if not Assigned(FInstance) then
  begin
    FInstance := TProviderFirebird.Create;
  end;
  Result := FInstance;
end;

{ TStructureDomain }

class function TStructureDomain.Field: IField;
begin
  Result := TField.New;
end;

class function TStructureDomain.Table: ITable;
begin
  Result := TTable.New;
end;

{ TTableField }

procedure TTableFields.AddField(const AField: IField);
begin
  Self.AddOrSetValue(AField.Name, AField);
end;

function TTableFields.HasPrimaryKey: Boolean;
begin
  Result := Self.PrimaryKeyCount > 0;
end;

function TTableFields.OrderedByIndex: TArray<IField>;
var
  LFields: TList<IField>;
begin
  LFields := TList<IField>.Create;
  try
    LFields.AddRange(Self.Values.ToArray);

    LFields.Sort(TComparer<IField>.Construct(
      function (const L, R: IField): integer
      begin
        if L.ID = R.ID then
        begin
          Result := 0;
        end
        else
        begin
          if L.ID < R.ID then
          begin
            Result := -1;
          end
          else
          begin
            Result := 1;
          end;
        end;
      end
    ));

    Result := LFields.ToArray;

  finally
    LFields.Free;
  end;
end;

function TTableFields.PrimaryKeyCount: integer;
begin
  Result := Length(Self.PrimaryKeys);
end;

function TTableFields.PrimaryKeys: TArray<IField>;
var
  LField: IField;
  LFields: TArray<IField>;
begin
  SetLength(Result, 0);

  LFields := Self.OrderedByIndex;
  for LField in LFields do
  begin
    if LField.PrimaryKey then
    begin
      SetLength(Result, Length(Result) + 1);
      Result[Length(Result) - 1] := LField;
    end;
  end;
end;

end.
