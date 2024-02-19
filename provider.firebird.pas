unit provider.firebird;

interface

uses
  provider,
  Data.DB,
  FireDAC.Stan.Def,
  FireDAC.Phys.FBDef,
  FireDAC.Stan.Intf,
  FireDAC.Stan.ASync,
  FireDAC.Phys,
  FireDAC.Phys.IBBase,
  FireDAC.Phys.FB,
  FireDAC.DApt,
  FireDAC.Comp.Client,
  FireDAC.Stan.Param,
  FireDAC.VCLUI.Wait,
  System.Classes;

type

  TProviderFirebird = class(TInterfacedObject, IProviderDatabase)
  private
    FConnection: TFDConnection;
    FConnectionInfo: TDatabaseInfo;
    FQuery: TFDQuery;
    FDataSet: TFDMemTable;
    FIniFilePath: string;
    procedure LoadDatabaseParams;
  public

    constructor Create;
    destructor Destroy; override;

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

    function ExistsField(const ATableName, AFieldName: string): boolean;

    function ConnectionString: string;

    function Clear: IProviderDatabase;
    function SetSQL(const ASQL: string): IProviderDatabase; overload;
    function SetSQL(const ASQL: TStrings): IProviderDatabase; overload;

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

implementation

uses
  System.IOUtils,
  System.IniFiles,
  System.SysUtils,
  FireDAC.Phys.Intf;

{ TProviderFirebird }

function TProviderFirebird.Clear: IProviderDatabase;
begin
  Result := Self;
  FDataSet := nil;
  if FQuery.Active then
  begin
    FQuery.Close;
  end;
  FQuery.SQL.Clear;
end;

function TProviderFirebird.ConnectionString: string;
begin
  Result := FConnection.ConnectionString;
end;

constructor TProviderFirebird.Create;
begin
  FIniFilePath := ChangeFileExt(ParamStr(0), '.conf');
  FConnection := TFDConnection.Create(nil);
  FConnection.DriverName := 'FB';
  FQuery := TFDQuery.Create(FConnection);
  FQuery.Connection := FConnection;
  LoadDatabaseParams;
end;

destructor TProviderFirebird.Destroy;
begin
  FQuery.Free;

  if FConnection.Connected then
    FConnection.Connected := False;

  FConnection.Free;
  inherited;
end;

function TProviderFirebird.Execute(out ARowsAffected: integer): IProviderDatabase;
begin
  Result := Self;
  ARowsAffected := -1;
  FQuery.ExecSQL;
  ARowsAffected := FQuery.RowsAffected;
end;

function TProviderFirebird.ExistsField(const ATableName, AFieldName: string): boolean;
var
  LList: TStrings;
begin
  LList := TStringList.Create;
  try
    FConnection.GetFieldNames(EmptyStr, EmptyStr, ATableName, EmptyStr, LList);
    Result := LList.IndexOf(UpperCase(AFieldName)) <> -1;
  finally
    LList.Free;
  end;
end;

function TProviderFirebird.FillFieldNames(const ATableName: string; AList: TStrings): IProviderDatabase;
begin
  Result := Self;

  if not Assigned(AList) then
    Exit;

  if ATableName.Trim.IsEmpty then
    Exit;

  AList.Clear;
  FConnection.GetFieldNames(EmptyStr, EmptyStr, ATableName, EmptyStr, AList);
end;

function TProviderFirebird.FillFields(const ATable: ITable): IProviderDatabase;
var
  LMetaInfoQuery: TFDMetaInfoQuery;
  LField: IField;
begin
  if not Assigned(ATable) then
    Exit;

  ATable.Fields.Clear;

  LMetaInfoQuery := TFDMetaInfoQuery.Create(FConnection);
  try
    LMetaInfoQuery.Connection := FConnection;
    LMetaInfoQuery.MetaInfoKind := mkTableFields;
    LMetaInfoQuery.ObjectName := ATable.Name;
    LMetaInfoQuery.Open;

    if not LMetaInfoQuery.IsEmpty then
    begin
      while not LMetaInfoQuery.Eof do
      begin
        LField := TStructureDomain.Field
          .ID(LMetaInfoQuery.FieldByName('COLUMN_POSITION').AsInteger)
          .PrimaryKey(False)
          .Name(LMetaInfoQuery.FieldByName('COLUMN_NAME').AsString)
          .FieldType(LMetaInfoQuery.FieldByName('COLUMN_TYPENAME').AsString)
          .FieldSize(LMetaInfoQuery.FieldByName('COLUMN_LENGTH').AsInteger);

        ATable.Fields.Add(LField.Name, LField);

        LMetaInfoQuery.Next;
      end;
    end;

    LMetaInfoQuery.Close;
    LMetaInfoQuery.MetaInfoKind := mkPrimaryKeyFields;
    LMetaInfoQuery.BaseObjectName := ATable.Name;
    LMetaInfoQuery.Open;

    if not LMetaInfoQuery.IsEmpty then
    begin
      while not LMetaInfoQuery.Eof do
      begin
        if ATable.Fields.TryGetValue(LMetaInfoQuery.FieldByName('COLUMN_NAME').AsString, LField) then
        begin
          LField.PrimaryKey(True);
        end;
        LMetaInfoQuery.Next;
      end;
    end;

  finally
    LMetaInfoQuery.Free;
  end;

end;

function TProviderFirebird.FillForeignKeys(const ATableName: string; AList: TStrings): IProviderDatabase;
var
  LMetaInfoQuery: TFDMetaInfoQuery;
begin

  Result := Self;

  if not Assigned(AList) then
    Exit;

  AList.Clear;

  LMetaInfoQuery := TFDMetaInfoQuery.Create(FConnection);
  try
    LMetaInfoQuery.Connection := FConnection;
    LMetaInfoQuery.MetaInfoKind := mkForeignKeys;
    LMetaInfoQuery.ObjectName := ATableName;
    LMetaInfoQuery.Open;

    if not LMetaInfoQuery.IsEmpty then
    begin
      AList.BeginUpdate;
      try
        while not LMetaInfoQuery.Eof do
        begin
          AList.Add(LMetaInfoQuery.FieldByName('FKEY_NAME').AsString);
          LMetaInfoQuery.Next;
        end;
      finally
        AList.EndUpdate;
      end;
    end;

  finally
    LMetaInfoQuery.Free;
  end;
end;

function TProviderFirebird.FillIndexNames(const ATableName: string; AList: TStrings): IProviderDatabase;
begin
  Result := Self;
  if not Assigned(AList) then
    Exit;

  AList.Clear;
  FConnection.GetIndexNames(EmptyStr, EmptyStr, ATableName, EmptyStr, AList);
end;

function TProviderFirebird.FillPrimaryKeys(const ATableName: string; AList: TStrings): IProviderDatabase;
var
  LMetaInfoQuery: TFDMetaInfoQuery;
begin
  Result := Self;

  if not Assigned(AList) then
    Exit;

  AList.Clear;
  LMetaInfoQuery := TFDMetaInfoQuery.Create(FConnection);
  try
    LMetaInfoQuery.Connection := FConnection;
    LMetaInfoQuery.MetaInfoKind := mkPrimaryKey;
    LMetaInfoQuery.ObjectName := ATableName;
    LMetaInfoQuery.Open;

    if not LMetaInfoQuery.IsEmpty then
    begin
      AList.BeginUpdate;
      try
        while not LMetaInfoQuery.Eof do
        begin
          AList.Add(LMetaInfoQuery.FieldByName('CONSTRAINT_NAME').AsString);
          LMetaInfoQuery.Next;
        end;
      finally
        AList.EndUpdate;
      end;
    end;

  finally
    LMetaInfoQuery.Free;
  end;
end;

function TProviderFirebird.FillSequences(const AList: TStrings): IProviderDatabase;
var
  LMetaInfoQuery: TFDMetaInfoQuery;
begin

  Result := Self;

  if not Assigned(AList) then
    Exit;

  AList.Clear;

  LMetaInfoQuery := TFDMetaInfoQuery.Create(FConnection);
  try
    LMetaInfoQuery.Connection := FConnection;
    LMetaInfoQuery.MetaInfoKind := mkGenerators;
    LMetaInfoQuery.Open;

    if not LMetaInfoQuery.IsEmpty then
    begin
      AList.BeginUpdate;
      try
        while not LMetaInfoQuery.Eof do
        begin
          AList.Add(LMetaInfoQuery.FieldByName('GENERATOR_NAME').AsString);
          LMetaInfoQuery.Next;
        end;
      finally
        AList.EndUpdate;
      end;
    end;

  finally
    LMetaInfoQuery.Free;
  end;
end;

function TProviderFirebird.FillTableNames(const AList: TStrings): IProviderDatabase;
begin
  Result := Self;
  if not Assigned(AList) then
    Exit;
  AList.Clear;
  FConnection.GetTableNames(EmptyStr, EmptyStr, EmptyStr, AList, [osMy], [tkTable]);
end;

function TProviderFirebird.FillTriggers(const ATableName: string; AList: TStrings): IProviderDatabase;
var
  LQuery: TFDQuery;
begin

  Result := Self;

  if not Assigned(AList) then
    Exit;

  AList.Clear;

  LQuery := TFDQuery.Create(FConnection);
  try
    LQuery.Connection := FConnection;
    LQuery.SQL.Add('select');
    LQuery.SQL.Add('  TRIGGERS.RDB$TRIGGER_NAME as NAME');
    LQuery.SQL.Add('from');
    LQuery.SQL.Add('  RDB$TRIGGERS as TRIGGERS');
    LQuery.SQL.Add('where');
    LQuery.SQL.Add('  TRIGGERS.RDB$RELATION_NAME = :TABLE_NAME');
    LQuery.ParamByName('TABLE_NAME').AsString := ATableName;
    LQuery.Open;

    if not LQuery.IsEmpty then
    begin
      AList.BeginUpdate;
      try
        while not LQuery.Eof do
        begin
          AList.Add(LQuery.FieldByName('NAME').AsString);
          LQuery.Next;
        end;
      finally
        AList.EndUpdate;
      end;
    end;

  finally
    LQuery.Free;
  end;
end;

function TProviderFirebird.Execute: IProviderDatabase;
var
  LRowsAffected: integer;
begin
  Result := Execute(LRowsAffected);
end;

function TProviderFirebird.Open: IProviderDatabase;
begin
  Result := Self;
  if Assigned(FDataSet) then
  begin
    if FDataSet.Active then
    begin
      FDataSet.EmptyDataSet;
    end;
    FQuery.Open;
    FDataSet.CloneCursor(FQuery);
  end;
end;

procedure TProviderFirebird.LoadDatabaseParams;
var
  LDataBasePath: string;
  LIniFile: TIniFile;
begin

  if not FIniFilePath.Trim.IsEmpty then
  begin
    LIniFile := TIniFile.Create(FIniFilepath);
    try
      FConnectionInfo.Server := LIniFile.ReadString( 'database', 'server', '127.0.0.1' );
      FConnectionInfo.FileName := LIniFile.ReadString( 'database', 'name', '');
      FConnectionInfo.UserName := LIniFile.ReadString( 'database', 'username', 'sysdba');
      FConnectionInfo.Password := LIniFile.ReadString( 'database', 'password', 'masterkey');
    finally
      LIniFile.Free;
    end;
  end;

  if FConnectionInfo.FileName.Trim.IsEmpty then
    FConnectionInfo.FileName := ChangeFileExt(ParamStr(0), '.fdb');

  LDataBasePath := ExtractFilePath(FConnectionInfo.FileName);
  if not DirectoryExists(LDataBasePath) then
    ForceDirectories(LDataBasePath);

  if FConnection.Connected then
    FConnection.Close;

  FConnection.Params.Values['CreateDatabase'] := BoolToStr(not FileExists(FConnectionInfo.FileName), True);
  FConnection.Params.Values['Database']:= FConnectionInfo.FileName;
  FConnection.Params.Values['Server']:= FConnectionInfo.Server;
  FConnection.Params.UserName := FConnectionInfo.UserName;
  FConnection.Params.Password := FConnectionInfo.Password;
end;

function TProviderFirebird.SetBooleanParam(const AName: string; const AValue: Boolean): IProviderDatabase;
begin
  Result := Self;
  FQuery.ParamByName(AName).AsBoolean := AValue;
end;

function TProviderFirebird.SetCurrencyParam(const AName: string; const AValue: Currency): IProviderDatabase;
begin
  Result := Self;
  FQuery.ParamByName(AName).AsCurrency := AValue;
end;

function TProviderFirebird.SetDatabaseInfo(AInfo: TDatabaseInfo): IProviderDatabase;
begin
  Result := Self;
  FConnectionInfo := AInfo;
  FIniFilePath := '';
  LoadDatabaseParams;
end;

function TProviderFirebird.SetDataset(ADataSet: TFDMemTable): IProviderDatabase;
begin
  Result := Self;
  FDataSet := ADataSet;
end;

function TProviderFirebird.SetDateParam(const AName: string; const AValue: TDate): IProviderDatabase;
begin
  Result := Self;
  FQuery.ParamByName(AName).AsDate := AValue;
end;

function TProviderFirebird.SetDateTimeParam(const AName: string; const AValue: TDateTime): IProviderDatabase;
begin
  Result := Self;
  FQuery.ParamByName(AName).AsDateTime := AValue;
end;

function TProviderFirebird.SetFloatParam(const AName: string; const AValue: Double): IProviderDatabase;
begin
  Result := Self;
  FQuery.ParamByName(AName).AsFloat := AValue;
end;

function TProviderFirebird.SetIniFilePath(const AIniFilePath: string): IProviderDatabase;
begin
  Result := Self;
  FIniFilePath := AIniFilePath;
  LoadDatabaseParams;
end;

function TProviderFirebird.SetIntegerParam(const AName: string; const AValue: integer): IProviderDatabase;
begin
  Result := Self;
  FQuery.ParamByName(AName).AsInteger := AValue;
end;

function TProviderFirebird.SetSQL(const ASql: string): IProviderDatabase;
begin
  Result := Self;
  FQuery.SQL.Text := ASql;
end;

function TProviderFirebird.SetSQL(const ASql: TStrings): IProviderDatabase;
begin
  Result := SetSQL(ASql.Text);
end;

function TProviderFirebird.SetStringParam(const AName, AValue: string): IProviderDatabase;
begin
  Result := Self;
  FQuery.ParamByName(AName).AsString := AValue;
end;

function TProviderFirebird.SetTimeParam(const AName: string; const AValue: TTime): IProviderDatabase;
begin
  Result := Self;
  FQuery.ParamByName(AName).AsTime := AValue;
end;

function TProviderFirebird.StartTransaction: IProviderDatabase;
begin
  Result := Self;
  if not FConnection.InTransaction then
    FConnection.StartTransaction;
end;

function TProviderFirebird.InTransaction: Boolean;
begin
  Result := FConnection.InTransaction;
end;

function TProviderFirebird.Commit: IProviderDatabase;
begin
  if FConnection.InTransaction then
    FConnection.Commit;
end;

function TProviderFirebird.Rollback: IProviderDatabase;
begin
  if FConnection.InTransaction then
    FConnection.Rollback;
end;

end.
