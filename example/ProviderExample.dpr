program ProviderExample;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  System.SysUtils,
  provider.firebird in '..\provider.firebird.pas',
  provider in '..\provider.pas',
  structure.domain.field in '..\structure.domain.field.pas',
  structure.domain.table in '..\structure.domain.table.pas';

begin
  try
    TProvider.Instance
      .Clear
      .StartTransaction
      .SetSQL('my sql')
      .Execute
      .Commit;

  except
    on E: Exception do
      Writeln(E.ClassName, ': ', E.Message);
  end;
end.
