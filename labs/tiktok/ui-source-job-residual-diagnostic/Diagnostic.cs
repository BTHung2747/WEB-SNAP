using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Runtime.InteropServices;
namespace WedJobDiagnostic {
 [StructLayout(LayoutKind.Sequential,Pack=8)] public struct PIDHeaderLayout {public uint Assigned,Count;public UIntPtr First;}
 internal static class DN {
  [DllImport("kernel32.dll",ExactSpelling=true,SetLastError=true,EntryPoint="QueryInformationJobObject")]
  [return:MarshalAs(UnmanagedType.Bool)] internal static extern bool Query(IntPtr job,int kind,IntPtr data,uint bytes,out uint returned);
  [DllImport("kernel32.dll",ExactSpelling=true,SetLastError=true)] internal static extern uint GetProcessId(IntPtr process);
 }
 public sealed class PIDList {
  public bool Complete;public string Code;public uint? Assigned,Count;public List<uint> PIDs=new List<uint>();
 }
 public sealed class PIDObservation {
  public uint PID;public bool RootNumericMatch;public long? Creation;public bool? Member,Identity;public uint? Wait,Exit;public int? Error;public string Code;
 }
 public sealed class JobSnapshot {
  public string Point,Code;public double BeginMs,AccountingMs,ListMs,EndMs;public bool? AccountingOK,ListOK;public int? AccountingError,ListError;public uint AccountingLength,ListLength;public uint? Active,Total,Terminated;public PIDList List;public List<PIDObservation> Rows=new List<PIDObservation>();
 }
 public sealed class Diagnostic {
  public int SnapshotAttempts,SkippedTail;public bool Complete=true;public string Code="OBSERVATIONS_NOT_ATOMIC";public double OverheadMs;public List<JobSnapshot> Snapshots=new List<JobSnapshot>();
  internal Dictionary<uint,long> Seen=new Dictionary<uint,long>();
 }
 public static class Collector {
  public const int PIDCap=16,SnapshotCap=3,PIDBufferBytes=136;
  public static Dictionary<string,int> Layout(){
   var d=new Dictionary<string,int>{{"DWORD",4},{"ULONG_PTR",IntPtr.Size},{"HeaderSize",Marshal.SizeOf<PIDHeaderLayout>()},{"AssignedOffset",(int)Marshal.OffsetOf<PIDHeaderLayout>("Assigned")},{"CountOffset",(int)Marshal.OffsetOf<PIDHeaderLayout>("Count")},{"ListOffset",(int)Marshal.OffsetOf<PIDHeaderLayout>("First")},{"AccountingSize",Marshal.SizeOf<Accounting>()},{"ActiveOffset",(int)Marshal.OffsetOf<Accounting>("Active")},{"BufferBytes",PIDBufferBytes}};
   if(IntPtr.Size!=8||d["HeaderSize"]!=16||d["AssignedOffset"]!=0||d["CountOffset"]!=4||d["ListOffset"]!=8||d["AccountingSize"]!=48||d["ActiveOffset"]!=40)throw new InvalidOperationException("DIAG_LAYOUT");return d;
  }
  // Public pure decoder exercises bounds only; not an emulator of Win32.
  public static PIDList Decode(bool success,int error,uint returned,byte[] bytes){
   var o=new PIDList{Code="UNKNOWN"};
   if(!success){o.Code=error==234?"MORE_DATA_NO_READ":"NATIVE_FAIL_NO_READ";return o;}
   if(bytes==null||bytes.Length!=PIDBufferBytes||returned<8||returned>PIDBufferBytes){o.Code="RETURN_LENGTH_INVALID";return o;}
   uint assigned=BitConverter.ToUInt32(bytes,0),count=BitConverter.ToUInt32(bytes,4);o.Assigned=assigned;o.Count=count;
   if(assigned>PIDCap||count>PIDCap||assigned!=count){o.Code="COUNT_INCOMPLETE_NO_PID_READ";return o;}
   if(returned<8+8*count){o.Code="RETURN_LENGTH_SHORT_NO_PID_READ";return o;}
   var seen=new HashSet<uint>();
   for(int i=0;i<count;i++){ulong pid=BitConverter.ToUInt64(bytes,8+8*i);if(pid==0||pid>uint.MaxValue||!seen.Add((uint)pid)){o.PIDs.Clear();o.Code="PID_INVALID_OR_DUPLICATE";return o;}o.PIDs.Add((uint)pid);}
   o.Complete=true;o.Code="BOUNDED_LIST_COMPLETE";return o;
  }
  public static string IdentityCode(uint listed,uint queried,bool member,long creation,long? prior){
   if(listed==0||listed!=queried)return "PID_MISMATCH";
   if(!member)return "NOT_IN_OWN_JOB";
   if(creation<=0)return "CREATION_UNKNOWN";
   if(prior.HasValue&&prior.Value!=creation)return "CREATION_CHANGED";
   return "OWN_IDENTITY_OBSERVED";
  }
  public static int PayloadLength(uint assigned,uint count,uint returned){
   if(returned<8||returned>PIDBufferBytes||assigned>PIDCap||count>PIDCap||assigned!=count||returned<8+8*count)return 8;
   return 8+8*(int)count;
  }
  private static PIDObservation Inspect(uint pid,IntPtr job,IntPtr root,Result r){
   var row=new PIDObservation{PID=pid,RootNumericMatch=pid==r.RootPID,Code="UNKNOWN"};
   // Never reopen a released root: another reference could extend its lifetime.
   if(row.RootNumericMatch&&root==IntPtr.Zero){row.Code="ROOT_RELEASED_NOT_REOPENED";return row;}
   K opened=null;IntPtr h=root;
   try{
    if(!row.RootNumericMatch){IntPtr p=N.OpenProcess(0x101000,false,pid);if(p==IntPtr.Zero){row.Error=Marshal.GetLastWin32Error();row.Code="OPEN_FAILED";return row;}opened=new K(p);h=opened.P;}
    uint queried=DN.GetProcessId(h);if(queried==0){row.Error=Marshal.GetLastWin32Error();row.Code="GET_PID_FAILED";return row;}
    bool member;if(!N.IsProcessInJob(h,job,out member)){row.Error=Marshal.GetLastWin32Error();row.Code="MEMBERSHIP_FAILED";return row;}row.Member=member;
    FT c,e,k,u;if(!N.GetProcessTimes(h,out c,out e,out k,out u)){row.Error=Marshal.GetLastWin32Error();row.Code="CREATION_FAILED";return row;}row.Creation=c.Value;
    long previous;long? expected=r.Diagnostics.Seen.TryGetValue(pid,out previous)?(long?)previous:null;
    if(row.RootNumericMatch)expected=r.RootCreationFileTime;
    row.Code=IdentityCode(pid,queried,member,c.Value,expected);row.Identity=row.Code=="OWN_IDENTITY_OBSERVED";
    if(!row.Identity.Value)return row;
    r.Diagnostics.Seen[pid]=c.Value;
    uint wait=N.WaitForSingleObject(h,0);row.Wait=wait;
    if(wait==0){uint exit;if(N.GetExitCodeProcess(h,out exit))row.Exit=exit;else{row.Error=Marshal.GetLastWin32Error();row.Code="EXIT_QUERY_FAILED";}}
    else if(wait!=258){row.Error=Marshal.GetLastWin32Error();row.Code="WAIT_FAILED";}
   }catch{row.Code="COLLECTOR_PID_ERROR";}finally{if(opened!=null)opened.Dispose();}
   return row;
  }
  internal static void Capture(IntPtr job,IntPtr root,Result r,Stopwatch clock,string point){
   var d=r.Diagnostics;if(d.SnapshotAttempts>=SnapshotCap)return;d.SnapshotAttempts++;
   if(job==IntPtr.Zero){d.Complete=false;d.Code="NULL_JOB_REJECTED";return;}
   // Preserve the original 400ms cleanup tail; never add a wait or grace.
   if(clock.Elapsed.TotalMilliseconds>=r.LimitMs-400){d.Complete=false;d.SkippedTail++;d.Code="TAIL_OBSERVATION_SKIPPED";return;}
   var watch=Stopwatch.StartNew();var s=new JobSnapshot{Point=point,BeginMs=clock.Elapsed.TotalMilliseconds,Code="OBSERVATION"};d.Snapshots.Add(s);
   try{
    if(r.DiagnosticFault)throw new InvalidOperationException("SYNTHETIC_COLLECTOR_FAULT");
    using(var b=new M(48)){
     uint length;bool ok=DN.Query(job,1,b.P,48,out length);s.AccountingOK=ok;s.AccountingError=ok?(int?)null:Marshal.GetLastWin32Error();s.AccountingLength=length;s.AccountingMs=clock.Elapsed.TotalMilliseconds;
     if(ok&&length==48){var a=Marshal.PtrToStructure<Accounting>(b.P);s.Active=a.Active;s.Total=a.Total;s.Terminated=a.Terminated;}else{d.Complete=false;s.Code="ACCOUNTING_UNKNOWN";}
    }
    if(clock.Elapsed.TotalMilliseconds>=r.LimitMs-400){d.Complete=false;s.Code="TAIL_LIST_SKIPPED";return;}
    using(var b=new M(PIDBufferBytes)){
     uint length;bool ok=DN.Query(job,3,b.P,PIDBufferBytes,out length);int error=ok?0:Marshal.GetLastWin32Error();s.ListOK=ok;s.ListError=ok?(int?)null:error;s.ListLength=length;s.ListMs=clock.Elapsed.TotalMilliseconds;
     byte[] bytes=null;
     // Do not even copy native memory on failure or invalid returned length.
     if(ok&&length>=8&&length<=PIDBufferBytes){
      bytes=new byte[PIDBufferBytes];Marshal.Copy(b.P,bytes,0,8);
      int needed=PayloadLength(BitConverter.ToUInt32(bytes,0),BitConverter.ToUInt32(bytes,4),length);
      if(needed>8)Marshal.Copy(IntPtr.Add(b.P,8),bytes,8,needed-8);
     }
     s.List=Decode(ok,error,length,bytes);
     if(!s.List.Complete){d.Complete=false;s.Code=s.List.Code;return;}
     foreach(uint pid in s.List.PIDs){
      if(clock.Elapsed.TotalMilliseconds>=r.LimitMs-400){d.Complete=false;s.Code="TAIL_PID_SKIPPED";break;}
      var row=Inspect(pid,job,root,r);s.Rows.Add(row);
      if(row.Code!="OWN_IDENTITY_OBSERVED"){d.Complete=false;}
     }
    }
   }catch{d.Complete=false;s.Code="COLLECTOR_ERROR_NO_MESSAGE";}
   finally{s.EndMs=clock.Elapsed.TotalMilliseconds;d.OverheadMs+=watch.Elapsed.TotalMilliseconds;}
  }
 }
}
