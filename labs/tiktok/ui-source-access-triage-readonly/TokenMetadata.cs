using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Diagnostics;
using System.IO;
using System.Runtime.InteropServices;
using System.Security.Principal;
using System.Text;
using Microsoft.Win32.SafeHandles;

namespace WedReadOnlyTriage {
 [StructLayout(LayoutKind.Sequential,Pack=8)] struct SidAttributes { public IntPtr Sid; public uint Attributes; }
 [StructLayout(LayoutKind.Sequential)] struct FT { public uint Low,High; public long Value {get{return (long)(((ulong)High<<32)|Low);}} }
 sealed class ReadFailure:Exception { internal string Phase; internal int Code; internal ReadFailure(string p,int c){Phase=p;Code=c;} }
 static class N {
  [DllImport("advapi32.dll",ExactSpelling=true,SetLastError=true)] [return:MarshalAs(UnmanagedType.Bool)] internal static extern bool GetTokenInformation(SafeAccessTokenHandle t,int cls,IntPtr data,uint size,out uint required);
  [DllImport("advapi32.dll",ExactSpelling=true,SetLastError=true,EntryPoint="GetTokenInformation")] [return:MarshalAs(UnmanagedType.Bool)] internal static extern bool TokenDword(SafeAccessTokenHandle t,int cls,out uint data,uint size,out uint required);
  [DllImport("advapi32.dll",ExactSpelling=true,SetLastError=true)] [return:MarshalAs(UnmanagedType.Bool)] internal static extern bool IsTokenRestricted(SafeAccessTokenHandle t);
  [DllImport("advapi32.dll",ExactSpelling=true,SetLastError=true)] [return:MarshalAs(UnmanagedType.Bool)] internal static extern bool OpenProcessToken(SafeProcessHandle p,uint access,out SafeAccessTokenHandle token);
  [DllImport("kernel32.dll",ExactSpelling=true,SetLastError=true)] internal static extern SafeProcessHandle OpenProcess(uint access,[MarshalAs(UnmanagedType.Bool)]bool inherit,uint pid);
  [DllImport("kernel32.dll",ExactSpelling=true,SetLastError=true)] [return:MarshalAs(UnmanagedType.Bool)] internal static extern bool GetProcessTimes(SafeProcessHandle p,out FT creation,out FT exit,out FT kernel,out FT user);
  [DllImport("kernel32.dll",ExactSpelling=true,CharSet=CharSet.Unicode,SetLastError=true)] [return:MarshalAs(UnmanagedType.Bool)] internal static extern bool QueryFullProcessImageNameW(SafeProcessHandle p,uint flags,StringBuilder text,ref uint size);
 }
 public static class Metadata {
  static int processHandles,tokenHandles,buffers;
  static void OK(bool ok,string phase){if(!ok)throw new ReadFailure(phase,Marshal.GetLastPInvokeError());}
  static object Attempt(string field,Func<object> action,List<object> errors){try{return action();}catch(ReadFailure e){errors.Add(new{field,phase=e.Phase,win32Error=(int?)e.Code});}catch(Win32Exception e){errors.Add(new{field,phase="MANAGED_WIN32_READ",win32Error=(int?)e.NativeErrorCode});}catch{errors.Add(new{field,phase="MANAGED_READ_ERROR",win32Error=(int?)null});}return null;}
  static uint Dword(SafeAccessTokenHandle t,int cls){uint value,length;OK(N.TokenDword(t,cls,out value,4,out length),"TOKEN_DWORD_"+cls);if(length!=4)throw new ReadFailure("TOKEN_DWORD_SIZE",0);return value;}
  static SecurityIdentifier Sid(SafeAccessTokenHandle t,int cls){
   uint length;bool first=N.GetTokenInformation(t,cls,IntPtr.Zero,0,out length);int error=Marshal.GetLastPInvokeError();
   if(first||error!=122||length<16||length>4096)throw new ReadFailure("TOKEN_SID_LENGTH",error);
   IntPtr data=Marshal.AllocHGlobal((int)length);buffers++;
   try{uint actual;OK(N.GetTokenInformation(t,cls,data,length,out actual),"TOKEN_SID_READ");if(actual<16||actual>length)throw new ReadFailure("TOKEN_SID_SIZE",0);return new SecurityIdentifier(Marshal.ReadIntPtr(data));}
   finally{Marshal.FreeHGlobal(data);buffers--;}
  }
  static string Integrity(SecurityIdentifier sid){
   foreach(var pair in new[]{(WellKnownSidType.WinUntrustedLabelSid,"UNTRUSTED"),(WellKnownSidType.WinLowLabelSid,"LOW"),(WellKnownSidType.WinMediumLabelSid,"MEDIUM"),(WellKnownSidType.WinMediumPlusLabelSid,"MEDIUM_PLUS"),(WellKnownSidType.WinHighLabelSid,"HIGH"),(WellKnownSidType.WinSystemLabelSid,"SYSTEM")})if(sid.IsWellKnown(pair.Item1))return pair.Item2;
   return "OTHER_UNKNOWN_LABEL";
  }
  public static Dictionary<string,int> Layout(){if(IntPtr.Size!=8||Marshal.SizeOf<SidAttributes>()!=16||Marshal.OffsetOf<SidAttributes>("Attributes").ToInt32()!=8||Marshal.SizeOf<FT>()!=8)throw new InvalidOperationException("X64_LAYOUT_REQUIRED");return new Dictionary<string,int>{{"pointer",8},{"SID_AND_ATTRIBUTES",16},{"AttributesOffset",8},{"FILETIME",8},{"DWORD",4}};}
  static object Inspect(Process candidate,string role,SecurityIdentifier currentUser,int? currentSession,string dockerRoot){
   var errors=new List<object>();var row=new Dictionary<string,object>{{"role",role},{"pid",candidate.Id},{"status","UNKNOWN"},{"errors",errors},{"ownerSameUser",null},{"startUTC",null},{"sessionID",null},{"sameSession",null},{"fileVersion",null},{"identityVerified",false}};
   object observed=Attempt("processMetadata",()=>{
    using(SafeProcessHandle p=N.OpenProcess(0x1000,false,(uint)candidate.Id)){
     if(p.IsInvalid)throw new ReadFailure("PROCESS_QUERY_LIMITED",Marshal.GetLastPInvokeError());processHandles++;
     try{
      FT a,b,c,d;OK(N.GetProcessTimes(p,out a,out b,out c,out d),"PROCESS_CREATION_TIME");long creation=a.Value;
      var image=new StringBuilder(32768);uint size=32768;OK(N.QueryFullProcessImageNameW(p,0,image,ref size),"PROCESS_IMAGE_NAME");string path=image.ToString();
      if(!string.Equals(Path.GetFileName(path),role+".exe",StringComparison.OrdinalIgnoreCase)||!Path.GetFullPath(path).StartsWith(dockerRoot+Path.DirectorySeparatorChar,StringComparison.OrdinalIgnoreCase))throw new ReadFailure("PROCESS_IMAGE_SCOPE_UNCONFIRMED",0);
      row["imageInExpectedDockerRoot"]=true;row["startUTC"]=DateTime.FromFileTimeUtc(creation).ToString("o");
      row["sessionID"]=Attempt("sessionID",()=>candidate.SessionId,errors);if(row["sessionID"] is int session&&currentSession.HasValue)row["sameSession"]=session==currentSession.Value;
      if(currentUser!=null){row["ownerSameUser"]=Attempt("ownerEquality",()=>{
       SafeAccessTokenHandle token;bool opened=N.OpenProcessToken(p,8,out token);int e=Marshal.GetLastPInvokeError();
       if(!opened){if(token!=null)token.Dispose();throw new ReadFailure("PROCESS_TOKEN_QUERY",e);}tokenHandles++;
       try{using(token){return currentUser.Equals(Sid(token,1));}}finally{tokenHandles--;}
      },errors);}
      row["fileVersion"]=Attempt("fileVersion",()=>{
       string walk=path;while(!string.IsNullOrEmpty(walk)){if((File.GetAttributes(walk)&FileAttributes.ReparsePoint)!=0)throw new ReadFailure("IMAGE_REPARSE_REFUSED",0);walk=Path.GetDirectoryName(walk);}
       string value=FileVersionInfo.GetVersionInfo(path).FileVersion;
       return value!=null&&System.Text.RegularExpressions.Regex.IsMatch(value,@"\A[A-Za-z0-9 .+_-]{1,64}\z")?(object)value:null;
      },errors);
      OK(N.GetProcessTimes(p,out a,out b,out c,out d),"PROCESS_CREATION_RECHECK");if(a.Value!=creation)throw new ReadFailure("PROCESS_IDENTITY_CHANGED",0);
      row["identityVerified"]=true;row["status"]=errors.Count==0?"OBSERVED_METADATA":"PARTIAL_METADATA_UNKNOWN_FIELDS";return true;
     }finally{processHandles--;}
    }
   },errors);
   if(observed==null){row["ownerSameUser"]=null;row["identityVerified"]=false;}
   return row;
  }
  public static object Capture(string dockerRoot){
   Layout();var errors=new List<object>();var self=new Dictionary<string,object>{{"status","UNKNOWN"},{"userNameOrSIDExported",false},{"errors",errors}};
   var roles=new List<object>();WindowsIdentity identity=null;SecurityIdentifier currentUser=null;int? currentSession=null;
   try{
    var read=Attempt("currentIdentity",()=>{identity=WindowsIdentity.GetCurrent(TokenAccessLevels.Query);currentUser=identity.User;self["impersonationLevel"]=identity.ImpersonationLevel.ToString();self["userAvailable"]=currentUser!=null;return true;},errors);
    if(read!=null){
     var t=identity.AccessToken;
     self["tokenSessionID"]=Attempt("tokenSessionID",()=>Dword(t,12),errors);if(self["tokenSessionID"] is uint sid)currentSession=(int)sid;
     self["elevationType"]=Attempt("elevationType",()=>{uint v=Dword(t,18);return v==1?"DEFAULT":v==2?"FULL":v==3?"LIMITED":"OTHER_UNKNOWN";},errors);
     self["elevated"]=Attempt("elevated",()=>Dword(t,20)!=0,errors);
     self["hasRestrictionsFilteredFlag"]=Attempt("hasRestrictionsFilteredFlag",()=>Dword(t,21)!=0,errors);
     self["restrictingSIDListPresent"]=Attempt("restrictingSIDListPresent",()=>{bool restricted=N.IsTokenRestricted(t);int e=Marshal.GetLastPInvokeError();if(!restricted&&e!=0)throw new ReadFailure("TOKEN_RESTRICTED_FLAG",e);return restricted;},errors);
     self["integrity"]=Attempt("integrity",()=>Integrity(Sid(t,25)),errors);
     self["appContainer"]=Attempt("appContainer",()=>{bool app=Dword(t,29)!=0;if(!app&&identity.ImpersonationLevel==TokenImpersonationLevel.Identification)return null;return (object)app;},errors);
     self["status"]=errors.Count==0?"OBSERVED_TOKEN_FIELDS":"PARTIAL_TOKEN_UNKNOWN_FIELDS";
    }
    int total=0;
    foreach(string name in new[]{"Docker Desktop","com.docker.backend"}){
     var failures=new List<object>();var rows=new List<object>();Process[] candidates=null;
     object lookup=Attempt("scopedProcessLookup",()=>{candidates=Process.GetProcessesByName(name);return true;},failures);
     if(candidates!=null){try{foreach(var candidate in candidates){if(total>=16){failures.Add(new{field="candidateCount",phase="BOUNDED_CANDIDATE_LIMIT",win32Error=(int?)null});break;}total++;rows.Add(Inspect(candidate,name,currentUser,currentSession,dockerRoot));}}finally{foreach(var p in candidates)p.Dispose();}}
     roles.Add(new{role=name,lookupStatus=lookup==null?"UNKNOWN":"OBSERVED_SCOPED_SNAPSHOT",candidateCount=candidates==null?(int?)null:candidates.Length,rows,errors=failures});
    }
   }finally{if(identity!=null)identity.Dispose();}
   return new{status="METADATA_SNAPSHOT_NOT_DAEMON_HEALTH",current=self,processes=roles,ownership=new{processHandles,tokenHandles,buffers,windowsIdentityDisposed=true},utc=DateTimeOffset.UtcNow.ToString("o"),pipeMetadata="NOT_RUN_NO_OPEN_OR_CONNECT",historicalTokenEquality="UNKNOWN_NO_HISTORICAL_TOKEN_SNAPSHOT"};
  }
 }
}
