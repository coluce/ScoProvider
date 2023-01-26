unit provider;

interface

uses
  Data.DB,
  FireDAC.Comp.Client,
  System.Classes;

type



  IProviderDatabase = interface
    ['{678D3DF1-4417-44EB-A88C-76D74F63B3E5}']

    function SetIniFilePath(const AIniFilePath: string): IProviderDatabase;

    function FillTableNames(const AList: TStrings): IProviderDatabase;
    function FillFieldNames(const ATableName: string; AList: TStrings): IProviderDatabase;
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
    function SetDataset(ADataSet: TFDMemTable): IProviderDatabase;
    function Open: IProviderDatabase;
    function Execute: IProviderDatabase; overload;
    function Execute(out ARowsAffected: integer): IProviderDatabase; overload;

  end;

  TProvider = class
  public
    class function Firebird: IProviderDatabase;
  end;

implementation

uses
  provider.firebird;

{ TProvider }

class function TProvider.Firebird: IProviderDatabase;
begin
  Result := TProviderFirebird.Create;
end;

end.
