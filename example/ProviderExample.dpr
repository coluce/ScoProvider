program ProviderExample;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  System.SysUtils,
  Data.DB,
  provider.firebird in '..\provider.firebird.pas',
  provider in '..\provider.pas',
  structure.domain.field in '..\structure.domain.field.pas',
  structure.domain.table in '..\structure.domain.table.pas';

var
  LDatabaseInfo: TDatabaseInfo;
  LProvider: IProviderDatabase;
  LDataSet: TProviderMemTable;
  i: integer;
  LStrLine: string;
  LTable: ITable;
  LField: IField;
begin
  Writeln('Provider - Projeto de Exemplo');
  try

    LDatabaseInfo.Server := 'localhost';
    LDatabaseInfo.Port := 3051;
    LDatabaseInfo.FileName := 'deathstar.fdb';
    LDatabaseInfo.UserName := 'SYSDBA';
    LDatabaseInfo.Password := '1709d7c5c7eb4f910115';

    LTable := TStructureDomain.Table;
    LTable.Name('TEST_TABLE');

    LField := TStructureDomain.Field
      .ID(1)
      .PrimaryKey(True)
      .Name('ID')
      .FieldType('INTEGER')
      .Obs('My Primary Key');

    LTable.Fields.AddOrSetValue(LField.Name, LField);

    LField := TStructureDomain.Field
      .ID(2)
      .Name('NAME')
      .FieldType('VARCHAR')
      .FieldSize(100)
      .Obs('Name of the entity');

    LTable.Fields.AddOrSetValue(LField.Name, LField);

    LProvider := TProvider.Instance
      .SetDatabaseInfo(LDatabaseInfo);

    Writeln('');
    Writeln('Database: ' + LDatabaseInfo.FileName);
    Writeln('');

    Writeln('aguarde ... criando tabela');
    LProvider.CreateTable(LTable, True);

    Writeln('');
    Writeln('aguarde ... inserindo registros');

    LStrLine := 'insert into ' + LTable.Name + ' (ID, Name) values (1, ' + QuotedStr('My Name') + ')';
    Writeln('script 1: ' + LStrLine);
    LProvider
      .Clear
      .SetSQL(LStrLine)
      .Execute;

    LStrLine := 'insert into ' + LTable.Name + ' (ID, Name) values (2, ' + QuotedStr('Your Name') + ')';
    Writeln('script 2: ' + LStrLine);
    LProvider
      .Clear
      .SetSQL(LStrLine)
      .Execute;

    Writeln('');
    Writeln('aguarde ... lendo registros');
    Writeln('');
    LDataSet := TProviderMemTable.Create(nil);
    try

      LProvider
        .Clear
        .SetSQL('select * from ' + LTable.Name)
        .SetDataset(LDataSet)
        .Open;

      if not LDataSet.IsEmpty then
      begin
        LDataSet.First;
        while not LDataSet.Eof do
        begin
          LStrLine := EmptyStr;
          for i := 0 to LDataSet.Fields.Count -1 do
          begin
            LStrLine := LStrLine + LDataSet.Fields[i].AsString + ';';
          end;
          Writeln(LStrLine);
          LDataSet.Next;
        end;

      end;

    finally
      LDataSet.Free;
    end;

    Writeln('Tudo OK!');

  except
    on E: Exception do
      Writeln(E.ClassName, ': ', E.Message);
  end;

  Readln;

end.
