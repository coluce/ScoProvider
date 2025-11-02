program SQLiteExample;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  System.SysUtils,
  System.Classes,
  Data.DB,
  Sco.Provider,
  Sco.Provider.SQLite;

var
  LDatabase: IProviderDatabase;
  LTable: ITable;
  LDataSet: TProviderMemTable;
  LStrLine: string;
  i: integer;
begin
  try
    // Configurar conexão SQLite
    LDatabase := TScoProvider.SQLite;
    LDatabase.DatabaseInfo.FileName := ExtractFilePath(ParamStr(0)) + 'test.db';

    Writeln('=== Exemplo ScoProvider SQLite ===');
    Writeln('Database: ', LDatabase.DatabaseInfo.FileName);
    Writeln;

    // Criar estrutura da tabela
    LTable := TStructureDomain.Table;
    LTable.Name('TEST_TABLE');
    
    // Adicionar campos
    LTable.Fields
      .AddIntegerField(1, 'ID')
        .PrimaryKey(True)
        .NotNull(True);
    
    LTable.Fields.AddStringField(2, 'NAME', 100);
    LTable.Fields.AddBooleanField(3, 'ACTIVE');
    LTable.Fields.AddDateTimeField(4, 'CREATED_AT');

    // Criar tabela no banco
    Writeln('Criando tabela...');
    LDatabase.CreateTable(LTable, True); // True = drop se existir
    Writeln('Tabela criada com sucesso!');
    Writeln;

    if LDatabase.TableExists('TEST_TABLE') then
      Writeln('Tabela existe!')
    else
      Writeln('Falha ao detectar tabela!');

    // Inserir alguns registros
    Writeln('Inserindo registros...');
    
    LDatabase
      .Clear
      .SetSQL('INSERT INTO TEST_TABLE (ID, NAME, ACTIVE, CREATED_AT) VALUES (:ID, :NAME, :ACTIVE, :CREATED_AT)')
      .SetIntegerParam('ID', 1)
      .SetStringParam('NAME', 'João Silva')
      .SetBooleanParam('ACTIVE', True)
      .SetDateTimeParam('CREATED_AT', Now)
      .Execute;

    LDatabase
      .Clear
      .SetSQL('INSERT INTO TEST_TABLE (ID, NAME, ACTIVE, CREATED_AT) VALUES (:ID, :NAME, :ACTIVE, :CREATED_AT)')
      .SetIntegerParam('ID', 2)
      .SetStringParam('NAME', 'Maria Santos')
      .SetBooleanParam('ACTIVE', False)
      .SetDateTimeParam('CREATED_AT', Now)
      .Execute;

    LDatabase
      .Clear
      .SetSQL('INSERT INTO TEST_TABLE (ID, NAME, ACTIVE, CREATED_AT) VALUES (:ID, :NAME, :ACTIVE, :CREATED_AT)')
      .SetIntegerParam('ID', 3)
      .SetStringParam('NAME', 'Pedro Costa')
      .SetBooleanParam('ACTIVE', True)
      .SetDateTimeParam('CREATED_AT', Now)
      .Execute;

    Writeln('Registros inseridos!');
    Writeln;

    // Ler dados da tabela
    Writeln('Lendo registros da tabela:');
    Writeln('ID | Nome | Ativo | Data Criação');
    Writeln('---|------|-------|-------------');

    LDataSet := TProviderMemTable.Create(nil);
    try
      LDatabase
        .Clear
        .SetSQL('SELECT * FROM TEST_TABLE ORDER BY ID')
        .SetDataset(LDataSet)
        .Open;

      if not LDataSet.IsEmpty then
      begin
        LDataSet.First;
        while not LDataSet.Eof do
        begin
          Write(LDataSet.FieldByName('ID').AsString.PadRight(2));
          Write(' | ');
          Write(LDataSet.FieldByName('NAME').AsString.PadRight(15));
          Write(' | ');
          Write(BoolToStr(LDataSet.FieldByName('ACTIVE').AsBoolean, True).PadRight(5));
          Write(' | ');
          Writeln(FormatDateTime('dd/mm/yyyy hh:nn:ss', LDataSet.FieldByName('CREATED_AT').AsDateTime));
          LDataSet.Next;
        end;
      end;

    finally
      LDataSet.Free;
    end;

    Writeln;
    Writeln('=== Testando recursos específicos do SQLite ===');

    // Testar informações da tabela
    Writeln;
    Writeln('Campos da tabela:');
    var LFieldNames := TStringList.Create;
    try
      LDatabase.FillFieldNames('TEST_TABLE', LFieldNames);
      for i := 0 to LFieldNames.Count - 1 do
        Writeln('- ' + LFieldNames[i]);
    finally
      LFieldNames.Free;
    end;

    // Testar chaves primárias
    Writeln;
    Writeln('Chaves primárias:');
    var LPrimaryKeys := TStringList.Create;
    try
      LDatabase.FillPrimaryKeys('TEST_TABLE', LPrimaryKeys);
      for i := 0 to LPrimaryKeys.Count - 1 do
        Writeln('- ' + LPrimaryKeys[i]);
    finally
      LPrimaryKeys.Free;
    end;

    // Testar se recurso não suportado gera exceção
    Writeln;
    Writeln('Testando recursos não suportados...');
    try
      var LSequences := TStringList.Create;
      try
        LDatabase.FillSequences(LSequences);
      finally
        LSequences.Free;
      end;
    except
      on E: Exception do
        Writeln('Exceção esperada: ' + E.Message);
    end;

    Writeln;
    Writeln('Exemplo concluído com sucesso!');
    Writeln('Pressione ENTER para sair...');
    Readln;

  except
    on E: Exception do
    begin
      Writeln('Erro: ' + E.ClassName + ': ' + E.Message);
      Writeln('Pressione ENTER para sair...');
      Readln;
    end;
  end;
end.