program ProviderExample;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  System.SysUtils,
  Data.DB,
  Sco.Provider.Firebird in '..\Sco.Provider.Firebird.pas',
  Sco.Provider in '..\Sco.Provider.pas',
  Sco.Provider.Domain.Field in '..\Sco.Provider.Domain.Field.pas',
  Sco.Provider.Domain.Table in '..\Sco.Provider.Domain.Table.pas';

var
  LDatabaseInfo: TDatabaseInfo;
  LProvider: IProviderDatabase;
  LDataSet: TProviderMemTable;
  LIndex: Integer;
  LStrLine: string;
  LTable: ITable;
begin

  ReportMemoryLeaksOnShutdown := True;

  Writeln('Provider - Example');
  try

    LDatabaseInfo.Server := 'localhost';
    LDatabaseInfo.Port := 3051;
    LDatabaseInfo.FileName := 'deathstar.fdb';
    LDatabaseInfo.Protocol := 'TCPIP';
    LDatabaseInfo.CharacterSet := 'UTF8';
    LDatabaseInfo.UserName := 'SYSDBA';
    LDatabaseInfo.Password := '1709d7c5c7eb4f910115';

    LTable := TStructureDomain.Table;
    LTable.Name('TEST_TABLE');
    LTable.Fields
      .AddIntegerField(1, 'ID')
        .PrimaryKey(True)
        .Obs('My primary key');
    LTable.Fields.AddStringField(2, 'NAME', 100, 'UTF8').NotNull(True);
    LTable.Fields.AddBooleanField(3, 'ACTIVE');

    LProvider := TProvider.Instance
      .SetDatabaseInfo(LDatabaseInfo);

    Writeln('');
    Writeln('Database: ' + LDatabaseInfo.FileName);
    Writeln('');

    Writeln('waiting ... creating table');
    LProvider.CreateTable(LTable, True);

    Writeln('');
    Writeln('waiting ... creating records');

    LStrLine := 'insert into TEST_TABLE (ID, NAME, ACTIVE) values (:ID, :NAME, :ACTIVE)';
    Writeln('script: ' + LStrLine);

    LProvider
      .Clear
      .SetSQL(LStrLine)
      .SetIntegerParam('ID', 1)
      .SetStringParam('NAME', 'My Name')
      .SetBooleanParam('ACTIVE', True)
      .Execute;

    LProvider
      .SetIntegerParam('ID', 2)
      .SetStringParam('NAME', 'Your Name')
      .SetBooleanParam('ACTIVE', True)
      .Execute;

    LProvider
      .SetIntegerParam('ID', 3)
      .SetStringParam('NAME', 'Nobody')
      .SetBooleanParam('ACTIVE', False)
      .Execute;

    Writeln('');
    Writeln('waiting ... reading active records');
    Writeln('');
    LDataSet := TProviderMemTable.Create(nil);
    try

      LProvider
        .Clear
        .SetSQL('select * from TEST_TABLE where ACTIVE')
        .SetDataset(LDataSet)
        .Open;

      if not LDataSet.IsEmpty then
      begin
        LDataSet.First;
        while not LDataSet.Eof do
        begin
          LStrLine := EmptyStr;
          for LIndex := 0 to LDataSet.Fields.Count -1 do
          begin
            LStrLine :=
              LStrLine + LDataSet.Fields[LIndex].FieldName + ' : ' +
              QuotedStr(LDataSet.Fields[LIndex].AsString) + ' ';
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
          for LIndex := 0 to LDataSet.Fields.Count -1 do
          begin
            LStrLine :=
              LStrLine + LDataSet.Fields[LIndex].FieldName + ' : ' +
              QuotedStr(LDataSet.Fields[LIndex].AsString) + ' ';
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
          for LIndex := 0 to LDataSet.Fields.Count -1 do
          begin
            LStrLine :=
              LStrLine + LDataSet.Fields[LIndex].FieldName + ' : ' +
              QuotedStr(LDataSet.Fields[LIndex].AsString) + ' ';
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
