program ScoProviderExample;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  System.SysUtils,
  Data.DB,
  Sco.Provider.Firebird in '..\Sco.Provider.Firebird.pas',
  Sco.Provider in '..\Sco.Provider.pas',
  Sco.Provider.Domain.Field in '..\Sco.Provider.Domain.Field.pas',
  Sco.Provider.Domain.Table in '..\Sco.Provider.Domain.Table.pas',
  Sco.Provider.DatabaseInfo in '..\Sco.Provider.DatabaseInfo.pas';

var
  LDatabase: IProviderDatabase;
  LDataSet: TProviderMemTable;
  LIndex: Integer;
  LStrLine: string;
  LTable: ITable;
  LReference: ITableForeignKey;
  LArrayParam: TArray<TScoParam>;
begin

  ReportMemoryLeaksOnShutdown := True;

  Writeln('ScoProvider - Example');
  try

    LDatabase := TScoProvider.Instance;
    LDatabase.DatabaseInfo.Server := 'localhost';
    LDatabase.DatabaseInfo.Port := 3050;
    LDatabase.DatabaseInfo.FileName := 'sco_provider';
    LDatabase.DatabaseInfo.Protocol := 'TCPIP';
    LDatabase.DatabaseInfo.CharacterSet := 'UTF8';
    LDatabase.DatabaseInfo.UserName := 'SYSDBA';
    LDatabase.DatabaseInfo.Password := 'masterkey';

    Writeln('');
    Writeln('Database: ' + LDatabase.DatabaseInfo.FileName);
    Writeln('');

    LTable := TStructureDomain.Table;
    LTable.Name('MASTER_TABLE');
    LTable.Fields.AddIntegerField(1, 'ID').PrimaryKey(True).Obs('My primary key');
    LTable.Fields.AddStringField(2, 'NAME', 100, 'UTF8').NotNull(True);
    LTable.Fields.AddBooleanField(3, 'ACTIVE');

    Writeln('waiting ... creating master table');
    LDatabase.CreateTable(LTable, True);

    LTable := TStructureDomain.Table;
    LTable.Name('DETAIL_TABLE');
    LTable.Fields.AddIntegerField(1, 'ID').PrimaryKey(True);
    LTable.Fields.AddIntegerField(1, 'ID_OWNER').NotNull(True);
    LTable.Fields.AddStringField(2, 'NAME', 100, 'UTF8');

    LReference := TTableForeignKey.New
      .Name('MASTER_DETAIL_FK')
      .Keys('ID_OWNER')
      .ReferenceTable('MASTER_TABLE')
      .ReferenceKeys('ID')
      .OnDelete(TTableForeignKeyType.Cascade);

    LTable.ForeignKeys.AddReference(LReference);

    Writeln('waiting ... creating detail table');
    LDatabase.CreateTable(LTable, True);

    Writeln('');
    Writeln('waiting ... creating records');

    LStrLine := 'insert into MASTER_TABLE (ID, NAME, ACTIVE) values (:ID, :NAME, :ACTIVE)';
    Writeln('script: ' + LStrLine);

    LDatabase
      .Clear
      .SetSQL(LStrLine)
      .SetIntegerParam('ID', 1)
      .SetStringParam('NAME', 'My Name')
      .SetBooleanParam('ACTIVE', True)
      .Execute;

    LDatabase
      .SetIntegerParam('ID', 2)
      .SetStringParam('NAME', 'Your Name')
      .SetBooleanParam('ACTIVE', True)
      .Execute;

    LDatabase
      .SetIntegerParam('ID', 3)
      .SetStringParam('NAME', 'Nobody')
      .SetBooleanParam('ACTIVE', False)
      .Execute;

    Writeln('');
    Writeln('waiting ... reading active records');
    Writeln('');
    LDataSet := TProviderMemTable.Create(nil);
    try

      LDatabase
        .Clear
        .SetSQL('select * from MASTER_TABLE where ACTIVE')
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

      LDatabase
        .Clear
        .SetSQL('select * from MASTER_TABLE where ID = :ID')
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

      LDatabase
        .Clear
        .SetSQL('select * from MASTER_TABLE where ID = :ID')
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

      Writeln('');
      Writeln('waiting ... filtering records by ID 2 by param array');

      SetLength(LArrayParam, 1);
      LArrayParam[0].Name := 'ID';
      LArrayParam[0].ParamType := ftInteger;
      LArrayParam[0].Value := 2;

      LDatabase
        .Clear
        .SetSQL('select * from MASTER_TABLE where ID = :ID')
        .SetDataset(LDataSet)
        .Open(LArrayParam);

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
