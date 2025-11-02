unit TestSQLiteProvider;

interface

uses
  TestFramework, Sco.Provider, System.Classes, Data.DB, System.SysUtils;

type
  TTestSQLiteProvider = class(TTestCase)
  private
    FDatabase: IProviderDatabase;
    FTestDBFile: string;
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure TestConnection;
    procedure TestCreateTable;
    procedure TestTableExists;
    procedure TestFieldExists;
    procedure TestInsertAndSelect;
    procedure TestTransaction;
    procedure TestFillTableNames;
    procedure TestFillFieldNames;
    procedure TestFillPrimaryKeys;
    procedure TestSequencesNotSupported;
    procedure TestFieldTypes;
    procedure TestBooleanFields;
    procedure TestDateTimeFields;
    procedure TestForeignKeyLimitations;
  end;

implementation

uses
  Sco.Provider.SQLite, System.IOUtils;

{ TTestSQLiteProvider }

procedure TTestSQLiteProvider.SetUp;
begin
  inherited;
  FTestDBFile := TPath.Combine(TPath.GetTempPath, 'test_sqlite.db');
  
  // Remove arquivo se existir
  if TFile.Exists(FTestDBFile) then
    TFile.Delete(FTestDBFile);
    
  FDatabase := TScoProvider.SQLite;
  FDatabase.DatabaseInfo.FileName := FTestDBFile;
end;

procedure TTestSQLiteProvider.TearDown;
begin
  FDatabase := nil;
  
  // Limpar arquivo de teste
  if TFile.Exists(FTestDBFile) then
    TFile.Delete(FTestDBFile);
    
  inherited;
end;

procedure TTestSQLiteProvider.TestConnection;
begin
  CheckNotNull(FDatabase, 'Database instance should not be nil');
  CheckEquals(FTestDBFile, FDatabase.DatabaseInfo.FileName, 'Database filename should match');
end;

procedure TTestSQLiteProvider.TestCreateTable;
var
  LTable: ITable;
begin
  LTable := TStructureDomain.Table;
  LTable.Name('TEST_CREATE');
  
  LTable.Fields
    .AddIntegerField(1, 'ID')
      .PrimaryKey(True)
      .NotNull(True);
  LTable.Fields.AddStringField(2, 'NAME', 50);
  
  CheckNoException(
    procedure
    begin
      FDatabase.CreateTable(LTable, True);
    end,
    'Should create table without exceptions'
  );
  
  CheckTrue(FDatabase.TableExists('TEST_CREATE'), 'Table should exist after creation');
end;

procedure TTestSQLiteProvider.TestTableExists;
var
  LTable: ITable;
begin
  CheckFalse(FDatabase.TableExists('NONEXISTENT'), 'Non-existent table should return false');
  
  LTable := TStructureDomain.Table;
  LTable.Name('TEST_EXISTS');
  LTable.Fields.AddIntegerField(1, 'ID').PrimaryKey(True);
  
  FDatabase.CreateTable(LTable, True);
  CheckTrue(FDatabase.TableExists('TEST_EXISTS'), 'Created table should exist');
end;

procedure TTestSQLiteProvider.TestFieldExists;
var
  LTable: ITable;
begin
  LTable := TStructureDomain.Table;
  LTable.Name('TEST_FIELD_EXISTS');
  LTable.Fields.AddIntegerField(1, 'ID').PrimaryKey(True);
  LTable.Fields.AddStringField(2, 'NAME', 50);
  
  FDatabase.CreateTable(LTable, True);
  
  CheckTrue(FDatabase.FieldExists('TEST_FIELD_EXISTS', 'ID'), 'ID field should exist');
  CheckTrue(FDatabase.FieldExists('TEST_FIELD_EXISTS', 'NAME'), 'NAME field should exist');
  CheckFalse(FDatabase.FieldExists('TEST_FIELD_EXISTS', 'NONEXISTENT'), 'Non-existent field should return false');
end;

procedure TTestSQLiteProvider.TestInsertAndSelect;
var
  LTable: ITable;
  LDataSet: TProviderMemTable;
  LRowsAffected: Integer;
begin
  // Criar tabela
  LTable := TStructureDomain.Table;
  LTable.Name('TEST_INSERT_SELECT');
  LTable.Fields.AddIntegerField(1, 'ID').PrimaryKey(True);
  LTable.Fields.AddStringField(2, 'NAME', 100);
  
  FDatabase.CreateTable(LTable, True);
  
  // Inserir dados
  FDatabase
    .Clear
    .SetSQL('INSERT INTO TEST_INSERT_SELECT (ID, NAME) VALUES (?, ?)')
    .SetIntegerParam('P1', 1)
    .SetStringParam('P2', 'Test Name')
    .Execute(LRowsAffected);
    
  CheckEquals(1, LRowsAffected, 'Should affect 1 row');
  
  // Selecionar dados
  LDataSet := TProviderMemTable.Create(nil);
  try
    FDatabase
      .Clear
      .SetSQL('SELECT * FROM TEST_INSERT_SELECT WHERE ID = ?')
      .SetIntegerParam('P1', 1)
      .SetDataset(LDataSet)
      .Open;
      
    CheckFalse(LDataSet.IsEmpty, 'Dataset should not be empty');
    CheckEquals(1, LDataSet.FieldByName('ID').AsInteger, 'ID should be 1');
    CheckEquals('Test Name', LDataSet.FieldByName('NAME').AsString, 'Name should match');
    
  finally
    LDataSet.Free;
  end;
end;

procedure TTestSQLiteProvider.TestTransaction;
var
  LTable: ITable;
  LDataSet: TProviderMemTable;
begin
  // Criar tabela
  LTable := TStructureDomain.Table;
  LTable.Name('TEST_TRANSACTION');
  LTable.Fields.AddIntegerField(1, 'ID').PrimaryKey(True);
  LTable.Fields.AddStringField(2, 'NAME', 50);
  
  FDatabase.CreateTable(LTable, True);
  
  // Test commit
  FDatabase.StartTransaction;
  CheckTrue(FDatabase.InTransaction, 'Should be in transaction');
  
  FDatabase
    .Clear
    .SetSQL('INSERT INTO TEST_TRANSACTION (ID, NAME) VALUES (1, ''Test'')')
    .Execute;
    
  FDatabase.Commit;
  CheckFalse(FDatabase.InTransaction, 'Should not be in transaction after commit');
  
  // Verificar se dados foram commitados
  LDataSet := TProviderMemTable.Create(nil);
  try
    FDatabase
      .Clear
      .SetSQL('SELECT COUNT(*) as CNT FROM TEST_TRANSACTION')
      .SetDataset(LDataSet)
      .Open;
      
    CheckEquals(1, LDataSet.FieldByName('CNT').AsInteger, 'Should have 1 record after commit');
  finally
    LDataSet.Free;
  end;
  
  // Test rollback
  FDatabase.StartTransaction;
  FDatabase
    .Clear
    .SetSQL('INSERT INTO TEST_TRANSACTION (ID, NAME) VALUES (2, ''Test2'')')
    .Execute;
    
  FDatabase.Rollback;
  
  // Verificar se rollback funcionou
  LDataSet := TProviderMemTable.Create(nil);
  try
    FDatabase
      .Clear
      .SetSQL('SELECT COUNT(*) as CNT FROM TEST_TRANSACTION')
      .SetDataset(LDataSet)
      .Open;
      
    CheckEquals(1, LDataSet.FieldByName('CNT').AsInteger, 'Should still have 1 record after rollback');
  finally
    LDataSet.Free;
  end;
end;

procedure TTestSQLiteProvider.TestFillTableNames;
var
  LTable: ITable;
  LTableNames: TStringList;
begin
  LTableNames := TStringList.Create;
  try
    // Inicialmente sem tabelas
    FDatabase.FillTableNames(LTableNames);
    CheckEquals(0, LTableNames.Count, 'Should have no tables initially');
    
    // Criar uma tabela
    LTable := TStructureDomain.Table;
    LTable.Name('TEST_TABLE_NAMES');
    LTable.Fields.AddIntegerField(1, 'ID').PrimaryKey(True);
    
    FDatabase.CreateTable(LTable, True);
    
    // Verificar se aparece na lista
    FDatabase.FillTableNames(LTableNames);
    CheckEquals(1, LTableNames.Count, 'Should have 1 table');
    CheckEquals('TEST_TABLE_NAMES', LTableNames[0], 'Table name should match');
    
  finally
    LTableNames.Free;
  end;
end;

procedure TTestSQLiteProvider.TestFillFieldNames;
var
  LTable: ITable;
  LFieldNames: TStringList;
begin
  // Criar tabela com campos
  LTable := TStructureDomain.Table;
  LTable.Name('TEST_FIELD_NAMES');
  LTable.Fields.AddIntegerField(1, 'ID').PrimaryKey(True);
  LTable.Fields.AddStringField(2, 'NAME', 50);
  LTable.Fields.AddBooleanField(3, 'ACTIVE');
  
  FDatabase.CreateTable(LTable, True);
  
  LFieldNames := TStringList.Create;
  try
    FDatabase.FillFieldNames('TEST_FIELD_NAMES', LFieldNames);
    
    CheckEquals(3, LFieldNames.Count, 'Should have 3 fields');
    CheckTrue(LFieldNames.IndexOf('ID') >= 0, 'Should contain ID field');
    CheckTrue(LFieldNames.IndexOf('NAME') >= 0, 'Should contain NAME field');
    CheckTrue(LFieldNames.IndexOf('ACTIVE') >= 0, 'Should contain ACTIVE field');
    
  finally
    LFieldNames.Free;
  end;
end;

procedure TTestSQLiteProvider.TestFillPrimaryKeys;
var
  LTable: ITable;
  LPrimaryKeys: TStringList;
begin
  // Criar tabela com chave primária composta
  LTable := TStructureDomain.Table;
  LTable.Name('TEST_PRIMARY_KEYS');
  LTable.Fields.AddIntegerField(1, 'ID1').PrimaryKey(True);
  LTable.Fields.AddIntegerField(2, 'ID2').PrimaryKey(True);
  LTable.Fields.AddStringField(3, 'NAME', 50);
  
  FDatabase.CreateTable(LTable, True);
  
  LPrimaryKeys := TStringList.Create;
  try
    FDatabase.FillPrimaryKeys('TEST_PRIMARY_KEYS', LPrimaryKeys);
    
    CheckEquals(2, LPrimaryKeys.Count, 'Should have 2 primary key fields');
    CheckTrue(LPrimaryKeys.IndexOf('ID1') >= 0, 'Should contain ID1 as primary key');
    CheckTrue(LPrimaryKeys.IndexOf('ID2') >= 0, 'Should contain ID2 as primary key');
    
  finally
    LPrimaryKeys.Free;
  end;
end;

procedure TTestSQLiteProvider.TestSequencesNotSupported;
var
  LSequences: TStringList;
begin
  LSequences := TStringList.Create;
  try
    CheckException(
      procedure
      begin
        FDatabase.FillSequences(LSequences);
      end,
      Exception,
      'Should raise exception when trying to use sequences'
    );
  finally
    LSequences.Free;
  end;
end;

procedure TTestSQLiteProvider.TestFieldTypes;
var
  LTable: ITable;
  LDataSet: TProviderMemTable;
begin
  // Criar tabela com vários tipos
  LTable := TStructureDomain.Table;
  LTable.Name('TEST_FIELD_TYPES');
  LTable.Fields.AddIntegerField(1, 'ID').PrimaryKey(True);
  LTable.Fields.AddStringField(2, 'TEXT_FIELD', 100);
  LTable.Fields.AddFloatField(3, 'NUMERIC_FIELD', 10, 2);
  LTable.Fields.AddBlobBinaryField(4, 'BLOB_FIELD');
  
  FDatabase.CreateTable(LTable, True);
  
  // Inserir dados
  FDatabase
    .Clear
    .SetSQL('INSERT INTO TEST_FIELD_TYPES (ID, TEXT_FIELD, NUMERIC_FIELD) VALUES (?, ?, ?)')
    .SetIntegerParam('P1', 1)
    .SetStringParam('P2', 'Test Text')
    .SetFloatParam('P3', 123.45)
    .Execute;
  
  // Verificar tipos
  LDataSet := TProviderMemTable.Create(nil);
  try
    FDatabase
      .Clear
      .SetSQL('SELECT * FROM TEST_FIELD_TYPES')
      .SetDataset(LDataSet)
      .Open;
      
    CheckFalse(LDataSet.IsEmpty, 'Dataset should not be empty');
    CheckEquals(1, LDataSet.FieldByName('ID').AsInteger, 'Integer field should work');
    CheckEquals('Test Text', LDataSet.FieldByName('TEXT_FIELD').AsString, 'Text field should work');
    CheckEquals(123.45, LDataSet.FieldByName('NUMERIC_FIELD').AsFloat, 0.01, 'Numeric field should work');
    
  finally
    LDataSet.Free;
  end;
end;

procedure TTestSQLiteProvider.TestBooleanFields;
var
  LTable: ITable;
  LDataSet: TProviderMemTable;
begin
  // Criar tabela com campo boolean
  LTable := TStructureDomain.Table;
  LTable.Name('TEST_BOOLEAN');
  LTable.Fields.AddIntegerField(1, 'ID').PrimaryKey(True);
  LTable.Fields.AddBooleanField(2, 'IS_ACTIVE');
  
  FDatabase.CreateTable(LTable, True);
  
  // Inserir valores true e false
  FDatabase
    .Clear
    .SetSQL('INSERT INTO TEST_BOOLEAN (ID, IS_ACTIVE) VALUES (?, ?)')
    .SetIntegerParam('P1', 1)
    .SetBooleanParam('P2', True)
    .Execute;
    
  FDatabase
    .Clear
    .SetSQL('INSERT INTO TEST_BOOLEAN (ID, IS_ACTIVE) VALUES (?, ?)')
    .SetIntegerParam('P1', 2)
    .SetBooleanParam('P2', False)
    .Execute;
  
  // Verificar valores
  LDataSet := TProviderMemTable.Create(nil);
  try
    FDatabase
      .Clear
      .SetSQL('SELECT * FROM TEST_BOOLEAN ORDER BY ID')
      .SetDataset(LDataSet)
      .Open;
      
    CheckFalse(LDataSet.IsEmpty, 'Dataset should not be empty');
    
    CheckTrue(LDataSet.FieldByName('IS_ACTIVE').AsBoolean, 'First record should be true');
    LDataSet.Next;
    CheckFalse(LDataSet.FieldByName('IS_ACTIVE').AsBoolean, 'Second record should be false');
    
  finally
    LDataSet.Free;
  end;
end;

procedure TTestSQLiteProvider.TestDateTimeFields;
var
  LTable: ITable;
  LDataSet: TProviderMemTable;
  LTestDate: TDateTime;
begin
  // Criar tabela com campo datetime
  LTable := TStructureDomain.Table;
  LTable.Name('TEST_DATETIME');
  LTable.Fields.AddIntegerField(1, 'ID').PrimaryKey(True);
  LTable.Fields.AddDateTimeField(2, 'CREATED_AT');
  
  FDatabase.CreateTable(LTable, True);
  
  LTestDate := EncodeDate(2024, 1, 1) + EncodeTime(12, 30, 45, 0);
  
  // Inserir data
  FDatabase
    .Clear
    .SetSQL('INSERT INTO TEST_DATETIME (ID, CREATED_AT) VALUES (?, ?)')
    .SetIntegerParam('P1', 1)
    .SetDateTimeParam('P2', LTestDate)
    .Execute;
  
  // Verificar data
  LDataSet := TProviderMemTable.Create(nil);
  try
    FDatabase
      .Clear
      .SetSQL('SELECT * FROM TEST_DATETIME')
      .SetDataset(LDataSet)
      .Open;
      
    CheckFalse(LDataSet.IsEmpty, 'Dataset should not be empty');
    
    // Verificar se a data é aproximadamente igual (pode haver pequenas diferenças de precisão)
    CheckEquals(LTestDate, LDataSet.FieldByName('CREATED_AT').AsDateTime, 1/86400, 'DateTime should match within 1 second');
    
  finally
    LDataSet.Free;
  end;
end;

procedure TTestSQLiteProvider.TestForeignKeyLimitations;
var
  LParentTable, LChildTable: ITable;
  LForeignKey: ITableForeignKey;
begin
  // Criar tabela pai
  LParentTable := TStructureDomain.Table;
  LParentTable.Name('PARENT_TABLE');
  LParentTable.Fields.AddIntegerField(1, 'ID').PrimaryKey(True);
  LParentTable.Fields.AddStringField(2, 'NAME', 50);
  
  FDatabase.CreateTable(LParentTable, True);
  
  // Criar tabela filha com foreign key
  LChildTable := TStructureDomain.Table;
  LChildTable.Name('CHILD_TABLE');
  LChildTable.Fields.AddIntegerField(1, 'ID').PrimaryKey(True);
  LChildTable.Fields.AddIntegerField(2, 'PARENT_ID');
  LChildTable.Fields.AddStringField(3, 'DESCRIPTION', 100);
  
  LForeignKey := TStructureDomain.ForeignKey;
  LForeignKey
    .Name('FK_CHILD_PARENT')
    .Keys('PARENT_ID')
    .ReferenceTable('PARENT_TABLE')
    .ReferenceKeys('ID')
    .OnDelete(Cascade)
    .OnUpdate(Restrict);
    
  LChildTable.ForeignKeys.AddReference(LForeignKey);
  
  // Deve funcionar na criação da tabela
  CheckNoException(
    procedure
    begin
      FDatabase.CreateTable(LChildTable, True);
    end,
    'Should create table with foreign key without exceptions'
  );
end;

initialization
  RegisterTest(TTestSQLiteProvider.Suite);

end.