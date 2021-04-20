unit main;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, FileUtil, Forms, Controls, Graphics, Dialogs, StdCtrls, Grids, MaskEdit, global;

type

  { TfrmMain }

  TfrmMain = class(TForm)
    btnDBSzinkron1: TButton;
    btnRiportKeszitese: TButton;
    btnFelveteliHibak: TButton;
    chkOsszesSoronKeres: TCheckBox;
    cmbGepek: TComboBox;
    cmbSorok: TComboBox;
    edtAlkatresz: TEdit;
    GroupBox3: TGroupBox;
    GroupBox4: TGroupBox;
    GroupBox2: TGroupBox;
    Label10: TLabel;
    Label13: TLabel;
    Label6: TLabel;
    Label7: TLabel;
    Label8: TLabel;
    Label9: TLabel;
    medIg: TMaskEdit;
    medTol: TMaskEdit;
    stgRiport: TStringGrid;
    procedure btnDBSzinkronClick(Sender: TObject);
    procedure btnFelveteliHibakClick(Sender: TObject);
    procedure btnRiportKesziteseClick(Sender: TObject);
    procedure cmbSorokChange(Sender: TObject);
    procedure FormShow(Sender: TObject);
  private

  public

  end;

var
  frmMain: TfrmMain;

implementation

uses myMSSQLDatabase, mySqliteDatabase;

{$R *.lfm}

{ TfrmMain }

procedure TfrmMain.FormShow(Sender: TObject);
var
  dbSorok, dbMachines : cSqliteDatabase;

  iSorID : integer;

begin
  medTol.Text := FormatDateTime('mm/dd/yyyy hh:', Now) + '00:00';
  medIg.Text := FormatDateTime('mm/dd/yyyy hh:', Now) + '00:00';

  //sorok feltöltése:
  dbSorok := cSqliteDatabase.Create('sorok', 'SELECT * FROM sorok ORDER BY sname');
  cmbSorok.Clear;
  repeat
    cmbSorok.Items.AddObject(dbSorok.pDataset.FieldByName('sname').AsString,
    TObject(dbSorok.pDataset.FieldByName('id').AsInteger));
    dbSorok.pDataset.Next;
  until dbSorok.pDataset.EOF;
  dbSorok.pDataset.First;
  cmbSorok.Text := dbSorok.pDataset.FieldByName('sname').AsString;
  dbSorok.Terminate();

  iSorID := integer(cmbSorok.Items.Objects[cmbSorok.ItemIndex]);

  dbMachines := cSqliteDatabase.Create('machines', 'SELECT * FROM machines WHERE msorid = ' +
                inttostr(iSorID) + ' ORDER BY mlinepos', 'mid');
  cmbGepek.Clear;
  repeat
    cmbGepek.Items.AddObject(dbMachines.pDataset.FieldByName('mname').AsString,
    TObject(dbMachines.pDataset.FieldByName('mid').AsInteger));
    dbMachines.pDataset.Next;
  until dbMachines.pDataset.EOF;
  dbMachines.pDataset.First;
  cmbGepek.Text := dbMachines.pDataset.FieldByName('mname').AsString;
  dbMachines.Terminate();

  stgRiport.Clean([gzNormal]);

end;

procedure TfrmMain.btnDBSzinkronClick(Sender: TObject);
var
  dbEventAndText_View : cMSSQLDatabase;
  dbLocal, dbLocalSzerverek : cSqliteDatabase;
  sLastCreated : string;    //utolsó rekord dátuma...
  bLocalDBEventEmpty : Boolean;
  iServerID : integer;

begin
  {
  OIS szerverekről le kell szedni a "hiányzó" riportokat a V_EVENTANDTEXT141 -viewből!
  Dátum szerint kell lehúzni az adatokat! A helyi db-ben lévőnél csak az újabbak kellenek!

  TÖBB SZÁZEZER REKORDRÓL VAN SZÓ, EZ NEM MŰKÖDIK!!!!
  }
  exit;



  //szerverek lekérése:
  dbLocalSzerverek := cSqliteDatabase.Create('szerverek', 'SELECT * FROM szerverek ORDER BY sid', 'sid');

  //legutolsó dátum, szerverenként:
  dbLocal := cSqliteDatabase.Create('ois_infok','SELECT * FROM ois_infok ORDER BY ois_created');
  dbLocal.pDataset.Last;
  bLocalDBEventEmpty := false;
  if dbLocal.GetRecordCount() = 0 then
  begin
    //üres a helyi db event lista, mindent át kell húzni a szerverekről:
    bLocalDBEventEmpty := true;
  end;

  repeat
    iServerID := dbLocalSzerverek.pDataset.FieldByName('sid').AsInteger;

    dbEventAndText_View := cMSSQLDatabase.Create('SiplaceOisUser', 'VUTB&&42ukbhSnG7',
          dbLocalSzerverek.pDataset.FieldByName('sName').AsString, 'SiplaceOIS');


    if bLocalDBEventEmpty then
    begin
      //üres a helyi event lista, kelle az összes esemény:
      dbEventAndText_View.RunSQL('SELECT * FROM ' + gcEVENT_VIEW_NAME + ' ORDER BY dtCreated');
      ShowMessage('OK');
    end
    else
    begin
      //csak azok a rekordok kellenek amik még nem szerepelnek a helyi db-ben (dátum szerint...):
    end;

    //rekordok átmásolása a szerverről a helyi db-be:
    dbEventAndText_View.pSQLQuery1.Last;    //kell az összes rekord!!
    dbEventAndText_View.pSQLQuery1.First;
    repeat
      with dbLocal.pDataset do
      begin
        Insert;
        FieldByName('ois_mid').AsInteger := dbEventAndText_View.pSQLQuery1.FieldByName('lId').AsInteger;
        FieldByName('ois_created').AsDateTime := dbEventAndText_View.pSQLQuery1.FieldByName('dtCreated').AsDateTime;
        FieldByName('ois_event').AsString := dbEventAndText_View.pSQLQuery1.FieldByName('strName').AsString;
        FieldByName('ois_serverid').AsInteger := iServerID;
        Post;
        ApplyUpdates;
      end;
      dbEventAndText_View.pSQLQuery1.Next;
    until dbEventAndText_View.pSQLQuery1.EOF;

    //event kapcsolat törlése:
    dbEventAndText_View.Terminate();
    dbEventAndText_View := nil;

    dbLocalSzerverek.pDataset.Next;
  until dbLocalSzerverek.pDataset.EOF;

  dbLocalSzerverek.Terminate();
  dbLocal.Terminate();

end;

procedure TfrmMain.btnFelveteliHibakClick(Sender: TObject);
var
  dbOis_adatok : cMSSQLDatabase;
  dbMachines, dbServers, dbSorok : cSqliteDatabase;

  sSQL : string;
  iSorid : integer;

begin
  //Alkatrész felvételi hibák kikeresése. Ha az "Összes soron keres" be van jelölve akkor minden
  //soron kikeresi az alkatrészhez tartozó felvételi hibákat!
  if chkOsszesSoronKeres.Checked then
  begin
    //összes soron kell keresni...

    exit;
  end;

  //csak a kiválasztott soron kell keresni:
  iSorid := integer(cmbSorok.Items.Objects[cmbSorok.ItemIndex]);
  //kell a szerver azonosító:
  dbSorok := cSqliteDatabase.Create('sorok', 'SELECT * FROM sorok WHERE id = ' + inttostr(iSorid));
  //szerver azonosítója:
  dbServers := cSqliteDatabase.Create('szerverek', 'SELECT * FROM szerverek WHERE sid = ' +
              inttostr(dbSorok.pDataset.FieldByName('sserver_id').AsInteger), 'sid');
  //csatlakozás a kiválasztott sorhoz tartozó szerverre:
  dbOis_adatok := cMSSQLDatabase.Create('SiplaceOisUser', 'VUTB&&42ukbhSnG7',
          dbServers.pDataset.FieldByName('sName').AsString, 'SiplaceOIS');

  sSQL := 'SELECT * FROM SiplaceOIS.dbo.PICKUPERROR, SiplaceOIS.dbo.ErrorMessage, SiplaceOIS.dbo.STATION ' +
          'WHERE SiplaceOIS.dbo.PICKUPERROR.lError LIKE (SiplaceOIS.dbo.ErrorMessage.ErrorNo) ' +
          'AND SiplaceOIS.dbo.ErrorMessage.LanguageCode = ''hu''' +
          'AND SiplaceOIS.dbo.STATION.lId = SiplaceOIS.dbo.PICKUPERROR.lId ' +
          'AND SiplaceOIS.dbo.PICKUPERROR.strPartNumber = ''' + edtAlkatresz.Text + ''' ' +
          'AND SiplaceOIS.dbo.PICKUPERROR.dtCreated >= ''' + medTol.Text + ''' ' +
          'AND SiplaceOIS.dbo.PICKUPERROR.dtCreated <= ''' + medIg.Text + '''';
  dbOis_adatok.RunSQL(sSQL);

  //eredmény exportálás excel-be:



  dbSorok.Terminate();
  dbServers.Terminate();
  dbOis_adatok.Terminate();

end;

procedure TfrmMain.btnRiportKesziteseClick(Sender: TObject);
var
  ois_adatok : cMSSQLDatabase;
  dbMachines : cSqliteDatabase;

  sSQL : string;
  iRowId : integer;

begin
  dbMachines := cSqliteDatabase.Create('machines', 'SELECT * FROM machines WHERE mid = ' +
                inttostr(integer(cmbGepek.Items.Objects[cmbGepek.ItemIndex])), 'mid');

  sSQL := 'SELECT * FROM Events WHERE Date >= ''' + medTol.Text + ''' AND Date <= ''' + medIg.Text + '''' +
          ' AND Station = ''' + dbMachines.pDataset.FieldByName('mhost').AsString + ''' ORDER BY Date';
  ois_adatok := cMSSQLDatabase.Create('lmsadmin', '1Admin%2014', 'tabnt11', 'LMS');
  ois_adatok.RunSQL(sSQL);

  GroupBox2.Caption := 'Riport.....Rekord száma: ' + inttostr(ois_adatok.GetRecordCount());

  stgRiport.Clean([gzNormal]);
  stgRiport.RowCount := 2;
  iRowId := 1;
  repeat
    with ois_adatok.pSQLQuery1 do
    begin
      stgRiport.InsertRowWithValues(iRowId,[FieldByName('Date').AsString, FieldByName('EventCode').AsString]);
      Inc(iRowId);
      Next;
    end;
  until ois_adatok.pSQLQuery1.EOF;

  dbMachines.Terminate();
  ois_adatok.Terminate();

end;

procedure TfrmMain.cmbSorokChange(Sender: TObject);
var
  dbMachines : cSqliteDatabase;

begin
  //Sor váltás történt, frissíteni kell a sorhoz tartozó géplistát:
  dbMachines := cSqliteDatabase.Create('macines', 'SELECT * FROM machines WHERE msorid = ' +
                inttostr(integer(cmbSorok.Items.Objects[cmbSorok.ItemIndex])) + ' ORDER BY mlinepos', 'mid');
  //lista frissítése:
  cmbGepek.Clear;
  repeat
    cmbGepek.Items.AddObject(dbMachines.pDataset.FieldByName('mname').AsString,
    TObject(dbMachines.pDataset.FieldByName('mid').AsInteger));
    dbMachines.pDataset.Next;
  until dbMachines.pDataset.EOF;
  dbMachines.pDataset.First;
  cmbGepek.Text := dbMachines.pDataset.FieldByName('mname').AsString;
  dbMachines.Terminate();

end;

end.

