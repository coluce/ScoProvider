unit Sco.Provider.SQLite;

interface

uses
  Sco.Provider, Data.DB, FireDAC.Stan.Def, FireDAC.Phys.SQLiteDef, FireDAC.Stan.Intf,
  FireDAC.Stan.ASync, FireDAC.Phys, FireDAC.Phys.SQLite, FireDAC.DApt, 
  FireDAC.Comp.Client, FireDAC.Stan.Param, FireDAC.VCLUI.Wait, System.Classes;

type

  TProviderSQLite = class(TInterfacedObject, IProviderDatabase)
  private
    FConnection: TFDConnection;
    FDatabaseInfo: IProviderDatabaseInfo;
    FQuery: TFDQuery;
    FDataSet: TProviderMemTable;
    procedure DoBeforeConnect(Sender: TObject);
    procedure SetArrayParams(AParams: TArray<TScoParam>);
    function GetSQLiteFieldType(const AField: IField): string;
    function SQLiteTypeToDelphiType(const ASQLiteType: string): TFieldType;
  public

    constructor Create;
    destructor Destroy; override;

    function DatabaseInfo: IProviderDatabaseInfo;
    function DatabaseType: TDatabaseType;

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
    function CheckConnection: Boolean;
  end;

implementation

uses
  System.IOUtils, System.SysUtils, System.Strutils, FireDAC.Phys.Intf, 
  System.Generics.Collections, System.Generics.Defaults, FireDAC.Comp.DataSet;

{ TProviderSQLite }

function TProviderSQLite.CheckConnection: Boolean;
begin
  try
    FConnection.CheckOnline;
    Result := True;
  except
    Result := False;
  end;
end;

function TProviderSQLite.Clear: IProviderDatabase;
begin
  Result := Self;
  FDataSet := nil;
  if FQuery.Active then
    FQuery.Close;
  FQuery.SQL.Clear;
end;

function TProviderSQLite.ConnectionString: string;
begin
  Result := FConnection.ConnectionString;
end;

constructor TProviderSQLite.Create;
begin
  FConnection := TFDConnection.Create(nil);
  FConnection.BeforeConnect := DoBeforeConnect;

  FQuery := TFDQuery.Create(FConnection);
  FQuery.Connection := FConnection;

  FDatabaseInfo := TScoProvider.Info;
end;

function TProviderSQLite.CreateTable(const ATable: ITable): IProviderDatabase;
begin
  Result := Self.CreateTable(ATable, False);
end;

function TProviderSQLite.CreateTable(const ATable: ITable; const ADropIfExists: Boolean): IProviderDatabase;

  procedure FillFieldsInDatabase(const AList: TStrings);
  var
    LQuery: TFDQuery;
  begin
    if not Assigned(AList) then
      Exit;

    AList.Clear;

    LQuery := TFDQuery.Create(FConnection);
    try
      LQuery.Connection := FConnection;
      LQuery.SQL.Text := 'PRAGMA table_info(' + QuotedStr(ATable.Name) + ')';
      LQuery.Open;

      if not LQuery.IsEmpty then
      begin
        LQuery.First;
        while not LQuery.Eof do
        begin
          AList.Add(LQuery.FieldByName('name').AsString);
          LQuery.Next;
        end;
      end;
    finally
      LQuery.Free;
    end;
  end;

  procedure CreateForeignKeys;
  var
    LSqlScript: TStrings;
    LForeignKey: ITableForeignKey;
    LAction: string;
  begin
    if ATable.ForeignKeys.Count < 1 then
      Exit;

    // SQLite só suporta foreign keys se estiver habilitado
    FConnection.ExecSQL('PRAGMA foreign_keys = ON');

    LSqlScript := TStringList.Create;
    try
      for LForeignKey in ATable.ForeignKeys.Values do
      begin
        LSqlScript.Clear;
        LSqlScript.Add('ALTER TABLE ' + ATable.Name + ' ADD CONSTRAINT ' + LForeignKey.Name);
        LSqlScript.Add('  FOREIGN KEY (' + LForeignKey.Keys + ')');
        LSqlScript.Add('  REFERENCES ' + LForeignKey.RefrenceTable + ' (' + LForeignKey.RefrenceKeys + ')');

        // SQLite suporta CASCADE, SET NULL, RESTRICT, mas não todas as opções do Firebird
        case LForeignKey.OnDelete of
          Cascade: LAction := 'CASCADE';
          SetNull: LAction := 'SET NULL';
          Restrict: LAction := 'RESTRICT';
          else LAction := 'NO ACTION';
        end;
        LSqlScript.Add('  ON DELETE ' + LAction);

        case LForeignKey.OnUpdate of
          Cascade: LAction := 'CASCADE';
          SetNull: LAction := 'SET NULL';
          Restrict: LAction := 'RESTRICT';
          else LAction := 'NO ACTION';
        end;
        LSqlScript.Add('  ON UPDATE ' + LAction);

        try
          FConnection.ExecSQL(LSqlScript.Text);
        except
          on E: Exception do
            raise Exception.Create('Erro ao criar foreign key "' + LForeignKey.Name + '": ' + E.Message + 
              '. Nota: SQLite tem limitações para adicionar foreign keys em tabelas existentes.');
        end;
      end;
    finally
      LSqlScript.Free;
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
  LFieldListInDatabase: TStrings;
begin
  Result := Self;

  if not ATable.Fields.HasPrimaryKey then
    raise Exception.Create('Nenhuma chave primária definida para a tabela "' + ATable.Name + '".');

  if ADropIfExists then
    if TableExists(ATable.Name) then
      FConnection.ExecSQL('DROP TABLE IF EXISTS ' + ATable.Name);

  LSqlScript := TStringList.Create;
  try
    if not TableExists(ATable.Name) then
    begin
      LFields := ATable.Fields.OrderedByIndex;
      
      // Construir campos da chave primária
      LPrimaryKeyFields := '';
      for LField in LFields do
      begin
        if LField.PrimaryKey then
        begin
          if LPrimaryKeyFields <> '' then
            LPrimaryKeyFields := LPrimaryKeyFields + ', ';
          LPrimaryKeyFields := LPrimaryKeyFields + LField.Name;
        end;
      end;

      // Criar tabela
      LSqlScript.Clear;
      LSqlScript.Add('CREATE TABLE ' + ATable.Name + ' (');
      
      i := 0;
      for LField in LFields do
      begin
        if i > 0 then
          LSqlScript.Add(',');
        LSqlScript.Add('  ' + LField.Name + ' ' + GetSQLiteFieldType(LField));
        Inc(i);
      end;
      
      LSqlScript.Add(', PRIMARY KEY (' + LPrimaryKeyFields + ')');
      LSqlScript.Add(')');
      
      FConnection.ExecSQL(LSqlScript.Text);
    end
    else
    begin
      // SQLite não suporta ALTER TABLE ADD COLUMN com todas as opções
      // Vamos tentar adicionar campos simples
      LFieldListInDatabase := TStringList.Create;
      try
        FillFieldsInDatabase(LFieldListInDatabase);

        SetLength(LFieldsToCreate, 0);
        LFields := ATable.Fields.OrderedByIndex;
        
        for LField in LFields do
        begin
          if not LField.PrimaryKey then
          begin
            if LFieldListInDatabase.IndexOf(LField.Name) = -1 then
            begin
              SetLength(LFieldsToCreate, Length(LFieldsToCreate) + 1);
              LFieldsToCreate[Length(LFieldsToCreate) - 1] := LField;
            end;
          end;
        end;

        // Adicionar novos campos (SQLite tem limitações aqui)
        for LField in LFieldsToCreate do
        begin
          try
            LSqlScript.Clear;
            LSqlScript.Add('ALTER TABLE ' + ATable.Name);
            LSqlScript.Add('ADD COLUMN ' + LField.Name + ' ' + GetSQLiteFieldType(LField));
            FConnection.ExecSQL(LSqlScript.Text);
          except
            on E: Exception do
              raise Exception.Create('Erro ao adicionar campo "' + LField.Name + '": ' + E.Message + 
                '. SQLite tem limitações para ALTER TABLE.');
          end;
        end;

      finally
        LFieldListInDatabase.Free;
      end;
    end;

    // Criar foreign keys (se a tabela foi criada agora)
    if not ADropIfExists then
      CreateForeignKeys;

  finally
    LSqlScript.Free;
  end;
end;

destructor TProviderSQLite.Destroy;
begin
  FQuery.Free;

  if FConnection.Connected then
    FConnection.Connected := False;

  FConnection.Free;
  inherited;
end;

procedure TProviderSQLite.DoBeforeConnect(Sender: TObject);

  procedure SetDatabaseExtension;
  begin
    case Self.DatabaseType of
      Firebird: FDatabaseInfo.FileName := FDatabaseInfo.FileName.Trim + '.fdb';
      SQLite: FDatabaseInfo.FileName := FDatabaseInfo.FileName.Trim + '.db';
    end;
  end;

var
  LConnectionString: string;
  LDatabasePath: string;
  LDatabaseExtension: string;
begin
  if FDatabaseInfo.FileName.Trim.IsEmpty then
    SetDatabaseExtension;

  LDatabaseExtension := ExtractFileExt(FDatabaseInfo.FileName);
  if LDatabaseExtension.Trim.IsEmpty then
    SetDatabaseExtension;

  LDatabasePath := ExtractFilePath(FDatabaseInfo.FileName);
  if not LDatabasePath.Trim.IsEmpty then
    if not DirectoryExists(LDatabasePath) then
      ForceDirectories(LDatabasePath);

  LConnectionString :=
     'Database=' + FDatabaseInfo.FileName + ';' +
     'DriverID=SQLite';

  if FConnection.Connected then
    FConnection.Close;

  FConnection.ConnectionString := LConnectionString;
end;

function TProviderSQLite.Execute(out ARowsAffected: integer): IProviderDatabase;
begin
  Result := Self;
  ARowsAffected := FConnection.ExecSQL(FQuery.SQL.Text, FQuery.Params);
end;

function TProviderSQLite.Execute: IProviderDatabase;
var
  LRowsAffected: integer;
begin
  Result := Execute(LRowsAffected);
end;

function TProviderSQLite.Execute(AParams: TArray<TScoParam>): IProviderDatabase;
begin
  Result := Self;
  SetArrayParams(AParams);
  Execute;
end;

function TProviderSQLite.Execute(out ARowsAffected: integer; AParams: TArray<TScoParam>): IProviderDatabase;
begin
  Result := Self;
  SetArrayParams(AParams);
  Execute(ARowsAffected);
end;

function TProviderSQLite.FieldExists(const ATableName, AFieldName: string): boolean;
var
  LQuery: TFDQuery;
begin
  Result := False;
  LQuery := TFDQuery.Create(FConnection);
  try
    LQuery.Connection := FConnection;
    LQuery.SQL.Text := 'PRAGMA table_info(' + QuotedStr(ATableName) + ')';
    LQuery.Open;

    if not LQuery.IsEmpty then
    begin
      LQuery.First;
      while not LQuery.Eof do
      begin
        if SameText(LQuery.FieldByName('name').AsString, AFieldName) then
        begin
          Result := True;
          Break;
        end;
        LQuery.Next;
      end;
    end;
  finally
    LQuery.Free;
  end;
end;

function TProviderSQLite.FillFieldNames(const ATableName: string; AList: TStrings): IProviderDatabase;
var
  LQuery: TFDQuery;
begin
  Result := Self;

  if not Assigned(AList) then
    Exit;

  if ATableName.Trim.IsEmpty then
    Exit;

  AList.Clear;
  LQuery := TFDQuery.Create(FConnection);
  try
    LQuery.Connection := FConnection;
    LQuery.SQL.Text := 'PRAGMA table_info(' + QuotedStr(ATableName) + ')';
    LQuery.Open;

    if not LQuery.IsEmpty then
    begin
      LQuery.First;
      while not LQuery.Eof do
      begin
        AList.Add(LQuery.FieldByName('name').AsString);
        LQuery.Next;
      end;
    end;
  finally
    LQuery.Free;
  end;
end;

function TProviderSQLite.FillFields(const ATable: ITable): IProviderDatabase;
var
  LQuery: TFDQuery;
  LField: IField;
  LFieldName, LFieldType: string;
  LIsPK, LIsNotNull: Boolean;
begin
  Result := Self;
  
  if not Assigned(ATable) then
    Exit;

  ATable.Fields.Clear;

  LQuery := TFDQuery.Create(FConnection);
  try
    LQuery.Connection := FConnection;
    LQuery.SQL.Text := 'PRAGMA table_info(' + QuotedStr(ATable.Name) + ')';
    LQuery.Open;

    if not LQuery.IsEmpty then
    begin
      LQuery.First;
      while not LQuery.Eof do
      begin
        LFieldName := LQuery.FieldByName('name').AsString;
        LFieldType := LQuery.FieldByName('type').AsString;
        LIsNotNull := LQuery.FieldByName('notnull').AsInteger = 1;
        LIsPK := LQuery.FieldByName('pk').AsInteger = 1;

        LField := TStructureDomain.Field
          .Index(LQuery.FieldByName('cid').AsInteger)
          .Name(LFieldName)
          .FieldType(LFieldType)
          .NotNull(LIsNotNull)
          .PrimaryKey(LIsPK);

        ATable.Fields.Add(LFieldName, LField);
        LQuery.Next;
      end;
    end;

  finally
    LQuery.Free;
  end;
end;

function TProviderSQLite.FillForeignKeys(const ATableName: string; AList: TStrings): IProviderDatabase;
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
    LQuery.SQL.Text := 'PRAGMA foreign_key_list(' + QuotedStr(ATableName) + ')';
    LQuery.Open;

    if not LQuery.IsEmpty then
    begin
      AList.BeginUpdate;
      try
        while not LQuery.Eof do
        begin
          AList.Add(LQuery.FieldByName('from').AsString + ' -> ' + 
                   LQuery.FieldByName('table').AsString + '(' + 
                   LQuery.FieldByName('to').AsString + ')');
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

function TProviderSQLite.FillIndexNames(const ATableName: string; AList: TStrings): IProviderDatabase;
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
    LQuery.SQL.Text := 'PRAGMA index_list(' + QuotedStr(ATableName) + ')';
    LQuery.Open;

    if not LQuery.IsEmpty then
    begin
      AList.BeginUpdate;
      try
        while not LQuery.Eof do
        begin
          AList.Add(LQuery.FieldByName('name').AsString);
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

function TProviderSQLite.FillPrimaryKeys(const ATableName: string; AList: TStrings): IProviderDatabase;
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
    LQuery.SQL.Text := 'PRAGMA table_info(' + QuotedStr(ATableName) + ')';
    LQuery.Open;

    if not LQuery.IsEmpty then
    begin
      AList.BeginUpdate;
      try
        while not LQuery.Eof do
        begin
          if LQuery.FieldByName('pk').AsInteger = 1 then
            AList.Add(LQuery.FieldByName('name').AsString);
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

function TProviderSQLite.FillSequences(const AList: TStrings): IProviderDatabase;
begin
  Result := Self;

  if not Assigned(AList) then
    Exit;

  AList.Clear;
  
  // SQLite não tem sequences como Firebird, mas tem AUTOINCREMENT
  // Podemos listar tabelas que têm campos AUTOINCREMENT
  raise Exception.Create('SQLite não suporta sequences. Use AUTOINCREMENT em campos INTEGER PRIMARY KEY.');
end;

function TProviderSQLite.FillTableNames(const AList: TStrings): IProviderDatabase;
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
    LQuery.SQL.Text := 'SELECT name FROM sqlite_master WHERE type = ''table'' AND name NOT LIKE ''sqlite_%''';
    LQuery.Open;

    if not LQuery.IsEmpty then
    begin
      AList.BeginUpdate;
      try
        while not LQuery.Eof do
        begin
          AList.Add(LQuery.FieldByName('name').AsString);
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

function TProviderSQLite.FillTriggers(const ATableName: string; AList: TStrings): IProviderDatabase;
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
    LQuery.SQL.Text := 'SELECT name FROM sqlite_master WHERE type = ''trigger'' AND tbl_name = ' + QuotedStr(ATableName);
    LQuery.Open;

    if not LQuery.IsEmpty then
    begin
      AList.BeginUpdate;
      try
        while not LQuery.Eof do
        begin
          AList.Add(LQuery.FieldByName('name').AsString);
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

function TProviderSQLite.GetSQLiteFieldType(const AField: IField): string;
var
  LFieldType: string;
begin
  LFieldType := UpperCase(AField.FieldType);
  
  // Mapear tipos Firebird para SQLite
  if LFieldType = 'INTEGER' then
    Result := 'INTEGER'
  else if (LFieldType = 'VARCHAR') or (LFieldType = 'CHAR') then
  begin
    if AField.FieldSize > 0 then
      Result := 'VARCHAR(' + AField.FieldSize.ToString + ')'
    else
      Result := 'TEXT';
  end
  else if (LFieldType = 'NUMERIC') or (LFieldType.StartsWith('NUMERIC(')) then
    Result := 'REAL'
  else if LFieldType = 'TIMESTAMP' then
    Result := 'DATETIME'
  else if LFieldType = 'BOOLEAN' then
    Result := 'BOOLEAN'
  else if (LFieldType = 'BLOB SUB_TYPE 0 SEGMENT SIZE 80') or 
          (LFieldType.StartsWith('BLOB')) then
    Result := 'BLOB'
  else if (LFieldType = 'BLOB SUB_TYPE TEXT SEGMENT SIZE 80') or
          (LFieldType = 'BLOB SUB_TYPE 1') or
          (LFieldType = 'BLOB SUB_TYPE TEXT') then
    Result := 'TEXT'
  else
    Result := 'TEXT'; // Padrão para tipos não reconhecidos

  // SQLite não suporta CHARACTER SET, ignorar
  // if not AField.CharacterSet.Trim.IsEmpty then
  //   // SQLite usa UTF-8 por padrão

  if AField.NotNull then
    Result := Result + ' NOT NULL';
end;

function TProviderSQLite.DatabaseInfo: IProviderDatabaseInfo;
begin
  Result := FDatabaseInfo;
end;

function TProviderSQLite.DatabaseType: TDatabaseType;
begin
  Result := TDatabaseType.SQLite;
end;

function TProviderSQLite.NewQuery: TProviderQuery;
begin
  Result := TProviderQuery.Create(FConnection);
  Result.Connection := FConnection;
end;

function TProviderSQLite.Open: IProviderDatabase;
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

    finally
      LDataSet.Free;
    end;
  end;
end;

function TProviderSQLite.Open(AParams: TArray<TScoParam>): IProviderDatabase;
begin
  Result := Self;
  SetArrayParams(AParams);
  Open;
end;

procedure TProviderSQLite.SetArrayParams(AParams: TArray<TScoParam>);
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
        ftString: LFieldParam.AsString := LScoParam.Value;
        ftWideString: LFieldParam.AsWideString := LScoParam.Value;
        ftInteger: LFieldParam.AsInteger := LScoParam.Value;
        ftSmallint: LFieldParam.AsSmallInt := LScoParam.Value;
        ftLargeint: LFieldParam.AsLargeInt := LScoParam.Value;
        ftFloat: LFieldParam.AsFloat := LScoParam.Value;
        ftCurrency: LFieldParam.AsCurrency := LScoParam.Value;
        ftBCD: LFieldParam.AsBCD := LScoParam.Value;
        ftDate: LFieldParam.AsDate := LScoParam.Value;
        ftTime: LFieldParam.AsTime := LScoParam.Value;
        ftDateTime: LFieldParam.AsDateTime := LScoParam.Value;
        ftBoolean: LFieldParam.AsBoolean := LScoParam.Value;
        ftBlob: LFieldParam.AsBlob := LScoParam.Value;
        ftMemo: LFieldParam.AsMemo := LScoParam.Value;
        ftWideMemo: LFieldParam.AsWideMemo := LScoParam.Value;
        ftSingle: LFieldParam.AsSingle := LScoParam.Value;
      end;
    end;
  end;
end;

function TProviderSQLite.SetBooleanParam(const AName: string; const AValue: Boolean): IProviderDatabase;
begin
  Result := Self;
  FQuery.ParamByName(AName).AsBoolean := AValue;
end;

function TProviderSQLite.SetCurrencyParam(const AName: string; const AValue: Currency): IProviderDatabase;
begin
  Result := Self;
  FQuery.ParamByName(AName).AsCurrency := AValue;
end;

function TProviderSQLite.SetDataset(var ADataSet: TProviderMemTable): IProviderDatabase;
begin
  Result := Self;
  FDataSet := ADataSet;
end;

function TProviderSQLite.SetDateParam(const AName: string; const AValue: TDate): IProviderDatabase;
begin
  Result := Self;
  FQuery.ParamByName(AName).AsDate := AValue;
end;

function TProviderSQLite.SetDateTimeParam(const AName: string; const AValue: TDateTime): IProviderDatabase;
begin
  Result := Self;
  FQuery.ParamByName(AName).AsDateTime := AValue;
end;

function TProviderSQLite.SetFloatParam(const AName: string; const AValue: Double): IProviderDatabase;
begin
  Result := Self;
  FQuery.ParamByName(AName).AsFloat := AValue;
end;

function TProviderSQLite.SetIntegerParam(const AName: string; const AValue: integer): IProviderDatabase;
begin
  Result := Self;
  FQuery.ParamByName(AName).AsInteger := AValue;
end;

function TProviderSQLite.SetSQL(const ASql: string): IProviderDatabase;
begin
  Result := Self;
  FQuery.SQL.Text := ASql;
end;

function TProviderSQLite.SetSQL(const ASql: TStrings): IProviderDatabase;
begin
  Result := SetSQL(ASql.Text);
end;

function TProviderSQLite.SetStringParam(const AName, AValue: string): IProviderDatabase;
begin
  Result := Self;
  FQuery.ParamByName(AName).AsString := AValue;
end;

function TProviderSQLite.SetTimeParam(const AName: string; const AValue: TTime): IProviderDatabase;
begin
  Result := Self;
  FQuery.ParamByName(AName).AsTime := AValue;
end;

function TProviderSQLite.SetWideStringParam(const AName, AValue: string): IProviderDatabase;
begin
  Result := Self;
  FQuery.ParamByName(AName).AsWideString := AValue;
end;

function TProviderSQLite.SQLiteTypeToDelphiType(const ASQLiteType: string): TFieldType;
var
  LType: string;
begin
  LType := UpperCase(ASQLiteType);
  
  if (LType = 'INTEGER') or (LType = 'INT') then
    Result := ftInteger
  else if (LType = 'REAL') or (LType = 'FLOAT') or (LType = 'DOUBLE') then
    Result := ftFloat
  else if (LType = 'TEXT') or (LType.StartsWith('VARCHAR')) or (LType.StartsWith('CHAR')) then
    Result := ftString
  else if (LType = 'BLOB') then
    Result := ftBlob
  else if (LType = 'DATETIME') or (LType = 'TIMESTAMP') then
    Result := ftDateTime
  else if (LType = 'BOOLEAN') then
    Result := ftBoolean
  else
    Result := ftString; // Padrão
end;

function TProviderSQLite.StartTransaction: IProviderDatabase;
begin
  Result := Self;
  if not FConnection.InTransaction then
    FConnection.StartTransaction;
end;

function TProviderSQLite.TableExists(const ATableName: string): boolean;
var
  LQuery: TFDQuery;
begin
  Result := False;
  LQuery := TFDQuery.Create(FConnection);
  try
    LQuery.Connection := FConnection;
    LQuery.SQL.Text := 'SELECT name FROM sqlite_master WHERE type = ''table'' AND name = ' + QuotedStr(ATableName);
    LQuery.Open;
    Result := not LQuery.IsEmpty;
  finally
    LQuery.Free;
  end;
end;

function TProviderSQLite.InTransaction: Boolean;
begin
  Result := FConnection.InTransaction;
end;

function TProviderSQLite.Commit: IProviderDatabase;
begin
  Result := Self;
  if FConnection.InTransaction then
    FConnection.Commit;
end;

function TProviderSQLite.Rollback: IProviderDatabase;
begin
  Result := Self;
  if FConnection.InTransaction then
    FConnection.Rollback;
end;

end.