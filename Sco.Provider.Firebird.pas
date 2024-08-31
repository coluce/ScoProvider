﻿unit Sco.Provider.Firebird;

interface

uses
  Sco.Provider, Data.DB, FireDAC.Stan.Def, FireDAC.Phys.FBDef, FireDAC.Stan.Intf,
  FireDAC.Stan.ASync, FireDAC.Phys, FireDAC.Phys.IBBase, FireDAC.Phys.FB,
  FireDAC.DApt, FireDAC.Comp.Client, FireDAC.Stan.Param, FireDAC.VCLUI.Wait,
  System.Classes;

type

  TProviderFirebird = class(TInterfacedObject, IProviderDatabase)
  private
    FConnection: TFDConnection;
    FDatabaseInfo: IProviderDatabaseInfo;
    // mais facil usar o FDQuery do que ter um obj de SQL e um de Param separados
    FQuery: TFDQuery;
    FDataSet: TProviderMemTable;
    FIniFilePath: string;
    procedure DoBeforeConnect(Sender: TObject);
    procedure SetArrayParams(AParams: TArray<TScoParam>);
  public

    constructor Create;
    destructor Destroy; override;

    function DatabaseInfo: IProviderDatabaseInfo;

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

    function NewQuery: TProviderQuery;

    function ConnectionString: string;

    function Clear: IProviderDatabase;
    function SetSQL(const ASQL: string): IProviderDatabase; overload;
    function SetSQL(const ASQL: TStrings): IProviderDatabase; overload;

    function SetDateTimeParam(const AName: string; const AValue: TDateTime): IProviderDatabase;
    function SetDateParam(const AName: string; const AValue: TDate): IProviderDatabase;
    function SetTimeParam(const AName: string; const AValue: TTime): IProviderDatabase;

    function SetStringParam(const AName: string; const AValue: string): IProviderDatabase;
    function SetWideStringParam(const AName: string; const AValue: string): IProviderDatabase;
    function SetIntegerParam(const AName: string; const AValue: integer): IProviderDatabase;
    function SetFloatParam(const AName: string; const AValue: Double): IProviderDatabase;
    function SetCurrencyParam(const AName: string; const AValue: Currency): IProviderDatabase;
    function SetBooleanParam(const AName: string; const AValue: Boolean): IProviderDatabase;

    function SetDataSet(var ADataSet: TProviderMemTable): IProviderDatabase;

    function Open: IProviderDatabase; overload;
    function Open(AParams: TArray<TScoParam>): IProviderDatabase; overload;
    function Execute: IProviderDatabase; overload;
    function Execute(AParams: TArray<TScoParam>): IProviderDatabase; overload;
    function Execute(out ARowsAffected: integer): IProviderDatabase; overload;
    function Execute(out ARowsAffected: integer; AParams: TArray<TScoParam>): IProviderDatabase; overload;

    function StartTransaction: IProviderDatabase;
    function InTransaction: Boolean;
    function Commit: IProviderDatabase;
    function Rollback: IProviderDatabase;

  end;

implementation

uses
  System.IOUtils, System.IniFiles, System.SysUtils, System.Strutils,
  FireDAC.Phys.Intf, System.Generics.Collections, System.Generics.Defaults,
  FireDAC.Comp.DataSet;

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
  FConnection.BeforeConnect := DoBeforeConnect;

  FQuery := TFDQuery.Create(FConnection);
  FQuery.Connection := FConnection;

  FDatabaseInfo := TScoProvider.Info;
end;

function TProviderFirebird.CreateTable(const ATable: ITable): IProviderDatabase;
begin
  Result := Self.CreateTable(ATable, False);
end;

function TProviderFirebird.CreateTable(const ATable: ITable; const ADropIfExists: Boolean): IProviderDatabase;

  function GetSqlFieldType(const AField: IField): string;
  var
    LFieldType: string;
  begin
    Result := AField.FieldType;
    LFieldType := UpperCase(Result);
    if
      LFieldType.Equals('CHAR') or
      LFieldType.Equals('VARCHAR')
    then
    begin
      Result := Result + '(' + AField.FieldSize.ToString + ')';
      if not AField.CharacterSet.Trim.IsEmpty then
         Result := Result + ' CHARACTER SET ' + AField.CharacterSet;
    end;

    if
      LFieldType.Equals('BLOB SUB_TYPE 1') or
      LFieldType.Equals('BLOB SUB_TYPE TEXT')
    then
    begin
      if not AField.CharacterSet.Trim.IsEmpty then
         Result := Result + ' CHARACTER SET ' + AField.CharacterSet;
    end;

    if AField.NotNull then
      Result := Result + ' NOT NULL';

    Result := UpperCase(Result);
  end;

  procedure FillFieldsInDataBase(const AList: TStrings);
  var
    LFieldName: string;
    LList: TStrings;
  begin

    if not Assigned(AList) then
      Exit;

    AList.Clear;

    LList := TStringList.Create;
    try
      FConnection.GetFieldNames(EmptyStr, EmptyStr, ATable.Name, EmptyStr, LList);
      for LFieldName in LList do
      begin
        AList.Add(LFieldName.Replace('"', EmptyStr));
      end;
    finally
      LList.Free;
    end;
  end;

var
  LSqlScript: TStrings;
  LField: IField;
  LFields: TArray<IField>;
  LFieldsToCreate: TArray<IField>;
  LPrimaryKeyFields: string;
  LFieldCount: Integer;
  i: integer;
  LFieldListInDataBase: TStrings;
begin

  Result := Self;

  if not ATable.Fields.HasPrimaryKey then
    raise Exception.Create('No Primary Key for Table "' + ATable.Name + '".');

  if ADropIfExists then
  begin
    if TableExists(ATable.Name) then
    begin
      FConnection.ExecSQL('drop table ' + ATable.Name);
    end;
  end;

  LSqlScript := TStringList.Create;
  try

    if not TableExists(ATable.Name) then
    begin

      LFields := ATable.Fields.PrimaryKeys;

      { primary key info }
      LPrimaryKeyFields := EmptyStr;
      LFieldCount := ATable.Fields.PrimaryKeyCount;

      { table header }
      LSqlScript.Clear;
      LSqlScript.Add('create table ' + ATable.Name + ' (');
      i := 0;
      for LField in LFields do
      begin
        if LField.PrimaryKey then
        begin
          inc(i);
          LSqlScript.Add('    ' + LField.Name + ' ' + GetSqlFieldType(LField) + ' not null' + IfThen(i < LFieldCount, ',', EmptyStr));
          if LPrimaryKeyFields.Trim.IsEmpty then
            LPrimaryKeyFields := LField.Name
          else
            LPrimaryKeyFields := LPrimaryKeyFields + IfThen(LFieldCount > 1, ', ', EmptyStr) + LField.Name;
        end;
      end;
      LSqlScript.Add(');');
      FConnection.ExecSQL(LSqlScript.Text);

      LSqlScript.Clear;
      LSqlScript.Add('alter table ' + ATable.Name + ' add constraint ' + UpperCase(ATable.Name) + '_PK primary key (' + LPrimaryKeyFields + ');');
      FConnection.ExecSQL(LSqlScript.Text);

    end;

    LFieldListInDataBase := TStringList.Create;
    try
      FillFieldsInDataBase(LFieldListInDataBase);

      SetLength(LFieldsToCreate, 0);

      LFields := ATable.Fields.OrderedByIndex;
      for LField in LFields do
      begin
        if not LField.PrimaryKey then
        begin
          if LFieldListInDataBase.IndexOf(UpperCase(LField.Name)) = -1 then
          begin
            SetLength(LFieldsToCreate, Length(LFieldsToCreate) + 1);
            LFieldsToCreate[Length(LFieldsToCreate) - 1] := LField;
          end;
        end;
      end;

      LFieldCount := Length(LFieldsToCreate);
      if LFieldCount > 0 then
      begin
        LSqlScript.Clear;
        LSqlScript.Add('alter table ' + ATable.Name);
        i := 0;
        for LField in LFieldsToCreate do
        begin
          if not LField.PrimaryKey then
          begin
            inc(i);
            LSqlScript.Add('    add ' + LField.Name + ' ' + GetSqlFieldType(LField) + IfThen(i < LFieldCount, ',', EmptyStr));
          end;
        end;
        LSqlScript.Add(';');
        FConnection.ExecSQL(LSqlScript.Text);
      end;

    finally
      LFieldListInDataBase.Free;
    end;

  finally
    LSqlScript.Free;
  end;
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
  ARowsAffected := FConnection.ExecSQL(FQuery.SQL.Text, FQuery.Params);
end;

function TProviderFirebird.FieldExists(const ATableName, AFieldName: string): boolean;
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
          .Index(LMetaInfoQuery.FieldByName('COLUMN_POSITION').AsInteger)
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
var
  LDataSet: TFDQuery;
begin
  Result := Self;
  if Assigned(FDataSet) then
  begin
    LDataSet := TFDQuery.Create(FConnection);
    try
      LDataSet.Connection := FConnection;
      LDataSet.SQL.Text := FQuery.SQL.Text;
      LDataSet.Params.AssignValues(FQuery.Params);
      LDataSet.Open;

      FDataSet.CloneCursor(LDataSet);

      { esse execsql cria um novo fdquery lá dentro, causando um memory leak }
      //FConnection.ExecSQL(FQuery.SQL.Text, LDataSet);

    finally
      LDataSet.Free;
    end;
  end;
end;

procedure TProviderFirebird.DoBeforeConnect(Sender: TObject);
var
  LConnectionString: string;
begin

  if FDatabaseInfo.Server.Trim.IsEmpty then
    FDatabaseInfo.Server := '127.0.0.1';

  if FDatabaseInfo.Port < 1 then
    FDatabaseInfo.Port := 3050;

  if FDatabaseInfo.FileName.Trim.IsEmpty then
    FDatabaseInfo.FileName := ChangeFileExt(ParamStr(0), '.fdb');

  if FDatabaseInfo.CharacterSet.Trim.IsEmpty then
    FDatabaseInfo.CharacterSet := 'UTF8';

  if FDatabaseInfo.Protocol.Trim.IsEmpty then
    FDatabaseInfo.Protocol := 'TCPIP';

  if FDatabaseInfo.UserName.Trim.IsEmpty then
    FDatabaseInfo.UserName := 'SYSDBA';

  if FDatabaseInfo.Password.Trim.IsEmpty then
    FDatabaseInfo.Password := 'masterkey';

  LConnectionString :=
     'Database=' + FDatabaseInfo.FileName + ';' +
     'User_Name=' + FDatabaseInfo.UserName + ';' +
     'Password=' + FDatabaseInfo.Password + ';' +
     'Server=' + FDatabaseInfo.Server + ';' +
     'Port=' + FDatabaseInfo.Port.ToString + ';' +
     'Protocol=' + FDatabaseInfo.Protocol + ';' +
     'CharacterSet=' + FDatabaseInfo.CharacterSet + ';' +
     'DriverID=FB';

  if FConnection.Connected then
    FConnection.Close;

  FConnection.ConnectionString := LConnectionString;
//  FConnection.Params.Values['CreateDatabase'] := BoolToStr(True, True);

//  var LDataBasePath: string;

//  LDataBasePath := ExtractFilePath(FConnectionInfo.FileName);
//  if not DirectoryExists(LDataBasePath) then
//    ForceDirectories(LDataBasePath);

//  FConnection.Params.Values['CreateDatabase'] := BoolToStr(not FileExists(FConnectionInfo.FileName), True);
//  FConnection.DriverName := 'FB';
//  FConnection.Params.Values['CreateDatabase'] := BoolToStr(False, True);
//  FConnection.Params.Values['Database']:= FConnectionInfo.FileName;
//  FConnection.Params.Values['Server']:= FConnectionInfo.Server;
//  FConnection.Params.Values['Port']:= FConnectionInfo.Port.ToString;
//  FConnection.Params.Add('CharacterSet=UTF8');
//  FConnection.Params.UserName := FConnectionInfo.UserName;
//  FConnection.Params.Password := FConnectionInfo.Password;
end;

function TProviderFirebird.NewQuery: TProviderQuery;
begin
  Result := TProviderQuery.Create(FConnection);
  Result.Connection := FConnection;
end;

function TProviderFirebird.Open(AParams: TArray<TScoParam>): IProviderDatabase;
begin
  Result := Self;
  SetArrayParams(AParams);
  Open;
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

function TProviderFirebird.DatabaseInfo: IProviderDatabaseInfo;
begin
  Result := FDatabaseInfo;
end;

function TProviderFirebird.SetDataset(var ADataSet: TProviderMemTable): IProviderDatabase;
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

function TProviderFirebird.SetWideStringParam(const AName, AValue: string): IProviderDatabase;
begin
  Result := Self;
  FQuery.ParamByName(AName).AsWideString := AValue;
end;

function TProviderFirebird.StartTransaction: IProviderDatabase;
begin
  Result := Self;
  if not FConnection.InTransaction then
    FConnection.StartTransaction;
end;

function TProviderFirebird.TableExists(const ATableName: string): boolean;
var
  LList: TStrings;
begin
  LList := TStringList.Create;
  try
    FillTableNames(LList);
    Result := LList.IndexOf(ATableName) <> -1;
  finally
    LList.Free;
  end;
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

procedure TProviderFirebird.SetArrayParams(AParams: TArray<TScoParam>);
var
  LScoParam: TScoParam;
  LFieldParam: TFDParam;
begin
  for LScoParam in AParams do
  begin
    LFieldParam := FQuery.Params.FindParam(LScoParam.Name);
    if Assigned(LFieldParam) then
    begin
      case LScoParam.ParamType of
        ftUnknown: ;
        ftString: LFieldParam.AsString := LScoParam.Value;
        ftSmallint: LFieldParam.AsSmallInt := LScoParam.Value;
        ftInteger: LFieldParam.AsInteger := LScoParam.Value;
        ftWord: LFieldParam.AsWord := LScoParam.Value;
        ftBoolean: LFieldParam.AsBoolean := LScoParam.Value;
        ftFloat: LFieldParam.AsFloat := LScoParam.Value;
        ftCurrency: LFieldParam.AsCurrency := LScoParam.Value;
        ftBCD: LFieldParam.AsBCD := LScoParam.Value;
        ftDate: LFieldParam.AsDate := LScoParam.Value;
        ftTime: LFieldParam.AsTime := LScoParam.Value;
        ftDateTime: LFieldParam.AsDateTime := LScoParam.Value;
        ftBytes: ;
        ftVarBytes: ;
        ftAutoInc: ;
        ftBlob: LFieldParam.AsBlob := LScoParam.Value;
        ftMemo: LFieldParam.AsMemo := LScoParam.Value;
        ftGraphic: ;
        ftFmtMemo: ;
        ftParadoxOle: ;
        ftDBaseOle: ;
        ftTypedBinary: ;
        ftCursor: ;
        ftFixedChar: LFieldParam.AsFixedChar := LScoParam.Value;
        ftWideString: LFieldParam.AsWideString := LScoParam.Value;
        ftLargeint: LFieldParam.AsLargeInt := LScoParam.Value;
        ftADT: ;
        ftArray: ;
        ftReference: ;
        ftDataSet: ;
        ftOraBlob: ;
        ftOraClob: ;
        ftVariant: LFieldParam.Value := LScoParam.Value;
        ftInterface: ;
        ftIDispatch: ;
        ftGuid: ;
        ftTimeStamp: ;
        ftFMTBcd: ;
        ftFixedWideChar: ;
        ftWideMemo: LFieldParam.AsWideMemo := LScoParam.Value;
        ftOraTimeStamp: ;
        ftOraInterval: ;
        ftLongWord: LFieldParam.AsLongword := LScoParam.Value;
        ftShortint: LFieldParam.AsShortInt := LScoParam.Value;
        ftByte: LFieldParam.AsByte := LScoParam.Value;
        ftExtended: LFieldParam.AsExtended := LScoParam.Value;
        ftConnection: ;
        ftParams: ;
        ftStream: ;
        ftTimeStampOffset: ;
        ftObject: ;
        ftSingle: LFieldParam.AsSingle := LScoParam.Value;
      end;
    end;
  end;
end;

function TProviderFirebird.Execute(out ARowsAffected: integer; AParams: TArray<TScoParam>): IProviderDatabase;
begin
  Result := Self;
  SetArrayParams(AParams);
  Execute(ARowsAffected);
end;

function TProviderFirebird.Execute(AParams: TArray<TScoParam>): IProviderDatabase;
begin
  Result := Self;
  SetArrayParams(AParams);
  Execute;
end;

end.
