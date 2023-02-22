program ProviderExample;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  System.SysUtils,
  provider.firebird in '..\provider.firebird.pas',
  provider in '..\provider.pas';

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
