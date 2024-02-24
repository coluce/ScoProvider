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
begin
  Writeln('Provider - Projeto de Exemplo');
  try

    LDatabaseInfo.Server := 'localhost';
    LDatabaseInfo.Port := 3051;
    LDatabaseInfo.FileName := 'deathstar.fdb';
    LDatabaseInfo.UserName := 'SYSDBA';
    LDatabaseInfo.Password := '1709d7c5c7eb4f910115';

    Writeln('');
    Writeln('Database: ' + LDatabaseInfo.FileName);
    Writeln('aguarde ... lendo registros');
    Writeln('');

    LDataSet := TProviderMemTable.Create(nil);
    try

      LProvider := TProvider.Instance
        .SetDatabaseInfo(LDatabaseInfo)
        .Clear
        .SetSQL('select * from STATUS')
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
            LStrLine := LStrLine + LDataSet.Fields[i].AsString + ' - ';
          end;
          Writeln(LStrLine);
          LDataSet.Next;
        end;

      end;

    finally
      LDataSet.Free;
    end;

  except
    on E: Exception do
      Writeln(E.ClassName, ': ', E.Message);
  end;

  Readln;

end.
