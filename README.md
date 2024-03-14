## ⚙️ Installation
Installation is done using the [`boss install`](https://github.com/HashLoad/boss) command:
``` sh
boss install github.com/coluce/provider
```

## ℹ️ Defining the connection data
```delphi
uses 
  provider;
var
  LProvider: IProviderDatabase;
  LDatabaseInfo: TDatabaseInfo;
begin

  LDatabaseInfo.Server := 'localhost';
  LDatabaseInfo.Port := 3050;
  LDatabaseInfo.FileName := 'my_firebird_database.fdb';
  LDatabaseInfo.UserName := 'SYSDBA';
  LDatabaseInfo.Password := 'my_secret_password';

  LProvider := TProvider.Instance
    .SetDatabaseInfo(LDatabaseInfo);

end;
```

## 🆕 Creating a table
```delphi
uses 
  provider;
var
  LTable: ITable;
  LField: IField;
begin

  LTable := TStructureDomain.Table;
  LTable.Name('TEST_TABLE');

  LField := TStructureDomain.Field
    .Index(1)
    .PrimaryKey(True)
    .Name('ID')
    .FieldType('INTEGER')
    .Obs('My Primary Key');

  LTable.Fields.AddOrSetValue(LField.Name, LField);

  LField := TStructureDomain.Field
    .Index(2)
    .Name('NAME')
    .FieldType('VARCHAR')
    .FieldSize(100)
    .Obs('Name of the entity');

  LTable.Fields.AddOrSetValue(LField.Name, LField);

  LProvider.CreateTable(LTable, True);

end;
```

## 👀 Manipulating Records
```delphi
uses 
  provider;
var
  LDataSet: TProviderMemTable;
  LStrLine: string;
  i: integer;
begin

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

end;
```

## 📚 Delphi Versions
`Provider` works with Delphi 12, Delphi 11 Alexandria, Delphi 10.4 Sydney, Delphi 10.3 Rio, Delphi 10.2 Tokyo, Delphi 10.1 Berlin, Delphi 10 Seattle, Delphi XE8 and Delphi XE7.