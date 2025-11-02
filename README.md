## ⚙️ Installation
Installation is done using the [`boss install`](https://github.com/HashLoad/boss) command:
``` sh
boss install github.com/coluce/scoprovider
```

## 🗄️ Supported Databases

ScoProvider supports multiple database engines:

### Firebird
```delphi
uses 
  Sco.Provider;
var
  LDatabase: IProviderDatabase;
begin
  LDatabase := TScoProvider.Firebird;
  LDatabase.DatabaseInfo.Server := 'localhost';
  LDatabase.DatabaseInfo.Port := 3050;
  LDatabase.DatabaseInfo.FileName := 'sco_provider';
  LDatabase.DatabaseInfo.Protocol := 'TCPIP';
  LDatabase.DatabaseInfo.CharacterSet := 'UTF8';
  LDatabase.DatabaseInfo.UserName := 'SYSDBA';
  LDatabase.DatabaseInfo.Password := 'masterkey';
end;
```

### SQLite
```delphi
uses 
  Sco.Provider;
var
  LDatabase: IProviderDatabase;
begin
  LDatabase := TScoProvider.SQLite;
  LDatabase.DatabaseInfo.FileName := 'C:\MyProject\database.db';
  // SQLite only needs the file path
end;
```

## ℹ️ Legacy Usage (Firebird only)
```delphi
// For backward compatibility - uses Firebird by default
LDatabase := TScoProvider.Instance;
```

## 🆕 Creating a table
```delphi
uses 
  Sco.Provider;
var
  LTable: ITable;
  LField: IField;
begin

  { define table structure }
  LTable := TStructureDomain.Table;
  LTable.Name('TEST_TABLE');
  LTable.Fields
    .AddIntegerField(1, 'ID')
      .PrimaryKey(True)
      .Obs('My primary key');
  LTable.Fields.AddStringField(2, 'NAME', 100, 'UTF8');
  LTable.Fields.AddBooleanField(3, 'ACTIVE');

  { create table in database }
  LDatabase.CreateTable(LTable, True);

end;
```

## 👀 Manipulating Records
```delphi
uses 
  Sco.Provider;
var
  LDataSet: TProviderMemTable;
  LStrLine: string;
  i: integer;
begin

  LStrLine := 'insert into ' + LTable.Name + ' (ID, Name) values (1, ' + QuotedStr('My Name') + ')';
  LDatabase
    .Clear
    .SetSQL(LStrLine)
    .Execute;

  LStrLine := 'insert into ' + LTable.Name + ' (ID, Name) values (2, ' + QuotedStr('Your Name') + ')';
  LDatabase
    .Clear
    .SetSQL(LStrLine)
    .Execute;

  { lendo registros do banco de dados }
  LDataSet := TProviderMemTable.Create(nil);
  try

    LDatabase
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

## � Database-Specific Features

### SQLite Limitations
- **Sequences**: Not supported. Use `AUTOINCREMENT` with `INTEGER PRIMARY KEY` instead
- **Character Sets**: Ignored (SQLite always uses UTF-8)
- **ALTER TABLE**: Limited support for adding columns to existing tables
- **Foreign Keys**: Can only be added during table creation

See [README_SQLite.md](README_SQLite.md) for detailed SQLite documentation.

## �📚 Delphi Versions
`Provider` works with Delphi 12, Delphi 11 Alexandria, Delphi 10.4 Sydney, Delphi 10.3 Rio, Delphi 10.2 Tokyo, Delphi 10.1 Berlin, Delphi 10 Seattle, Delphi XE8 and Delphi XE7.