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

  { definindo os dados de conexão ao banco de dados }
  LDatabaseInfo.Server := 'localhost';
  LDatabaseInfo.Port := 3050;
  LDatabaseInfo.FileName := 'my_firebird_database.fdb';
  LDatabaseInfo.UserName := 'SYSDBA';
  LDatabaseInfo.Password := 'my_secret_password';

  { passando as propriedades de conexão ao Provider }
  LProvider := TProvider.Instance
    .SetDatabaseInfo(LDatabaseInfo);

  { definindo a estrutura da tabela }
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

  { criando a tabela no banco de dados }
  LProvider.CreateTable(LTable, True);

  { inserindo registros }
  LStrLine := 'insert into ' + LTable.Name + ' (ID, Name) values (1, ' + QuotedStr('My Name') + ')';
  LProvider
    .Clear
    .SetSQL(LStrLine)
    .Execute;

  LStrLine := 'insert into ' + LTable.Name + ' (ID, Name) values (2, ' + QuotedStr('Your Name') + ')';
  LProvider
    .Clear
    .SetSQL(LStrLine)
    .Execute;

  { lendo registros do banco de dados }
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

```

## 📚 Delphi Versions
`Provider` works with Delphi 12, Delphi 11 Alexandria, Delphi 10.4 Sydney, Delphi 10.3 Rio, Delphi 10.2 Tokyo, Delphi 10.1 Berlin, Delphi 10 Seattle, Delphi XE8 and Delphi XE7.