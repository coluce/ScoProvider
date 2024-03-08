## ⚙️ Installation
Installation is done using the [`boss install`](https://github.com/HashLoad/boss) command:
``` sh
boss install github.com/coluce/provider
```

## ⚡️ Quickstart
```delphi
uses 
  provider;

var
  LProvider: IProviderDatabase;
  LDatabaseInfo: TDatabaseInfo;
  LDataSet: TProviderMemTable;
  LStrLine: string;
  i: integer;
  LTable: ITable;
  LField: IField;
begin
  LDatabaseInfo.Server := 'localhost';
  LDatabaseInfo.Port := 3050;
  LDatabaseInfo.FileName := 'my_firebird_database.fdb';
  LDatabaseInfo.UserName := 'SYSDBA';
  LDatabaseInfo.Password := 'my_secret_password';

  LProvider := TProvider.Instance
    .SetDatabaseInfo(LDatabaseInfo);

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

```

## 📚 Delphi Versions
`Provider` works with Delphi 12, Delphi 11 Alexandria, Delphi 10.4 Sydney, Delphi 10.3 Rio, Delphi 10.2 Tokyo, Delphi 10.1 Berlin, Delphi 10 Seattle, Delphi XE8 and Delphi XE7.