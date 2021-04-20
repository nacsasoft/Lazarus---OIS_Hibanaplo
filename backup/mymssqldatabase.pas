unit myMSSQLDatabase;

{$mode objfpc} // directive to be used for defining classes
{$m+}		   // directive to be used for using constructor


interface

uses
  Classes, SysUtils,sqldb, mssqlconn, Dialogs;

type
  cMSSQLDatabase = class
  private
    pConnection: TSQLConnection;
    pSQLTransaction1: TSQLTransaction;


    {const
        dbUserName = 'odc';
        dbPassword = '1odc%Admin';
        dbHostName = 'tabnt11';
        dbDatabaseName = 'OI_DELTA_CONTROL';}

  public
    pSQLQuery1: TSQLQuery;


    constructor Create(dbUserName : String = 'odc'; dbPassword : String = '1odc%Admin';
                                  dbHostName : String = 'tabnt11'; dbDatabaseName : String = 'OI_DELTA_CONTROL';);
    procedure RunSQL(sSQL: ansistring);
    procedure Terminate();
    procedure InsertDatas();

    function GetRecordCount() : integer;


  end;

implementation


constructor cMSSQLDatabase.Create(dbUserName : String = 'odc'; dbPassword : String = '1odc%Admin';
                                  dbHostName : String = 'tabnt11'; dbDatabaseName : String = 'OI_DELTA_CONTROL';);
begin
  //mssql kapcsolat létrehozása:
  pConnection := TMSSQLConnection.Create(nil);
  pSQLQuery1 := TSQLQuery.Create(nil);
  pSQLTransaction1 := TSQLTransaction.Create(nil);

  pSQLTransaction1.DataBase := pConnection;
  pSQLQuery1.DataBase := pConnection;

  with pConnection do
  begin
    UserName := dbUserName;
    Password := dbPassword;
    HostName := dbHostName;
    DatabaseName := dbDatabaseName;
    Transaction := pSQLTransaction1;
  end;

  try
    pConnection.Connected := true;
  except
    on E: Exception do
      ShowMessage('Adatbázis kapcsolódási hiba: ' + E.ClassName + ' / ' + E.Message);
  end;

end;

procedure cMSSQLDatabase.RunSQL(sSQL : ansistring);
begin
  pSQLTransaction1.Active:=false;
  pSQLQuery1.Active := false;
  pSQLQuery1.SQL.Text := sSQL;
  pSQLTransaction1.Active:=true;
  pSQLQuery1.Active := true;
end;

function cMSSQLDatabase.GetRecordCount() : integer;
begin
  pSQLQuery1.Last;
  result := pSQLQuery1.RecordCount;
  pSQLQuery1.First;
end;

procedure cMSSQLDatabase.InsertDatas();
begin
  pSQLQuery1.ExecSQL;
  pSQLTransaction1.Commit;
end;

procedure cMSSQLDatabase.Terminate();
begin
  pSQLQuery1.Free;
  pSQLTransaction1.Free;
  pConnection.Close();
  pConnection.Free;
end;

end.
