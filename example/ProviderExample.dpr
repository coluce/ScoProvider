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

  ReportMemoryLeaksOnShutdown := True;

  Writeln('Provider - Example');
  try

    LDatabaseInfo.Server := 'localhost';
    LDatabaseInfo.Port := 3051;
    LDatabaseInfo.FileName := 'deathstar.fdb';
    LDatabaseInfo.UserName := 'SYSDBA';
    LDatabaseInfo.Password := '1709d7c5c7eb4f910115';

    LTable := TStructureDomain.Table;
    LTable.Name('TEST_TABLE');

    LField := TStructureDomain.Field
      .Index(1)
      .PrimaryKey(True)
      .Name('ID')
      .FieldType('INTEGER')
      .Obs('My Primary Key');

    LTable.Fields.AddField(LField);

    LField := TStructureDomain.Field
      .Index(2)
      .Name('Name')
      .FieldType('VARCHAR')
      .FieldSize(100)
      .Obs('Name of the entity');

    LTable.Fields.AddField(LField);

    LField := TStructureDomain.Field
      .Index(3)
      .Name('Active')
      .FieldType('BOOLEAN');

    LTable.Fields.AddField(LField);

    LProvider := TProvider.Instance
      .SetDatabaseInfo(LDatabaseInfo);

    Writeln('');
    Writeln('Database: ' + LDatabaseInfo.FileName);
    Writeln('');

    Writeln('waiting ... creating table');
    LProvider.CreateTable(LTable, True);

    Writeln('');
    Writeln('waiting ... creating records');

    LStrLine := 'insert into TEST_TABLE (ID, Name, Active) values (:ID, :Name, :Active)';
    Writeln('script: ' + LStrLine);

    LProvider
      .Clear
      .SetSQL(LStrLine)
      .SetIntegerParam('ID', 1)
      .SetStringParam('Name', 'My Name')
      .SetBooleanParam('Active', True)
      .Execute;

    LProvider
      .SetIntegerParam('ID', 2)
      .SetStringParam('Name', 'Your Name')
      .SetBooleanParam('Active', True)
      .Execute;

    LProvider
      .SetIntegerParam('ID', 3)
      .SetStringParam('Name', 'Nobody')
      .SetBooleanParam('Active', False)
      .Execute;

    Writeln('');
    Writeln('waiting ... reading active records');
    Writeln('');
    LDataSet := TProviderMemTable.Create(nil);
    try

      LProvider
        .Clear
        .SetSQL('select * from TEST_TABLE where Active')
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
            LStrLine := LStrLine + LDataSet.Fields[i].FieldName + ' : ' + QuotedStr(LDataSet.Fields[i].AsString) + ' ';
          end;
          Writeln(LStrLine);
          LDataSet.Next;
        end;

      end;

      Writeln('');
      Writeln('waiting ... filtering records by ID 2');

      LProvider
        .Clear
        .SetSQL('select * from TEST_TABLE where ID = :ID')
        .SetDataset(LDataSet)
        .SetIntegerParam('ID', 2)
        .Open;

      if not LDataSet.IsEmpty then
      begin
        LDataSet.First;
        while not LDataSet.Eof do
        begin
          LStrLine := EmptyStr;
          for i := 0 to LDataSet.Fields.Count -1 do
          begin
            LStrLine := LStrLine + LDataSet.Fields[i].FieldName + ' : ' + QuotedStr(LDataSet.Fields[i].AsString) + ' ';
          end;
          Writeln(LStrLine);
          LDataSet.Next;
        end;

      end;

      Writeln('');
      Writeln('waiting ... filtering records by ID 3');

      LProvider
        .Clear
        .SetSQL('select * from TEST_TABLE where ID = :ID')
        .SetDataset(LDataSet)
        .SetIntegerParam('ID', 3)
        .Open;

      if not LDataSet.IsEmpty then
      begin
        LDataSet.First;
        while not LDataSet.Eof do
        begin
          LStrLine := EmptyStr;
          for i := 0 to LDataSet.Fields.Count -1 do
          begin
            LStrLine := LStrLine + LDataSet.Fields[i].FieldName + ' : ' + QuotedStr(LDataSet.Fields[i].AsString) + ' ';
          end;
          Writeln(LStrLine);
          LDataSet.Next;
        end;

      end;

    finally
      LDataSet.Free;
    end;

    Writeln('');
    Writeln('Done!');

  except
    on E: Exception do
      Writeln(E.ClassName, ': ', E.Message);
  end;

  Readln;

end.
