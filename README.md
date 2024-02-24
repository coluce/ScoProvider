## ⚙️ Installation
Installation is done using the [`boss install`](https://github.com/HashLoad/boss) command:
``` sh
boss install github.com/coluce/provider
```

## ⚡️ Quickstart Delphi
```delphi
uses 
  provider;

var
  LProvider: IProviderDatabase;
  LDatabaseInfo: TDatabaseInfo;
  LDataSet: TProviderMemTable; 
  LStrLine: string;  
  i: integer;  
begin
  LDatabaseInfo.Server := 'localhost';
  LDatabaseInfo.Port := 3050;
  LDatabaseInfo.FileName := 'my_firebird_database.fdb';
  LDatabaseInfo.UserName := 'SYSDBA';
  LDatabaseInfo.Password := 'my_secret_password';

  LProvider := TProvider.Instance
    .SetDatabaseInfo(LDatabaseInfo);

  LProvider	
    .Clear
    .SetSQL('select * from MY_TABLE')
    .SetDataset(LDataSet)
    .Open;

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

finally
  LDataSet.Free;
end;

```

## Delphi Versions
`Provider` works with Delphi 12, Delphi 11 Alexandria, Delphi 10.4 Sydney, Delphi 10.3 Rio, Delphi 10.2 Tokyo, Delphi 10.1 Berlin, Delphi 10 Seattle, Delphi XE8 and Delphi XE7.