unit FirebirdServices;
{$mode objfpc}{$H+}
interface
uses Classes,SysUtils,ibase60dyn;
type
  TServiceOperation=(soBackup,soRestore,soSweep,soValidate,soServerLog);
  TServiceOptions=record
    BackupMetadataOnly,BackupNoGarbageCollection,BackupIgnoreLimbo,
      BackupIgnoreChecksums,BackupConvertExternalTables,BackupNonTransportable:Boolean;
    RestoreReplace,RestoreCommitEachTable,RestoreNoShadow,
      RestoreDeactivateIndices,RestoreNoValidity,RestoreUseAllSpace:Boolean;
    RestorePageSize:LongWord;
    Verbose:Boolean;
  end;
  TServiceOutput=procedure(const Line:string) of object;
procedure RunService(const ServiceName,UserName,Password,Role,DatabasePath,BackupPath:string;
  Operation:TServiceOperation;Output:TServiceOutput); overload;
procedure RunService(const ServiceName,UserName,Password,Role,DatabasePath:string;
  BackupFiles:TStrings;const Options:TServiceOptions;Operation:TServiceOperation;
  Output:TServiceOutput); overload;
implementation
function ShortItem(Tag:Byte;const Value:string):string;
begin
  if Length(Value)>255 then raise Exception.Create('Service credential exceeds 255 bytes');
  Result:=Chr(Tag)+Chr(Length(Value))+Value;
end;
function LongItem(Tag:Byte;const Value:string):string;
begin
  if Length(Value)>65535 then raise Exception.Create('Service path exceeds 65535 bytes');
  Result:=Chr(Tag)+Chr(Length(Value) and 255)+Chr(Length(Value) shr 8)+Value;
end;
function NumberItem(Tag:Byte;Value:LongWord):string;
begin
  Result:=Chr(Tag)+Chr(Value and 255)+Chr((Value shr 8) and 255)+Chr((Value shr 16) and 255)+Chr((Value shr 24) and 255);
end;
procedure RunService(const ServiceName,UserName,Password,Role,DatabasePath,BackupPath:string;
  Operation:TServiceOperation;Output:TServiceOutput);
var Files:TStringList;Options:TServiceOptions;
begin
  Files:=TStringList.Create;
  try
    if BackupPath<>'' then Files.Add(BackupPath);
    Options:=Default(TServiceOptions);Options.Verbose:=True;
    RunService(ServiceName,UserName,Password,Role,DatabasePath,Files,Options,Operation,Output);
  finally Files.Free;end;
end;

procedure RunService(const ServiceName,UserName,Password,Role,DatabasePath:string;
  BackupFiles:TStrings;const Options:TServiceOptions;Operation:TServiceOperation;
  Output:TServiceOutput);
var Status:array[0..19] of ISC_STATUS;Handle:isc_svc_handle;
    SPB,Request,Send,Receive,Line:string;Buffer:array[0..8191] of AnsiChar;
    L,I:Integer;Flags:LongWord;P:PISC_STATUS;ErrorBuffer:array[0..2047] of AnsiChar;ErrorText:string;
  procedure Check(Code:ISC_STATUS);
  begin
    if Code=0 then Exit;
    P:=@Status[0];ErrorText:='';
    while isc_interprete(@ErrorBuffer[0],@P)>0 do begin
      if ErrorText<>'' then ErrorText:=ErrorText+LineEnding;
      ErrorText:=ErrorText+StrPas(@ErrorBuffer[0]);
    end;
    raise Exception.Create(ErrorText);
  end;
  procedure Query(Tag:Byte);
  begin
    FillChar(Buffer,SizeOf(Buffer),0);Receive:=Chr(Tag);
    Check(isc_service_query(@Status[0],@Handle,nil,Length(Send),PChar(Send),1,PChar(Receive),SizeOf(Buffer),@Buffer[0]));
    if Byte(Buffer[0])=isc_info_error then raise Exception.Create('Service query returned an error');
  end;
begin
  if not Assigned(isc_service_attach) then raise Exception.Create('Load Firebird client before using services');
  if (Operation<>soServerLog) and (Trim(DatabasePath)='') then raise Exception.Create('Database path is required');
  if (Operation in [soBackup,soRestore]) and ((BackupFiles=nil) or (BackupFiles.Count=0)) then raise Exception.Create('Backup path is required');
  FillChar(Status,SizeOf(Status),0);Handle:=0;
  SPB:=Chr(isc_spb_version)+Chr(isc_spb_current_version)+ShortItem(isc_spb_user_name,UserName)+ShortItem(isc_spb_password,Password);
  if Role<>'' then SPB:=SPB+ShortItem(isc_spb_sql_role_name,Role);
  SPB:=SPB+Chr(118)+Chr(0); // isc_spb_utf8_filename, empty flag clumplet
  try
    Check(isc_service_attach(@Status[0],Length(ServiceName),PChar(ServiceName),@Handle,Length(SPB),PChar(SPB)));
    SPB:='';
    case Operation of
      soBackup:begin
        Flags:=0;
        if Options.BackupMetadataOnly then Flags:=Flags or isc_spb_bkp_metadata_only;
        if Options.BackupNoGarbageCollection then Flags:=Flags or isc_spb_bkp_no_garbage_collect;
        if Options.BackupIgnoreLimbo then Flags:=Flags or isc_spb_bkp_ignore_limbo;
        if Options.BackupIgnoreChecksums then Flags:=Flags or isc_spb_bkp_ignore_checksums;
        if Options.BackupConvertExternalTables then Flags:=Flags or isc_spb_bkp_convert;
        if Options.BackupNonTransportable then Flags:=Flags or isc_spb_bkp_non_transportable;
        Request:=Chr(isc_action_svc_backup)+LongItem(isc_spb_dbname,DatabasePath);
        for I:=0 to BackupFiles.Count-1 do Request:=Request+LongItem(isc_spb_bkp_file,BackupFiles[I]);
        Request:=Request+NumberItem(isc_spb_options,Flags);
        if Options.Verbose then Request:=Request+Chr(isc_spb_verbose);
      end;
      soRestore:begin
        Flags:=isc_spb_res_create;
        if Options.RestoreReplace then Flags:=isc_spb_res_replace;
        if Options.RestoreCommitEachTable then Flags:=Flags or isc_spb_res_one_at_a_time;
        if Options.RestoreNoShadow then Flags:=Flags or isc_spb_res_no_shadow;
        if Options.RestoreDeactivateIndices then Flags:=Flags or isc_spb_res_deactivate_idx;
        if Options.RestoreNoValidity then Flags:=Flags or isc_spb_res_no_validity;
        if Options.RestoreUseAllSpace then Flags:=Flags or isc_spb_res_use_all_space;
        Request:=Chr(isc_action_svc_restore);
        for I:=0 to BackupFiles.Count-1 do Request:=Request+LongItem(isc_spb_bkp_file,BackupFiles[I]);
        Request:=Request+LongItem(isc_spb_dbname,DatabasePath)+
          NumberItem(isc_spb_res_page_size,Options.RestorePageSize)+NumberItem(isc_spb_options,Flags);
        if Options.Verbose then Request:=Request+Chr(isc_spb_verbose);
      end;
      soSweep:Request:=Chr(isc_action_svc_repair)+LongItem(isc_spb_dbname,DatabasePath)+NumberItem(isc_spb_options,isc_spb_rpr_sweep_db);
      soValidate:Request:=Chr(isc_action_svc_repair)+LongItem(isc_spb_dbname,DatabasePath)+NumberItem(isc_spb_options,isc_spb_rpr_validate_db or isc_spb_rpr_check_db);
      soServerLog:Request:=Chr(isc_action_svc_get_ib_log);
    end;
    Check(isc_service_start(@Status[0],@Handle,nil,Length(Request),PChar(Request)));
    Send:=NumberItem(isc_info_svc_timeout,1);
    while True do begin
      Query(isc_info_svc_line);
      if Byte(Buffer[0])=isc_info_svc_line then begin
        L:=Byte(Buffer[1])+(Byte(Buffer[2]) shl 8);
        if L>SizeOf(Buffer)-4 then raise Exception.Create('Invalid service response length');
        if L>0 then begin
          SetString(Line,PChar(@Buffer[3]),L);
          if Assigned(Output) then Output(Line);
          Continue;
        end;
      end;
      Query(isc_info_svc_running);
      if (Byte(Buffer[0])=isc_info_svc_running) and (Byte(Buffer[1])=0) and
        (Byte(Buffer[2])=0) and (Byte(Buffer[3])=0) and (Byte(Buffer[4])=0) then Break;
      Sleep(20);
    end;
  finally
    SPB:='';
    if Handle<>0 then isc_service_detach(@Status[0],@Handle);
  end;
end;
end.
