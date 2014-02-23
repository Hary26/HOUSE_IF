unit unithaus;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, FileUtil, Forms, Controls, Graphics, Dialogs, StdCtrls,
  ExtCtrls, fphttpclient, fpjson, jsonparser,syncobjs,dateutils;

type

  { TSolarData }

  TSolarData=class
  private
    FLock      : TCriticalSection;
  public
    DateString : String;
    TimeString : String;
    KOLLEKTOR_VL : integer;
    KOLLEKTOR_RL : integer;
    KOLLEKTOR_MWL : double;
    WARMWASSER_TUnten : integer;
    PUFFER_Toben      : integer;
    PUFFER_TUnten     : integer;
    KESSEL_OEL        : integer;
    KESSEL_HOLZ       : integer;
    PUMPE_SOLAR       : boolean;
    PUMPE_LADE        : boolean;
    ZONENVENTIL       : String;
    UPDTime           : Integer;
    constructor Create;
    destructor  Destroy;override;
    procedure   UpdateData;
    procedure   LockData;
    procedure   ReleaseData;
  end;

  var
  { TForm1 }
  GCurrent : TSolarData;
  Gserver  : string;


type

  { TUpdateThread }

  TUpdateThread=class(TThread)
  private
  public
    procedure Execute;override;
  end;

  TForm1 = class(TForm)
    Image1: TImage;
    lPSOL: TLabel;
    lKOLLRL: TLabel;
    lPLADE: TLabel;
    lZVentil: TLabel;
    lWWTu: TLabel;
    lKOLLVL: TLabel;
    lKOLLMWL: TLabel;
    lUpdateTS: TLabel;
    lPUTu: TLabel;
    lPUTo: TLabel;
    lKOEL: TLabel;
    lKHolz: TLabel;
    Timer: TTimer;
    procedure FormCreate(Sender: TObject);
    procedure FormPaint(Sender: TObject);
    procedure lWWTu1Click(Sender: TObject);
    procedure TimerTimer(Sender: TObject);
  private
    FUpdater : TUpdateThread;
    { private declarations }
  public


    { public declarations }
  end;

var
  Form1: TForm1;

implementation

{$R *.lfm}

{ TUpdateThread }

procedure TUpdateThread.Execute;
begin
  while not terminated do
   begin
     GCurrent.UpdateData;
     sleep(500);
   end;
end;

{ TSolarData }

constructor TSolarData.Create;
begin
  inherited;
  FLock := TCriticalSection.Create;
end;

destructor TSolarData.Destroy;
begin
  FLock.Free;
  inherited Destroy;
end;

procedure TSolarData.UpdateData;
var s      : string;
    json   : TJSONData;
    jo,jso : TJSONObject;
    jp     : TJSONParser;
    i      : Integer;
    st     : TDateTime;

begin
  With TFPHttpClient.Create(Nil) do
    try
      st := Now;
      s:='';
      try
        S:=Get(gserver)
      except
        UPDTime:=-1;
        exit;
      end;
      UPDTime := MilliSecondsBetween(Now,St);
      FLock.Acquire;
      try
        try
          jp := TJSONParser.Create(s);
          json := jp.Parse;
          if json is TJSONObject then
           begin
             jo := json as TJSONObject;
             jso := jo.Find('TS') as TJSONObject;
             DateString := jso.Find('DATE').AsString;
             TimeString := jso.Find('TIME').AsString;
             jso := jo.Find('KOLLEKTOR') as TJSONObject;
             KOLLEKTOR_VL  := jso.Find('VL').AsInteger;
             KOLLEKTOR_RL  := jso.Find('RL').AsInteger;
             KOLLEKTOR_MWL := jso.Find('MWL').AsFloat;
             jso := jo.Find('WARMWASSER') as TJSONObject;
             WARMWASSER_TUnten  := jso.Find('TUnten').AsInteger;
             jso := jo.Find('PUFFER') as TJSONObject;
             PUFFER_Toben  := jso.Find('TOben').AsInteger;
             PUFFER_TUnten := jso.Find('TUnten').AsInteger;
             jso := jo.Find('KESSEL') as TJSONObject;
             KESSEL_OEL  := jso.Find('OEL').AsInteger;
             KESSEL_HOLZ := jso.Find('HOLZ').AsInteger;
             jso := jo.Find('PUMPEN') as TJSONObject;
             PUMPE_SOLAR  := jso.Find('SOLARPUMPE').AsString='EIN';
             PUMPE_LADE   := jso.Find('LADEPUMPE').AsString='EIN';
             ZONENVENTIL  := jo.Find('ZONENVENTIL').AsString;
           end;
        except
          UPDTime:=-2;
        end;
      finally
        jp.free;
        FLock.Release;
      end;
  finally
    Free;
  end;
end;

procedure TSolarData.LockData;
begin
  FLock.Acquire;
end;

procedure TSolarData.ReleaseData;
begin
  FLock.Release;
end;

{ TForm1 }


procedure TForm1.FormCreate(Sender: TObject);
begin
  if paramstr(1)='' then
   begin
//     Gserver:='http://hinterface.no-ip.org/cgi/json'
     Gserver:='http://10.0.0.123/cgi/json'
   end
  else
    begin
      Gserver:=(paramstr(1));
    end;

  GCurrent:=TSolarData.Create;
  FUpdater:=TUpdateThread.Create(false);
  Timer.Enabled:=true;
end;

procedure TForm1.FormPaint(Sender: TObject);
begin
  Canvas.Draw(0,0,Image1.Picture.Bitmap);
end;

procedure TForm1.lWWTu1Click(Sender: TObject);
begin

end;

procedure TForm1.TimerTimer(Sender: TObject);
begin
  if not assigned(GCurrent) then
   exit;
  GCurrent.LockData;
  try
    if GCurrent.UPDTime>0 then
     begin
       lUpdateTS.Caption:=GCurrent.DateString+' | '+GCurrent.TimeString+' ['+inttostr(GCurrent.UPDTime)+']';
       lKOLLVL.Caption  := inttostr(GCurrent.KOLLEKTOR_VL)+' °C';
       lKOLLRL.Caption  := inttostr(GCurrent.KOLLEKTOR_RL)+' °C';
       lKOLLMWL.Caption := floattostr(GCurrent.KOLLEKTOR_MWL)+' kW';
       lKHolz.Caption   := inttostr(GCurrent.KESSEL_HOLZ)+' °C';
       lKOEL.Caption    := inttostr(GCurrent.KESSEL_OEL)+' °C';
       lPUTo.Caption    := inttostr(GCurrent.PUFFER_Toben)+' °C';
       lPUTu.Caption    := inttostr(GCurrent.PUFFER_TUnten)+' °C';
       lWWTu.Caption    := inttostr(GCurrent.WARMWASSER_TUnten)+' °C';
       lPLADE.Caption   := BoolToStr(GCurrent.PUMPE_LADE,'EIN','AUS');
       lPSOL.Caption    := BoolToStr(GCurrent.PUMPE_SOLAR,'EIN','AUS');
       lZVentil.Caption := GCurrent.ZONENVENTIL;
     end
    else
      if GCurrent.UPDTime=-2 then
        lUpdateTS.Caption:='PARSE FAIL'
      else
        lUpdateTS.Caption:='NET FAIL'
  finally
    GCurrent.ReleaseData;
  end;
end;

end.

