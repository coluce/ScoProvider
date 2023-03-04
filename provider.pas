unit provider;

interface

uses
  Data.DB,
  FireDAC.Comp.Client,
  System.Classes,
  System.Generics.Collections;

type

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

  end;

  ITable = interface
    ['{AEF9F64E-33D2-4433-A999-C3A8C8EF3F03}']

    function Name: string; overload;
    function Name(const Value: string): ITable; overload;

    function Fields: TDictionary<string, IField>;

  end;

  IProviderDatabase = interface
    ['{678D3DF1-4417-44EB-A88C-76D74F63B3E5}']

    function SetIniFilePath(const AIniFilePath: string): IProviderDatabase;

    function FillTableNames(const AList: TStrings): IProviderDatabase;
    function FillFieldNames(const ATableName: string; AList: TStrings): IProviderDatabase;
    function FillFields(const ATable: ITable): IProviderDatabase;
    function FillIndexNames(const ATableName: string; AList: TStrings): IProviderDatabase;
    function FillPrimaryKeys(const ATableName: string; AList: TStrings): IProviderDatabase;
    function FillForeignKeys(const ATableName: string; AList: TStrings): IProviderDatabase;
    function FillSequences(const AList: TStrings): IProviderDatabase;
    function FillTriggers(const ATableName: string; AList: TStrings): IProviderDatabase;

    function ExistsField(const ATableName, AFieldName: string): boolean;

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
    function SetDataset(ADataSet: TFDMemTable): IProviderDatabase;
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
  provider.firebird;

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
  Result := TField.Create;
end;

class function TStructureDomain.Table: ITable;
begin
  Result := TTable.Create;
end;

end.
