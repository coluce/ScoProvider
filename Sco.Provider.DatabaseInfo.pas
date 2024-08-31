unit Sco.Provider.DatabaseInfo;

interface

uses
  Sco.Provider;

type

  TProviderDatabaseInfo = class(TInterfacedObject, IProviderDatabaseInfo)
  private
    FServer: string;
    FPort: integer;
    FFileName: string;
    FUserName: string;
    FPassword: string;
    FCharacterSet: string;
    FProtocol: string;

    function GetServer: string;
    function GetPort: integer;
    function GetFileName: string;
    function GetUserName: string;
    function GetPassword: string;
    function GetCharacterSet: string;
    function GetProtocol: string;

    procedure SetServer(const Value: string);
    procedure SetPort(const Value: integer);
    procedure SetFileName(const Value: string);
    procedure SetUserName(const Value: string);
    procedure SetPassword(const Value: string);
    procedure SetCharacterSet(const Value: string);
    procedure SetProtocol(const Value: string);

  public
    class function New: IProviderDatabaseInfo;
    property Server: string read GetServer write SetServer;
    property Port: integer read GetPort write SetPort;
    property FileName: string read GetFileName write SetFileName;
    property UserName: string read GetUserName write SetUserName;
    property Password: string read GetPassword write SetPassword;
    property CharacterSet: string read GetCharacterSet write SetCharacterSet;
    property Protocol: string read GetProtocol write SetProtocol;
  end;

implementation

{ TProviderDatabaseInfo }

class function TProviderDatabaseInfo.New: IProviderDatabaseInfo;
begin
  Result := Self.Create;
end;

function TProviderDatabaseInfo.GetCharacterSet: string;
begin
  Result := FCharacterSet;
end;

function TProviderDatabaseInfo.GetFileName: string;
begin
  Result := FFileName;
end;

function TProviderDatabaseInfo.GetPassword: string;
begin
  Result := FPassword;
end;

function TProviderDatabaseInfo.GetPort: integer;
begin
  Result := FPort;
end;

function TProviderDatabaseInfo.GetProtocol: string;
begin
  Result := FProtocol;
end;

function TProviderDatabaseInfo.GetServer: string;
begin
  Result := FServer;
end;

function TProviderDatabaseInfo.GetUserName: string;
begin
  Result := FUserName;
end;

procedure TProviderDatabaseInfo.SetCharacterSet(const Value: string);
begin
  FCharacterSet := Value;
end;

procedure TProviderDatabaseInfo.SetFileName(const Value: string);
begin
  FFileName := Value;
end;

procedure TProviderDatabaseInfo.SetPassword(const Value: string);
begin
  FPassword := Value;
end;

procedure TProviderDatabaseInfo.SetPort(const Value: integer);
begin
  FPort := Value;
end;

procedure TProviderDatabaseInfo.SetProtocol(const Value: string);
begin
  FProtocol := Value;
end;

procedure TProviderDatabaseInfo.SetServer(const Value: string);
begin
  FServer := Value;
end;

procedure TProviderDatabaseInfo.SetUserName(const Value: string);
begin
  FUserName := Value;
end;

end.
