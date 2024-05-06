unit Sco.Provider.Firebird;

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
    FConnectionInfo: TDatabaseInfo;
    // mais facil usar o FDQuery do que ter um obj de SQL e um de Param separados
    FQuery: TFDQuery;
    FDataSet: TProviderMemTable;
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

    function CreateTable(const ATable: ITable): IProviderDatabase; overload;
    function CreateTable(const ATable: ITable; const ADropIfExists: Boolean): IProviderDatabase; overload;
    function FieldExists(const ATableName, AFieldName: string): boolean;
    function TableExists(const ATableName: string): boolean;

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
  system.strutils,
  FireDAC.Phys.Intf,
  System.Generics.Collections,
  System.Generics.Defaults, FireDAC.Comp.DataSet;

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

  FQuery := TFDQuery.Create(FConnection);
  FQuery.Connection := FConnection;

  LoadDatabaseParams;
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

    Result := UpperCase(Result);
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

  if ADropIfExists then
  begin
    if TableExists(ATable.Name) then
    begin
      FConnection.ExecSQL('drop table ' + ATable.Name);
    end;
  end;

  LSqlScript := TStringList.Create;
  try

    if
      (not TableExists(ATable.Name)) and
      (ATable.Fields.HasPrimaryKey)
    then
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
          LPrimaryKeyFields := LPrimaryKeyFields + IfThen(LFieldCount > 1, ', ', EmptyStr) + LField.Name;
        end;
      end;
      LSqlScript.Add(');');
      FConnection.ExecSQL(LSqlScript.GetText);

      LSqlScript.Clear;
      LSqlScript.Add('alter table ' + ATable.Name + ' add constraint ' + UpperCase(ATable.Name) + '_PK primary key (' + LPrimaryKeyFields + ');');
      FConnection.ExecSQL(LSqlScript.GetText);

    end;

    LFieldListInDataBase := TStringList.Create;
    try
      FConnection.GetFieldNames(EmptyStr, EmptyStr, ATable.Name, EmptyStr, LFieldListInDataBase);

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
        for LField in LFields do
        begin
          if not LField.PrimaryKey then
          begin
            inc(i);
            LSqlScript.Add('    add ' + LField.Name + ' ' + GetSqlFieldType(LField) + IfThen(i < LFieldCount, ',', EmptyStr));
          end;
        end;
        LSqlScript.Add(';');
        FConnection.ExecSQL(LSqlScript.GetText);
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

procedure TProviderFirebird.LoadDatabaseParams;
var
  LIniFile: TIniFile;
  LConnectionString: string;
begin

  if not FIniFilePath.Trim.IsEmpty then
  begin
    LIniFile := TIniFile.Create(FIniFilepath);
    try
      FConnectionInfo.Server := LIniFile.ReadString( 'database', 'server', '127.0.0.1' );
      FConnectionInfo.Port := LIniFile.ReadInteger('database', 'port', 3050);
      FConnectionInfo.FileName := LIniFile.ReadString( 'database', 'name', '');
      FConnectionInfo.CharacterSet := LIniFile.ReadString( 'database', 'charset', 'UTF8');
      FConnectionInfo.Protocol := LIniFile.ReadString( 'database', 'protocol', 'TCPIP');
      FConnectionInfo.UserName := LIniFile.ReadString( 'database', 'username', 'sysdba');
      FConnectionInfo.Password := LIniFile.ReadString( 'database', 'password', 'masterkey');
    finally
      LIniFile.Free;
    end;
  end;

  if FConnectionInfo.Server.Trim.IsEmpty then
    FConnectionInfo.Server := '127.0.0.1';

  if FConnectionInfo.Port < 1 then
    FConnectionInfo.Port := 3050;

  if FConnectionInfo.FileName.Trim.IsEmpty then
    FConnectionInfo.FileName := ChangeFileExt(ParamStr(0), '.fdb');

  if FConnectionInfo.CharacterSet.Trim.IsEmpty then
    FConnectionInfo.CharacterSet := 'UTF8';

  if FConnectionInfo.Protocol.Trim.IsEmpty then
    FConnectionInfo.Protocol := 'TCPIP';

  if FConnectionInfo.UserName.Trim.IsEmpty then
    FConnectionInfo.UserName := 'SYSDBA';

  if FConnectionInfo.Password.Trim.IsEmpty then
    FConnectionInfo.Password := 'masterkey';

  LConnectionString :=
     'Database=' + FConnectionInfo.FileName + ';' +
     'User_Name=' + FConnectionInfo.UserName + ';' +
     'Password=' + FConnectionInfo.Password + ';' +
     'Server=' + FConnectionInfo.Server + ';' +
     'Port=' + FConnectionInfo.Port.ToString + ';' +
     'Protocol=' + FConnectionInfo.Protocol + ';' +
     'CharacterSet=' + FConnectionInfo.CharacterSet + ';' +
     'DriverID=FB';

  if FConnection.Connected then
    FConnection.Close;

  FConnection.ConnectionString := LConnectionString;

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

end.
