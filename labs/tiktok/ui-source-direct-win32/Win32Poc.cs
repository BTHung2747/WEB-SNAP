// Offline-only direct Win32 glue. Provenance/layout: evidence API_LAYOUT.md.
using System;
using System.IO;
using System.Text;
using System.Diagnostics;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using Microsoft.Win32.SafeHandles;
[assembly: DefaultDllImportSearchPaths(DllImportSearchPath.System32)]
namespace WedDirectWin32 {
 [StructLayout(LayoutKind.Sequential, Pack=8)] public struct SA { public uint Length; public IntPtr Descriptor; public int Inherit; }
 [StructLayout(LayoutKind.Sequential, Pack=8)] public struct SI { public uint cb; public IntPtr Reserved,Desktop,Title; public uint X,Y,XSize,YSize,XCount,YCount,Fill,Flags; public ushort Show,ReservedCount; public IntPtr Reserved2,Input,Output,Error; }
 [StructLayout(LayoutKind.Sequential, Pack=8)] public struct SIX { public SI Startup; public IntPtr Attributes; }
 [StructLayout(LayoutKind.Sequential, Pack=8)] public struct PI { public IntPtr Process,Thread; public uint PID,TID; }
 [StructLayout(LayoutKind.Sequential, Pack=8)] public struct BasicLimits { public long ProcessTime,JobTime; public uint Flags; public UIntPtr Minimum,Maximum; public uint ActiveLimit; public UIntPtr Affinity; public uint Priority,Scheduling; }
 [StructLayout(LayoutKind.Sequential, Pack=8)] public struct IO { public ulong ReadOps,WriteOps,OtherOps,ReadBytes,WriteBytes,OtherBytes; }
 [StructLayout(LayoutKind.Sequential, Pack=8)] public struct Limits { public BasicLimits Basic; public IO Io; public UIntPtr ProcessMemory,JobMemory,PeakProcess,PeakJob; }
 [StructLayout(LayoutKind.Sequential, Pack=8)] public struct Accounting { public long User,Kernel,PeriodUser,PeriodKernel; public uint Faults,Total,Active,Terminated; }
 [StructLayout(LayoutKind.Sequential)] internal struct FT { public uint Low,High; public long Value { get {return (long)(((ulong)High<<32)|Low);} } }
 internal static class N {
  [DllImport("kernel32.dll",ExactSpelling=true,SetLastError=true)] internal static extern IntPtr GetCurrentProcess();
  [DllImport("kernel32.dll",ExactSpelling=true,SetLastError=true)] [return:MarshalAs(UnmanagedType.Bool)] internal static extern bool CloseHandle(IntPtr h);
  [DllImport("kernel32.dll",ExactSpelling=true,SetLastError=true)] [return:MarshalAs(UnmanagedType.Bool)] internal static extern bool GetHandleInformation(IntPtr h,out uint flags);
  [DllImport("kernel32.dll",ExactSpelling=true,SetLastError=true)] [return:MarshalAs(UnmanagedType.Bool)] internal static extern bool SetHandleInformation(IntPtr h,uint mask,uint flags);
  [DllImport("kernel32.dll",ExactSpelling=true,SetLastError=true)] [return:MarshalAs(UnmanagedType.Bool)] internal static extern bool GetProcessHandleCount(IntPtr p,out uint count);
  [DllImport("kernel32.dll",ExactSpelling=true,SetLastError=true)] internal static extern uint WaitForSingleObject(IntPtr h,uint ms);
  [DllImport("kernel32.dll",ExactSpelling=true,SetLastError=true)] [return:MarshalAs(UnmanagedType.Bool)] internal static extern bool GetExitCodeProcess(IntPtr h,out uint code);
  [DllImport("kernel32.dll",ExactSpelling=true,SetLastError=true)] internal static extern IntPtr OpenProcess(uint access,[MarshalAs(UnmanagedType.Bool)]bool inherit,uint pid);
  [DllImport("kernel32.dll",ExactSpelling=true,SetLastError=true)] [return:MarshalAs(UnmanagedType.Bool)] internal static extern bool GetProcessTimes(IntPtr p,out FT creation,out FT exit,out FT kernel,out FT user);
  [DllImport("kernel32.dll",ExactSpelling=true,SetLastError=true,CharSet=CharSet.Unicode)] internal static extern IntPtr CreateJobObjectW(IntPtr security,string name);
  [DllImport("kernel32.dll",ExactSpelling=true,SetLastError=true)] [return:MarshalAs(UnmanagedType.Bool)] internal static extern bool SetInformationJobObject(IntPtr job,int kind,ref Limits data,uint size);
  [DllImport("kernel32.dll",ExactSpelling=true,SetLastError=true,EntryPoint="QueryInformationJobObject")] [return:MarshalAs(UnmanagedType.Bool)] internal static extern bool QueryLimits(IntPtr job,int kind,out Limits data,uint size,IntPtr length);
  [DllImport("kernel32.dll",ExactSpelling=true,SetLastError=true,EntryPoint="QueryInformationJobObject")] [return:MarshalAs(UnmanagedType.Bool)] internal static extern bool QueryAccounting(IntPtr job,int kind,out Accounting data,uint size,IntPtr length);
  [DllImport("kernel32.dll",ExactSpelling=true,SetLastError=true)] [return:MarshalAs(UnmanagedType.Bool)] internal static extern bool TerminateJobObject(IntPtr job,uint code);
  [DllImport("kernel32.dll",ExactSpelling=true,SetLastError=true)] [return:MarshalAs(UnmanagedType.Bool)] internal static extern bool IsProcessInJob(IntPtr process,IntPtr job,[MarshalAs(UnmanagedType.Bool)]out bool result);
  [DllImport("kernel32.dll",ExactSpelling=true,SetLastError=true)] [return:MarshalAs(UnmanagedType.Bool)] internal static extern bool CreatePipe(out IntPtr read,out IntPtr write,ref SA security,uint size);
  [DllImport("kernel32.dll",ExactSpelling=true,SetLastError=true)] [return:MarshalAs(UnmanagedType.Bool)] internal static extern bool PeekNamedPipe(IntPtr pipe,IntPtr buffer,uint size,IntPtr read,out uint available,IntPtr remaining);
  [DllImport("kernel32.dll",ExactSpelling=true,SetLastError=true)] [return:MarshalAs(UnmanagedType.Bool)] internal static extern bool ReadFile(IntPtr pipe,[Out]byte[] buffer,uint size,out uint read,IntPtr overlapped);
  [DllImport("kernel32.dll",ExactSpelling=true,SetLastError=true)] [return:MarshalAs(UnmanagedType.Bool)] internal static extern bool InitializeProcThreadAttributeList(IntPtr list,uint count,uint flags,ref UIntPtr size);
  [DllImport("kernel32.dll",ExactSpelling=true,SetLastError=true)] [return:MarshalAs(UnmanagedType.Bool)] internal static extern bool UpdateProcThreadAttribute(IntPtr list,uint flags,UIntPtr attribute,IntPtr value,UIntPtr size,IntPtr previous,IntPtr returned);
  [DllImport("kernel32.dll",ExactSpelling=true)] internal static extern void DeleteProcThreadAttributeList(IntPtr list);
  [DllImport("kernel32.dll",ExactSpelling=true,SetLastError=true,CharSet=CharSet.Unicode)] [return:MarshalAs(UnmanagedType.Bool)] internal static extern bool CreateProcessW(string app,StringBuilder command,IntPtr ps,IntPtr ts,[MarshalAs(UnmanagedType.Bool)]bool inherit,uint flags,IntPtr env,string cwd,ref SIX startup,out PI info);
 }
 internal sealed class NativeFailure:Exception { internal string Phase; internal int Error; internal NativeFailure(string phase,int error){Phase=phase;Error=error;} }
 internal sealed class K:SafeHandleZeroOrMinusOneIsInvalid {
  internal static int Live,CloseErrors;
  internal K(IntPtr h):base(true){SetHandle(h);if(IsInvalid)throw new InvalidOperationException("INVALID_HANDLE");Live++;}
  internal IntPtr P {get{return DangerousGetHandle();}}
  protected override bool ReleaseHandle(){bool ok=N.CloseHandle(handle);if(ok)Live--;else CloseErrors++;return ok;}
 }
 internal sealed class M:IDisposable {
  internal static int Live; internal IntPtr P; internal M(int size){if(size<1||size>65536)throw new InvalidOperationException("BUFFER_SIZE");P=Marshal.AllocHGlobal(size);Live++;}
  public void Dispose(){if(P!=IntPtr.Zero){Marshal.FreeHGlobal(P);P=IntPtr.Zero;Live--;}}
 }
 public sealed class Event { public string Code; public double Ms; public uint? Active; }
 public sealed class Result {
  public string Mode="OFFLINE_TEST_ONLY",Case,Status="FAIL",Phase,FaultKind;
  public int? Win32Error; public long? RootExit; public uint? BeforeRootRelease,AfterRootRelease,FinalActive,PeakActive;
  public bool Created,RootInOwnJob,HostInJob,JobHandleNonInherited,LimitsVerified,Timeout,ByteCapExceeded,TerminationRequested,TreeClosed,PipesEOF,CleanupClosed;
  public int ByteCap,LimitMs,RetainedBytes,LiveHandles,LiveBuffers,CloseErrors,BackgroundReaders;
  public long StdoutBytes,StderrBytes; public ulong PeakJobMemory,MemoryLimitBytes; public double ElapsedMs; public uint HandleCountBefore,HandleCountAfter,ActiveLimitActual,LimitFlagsActual;
  public string RawOut,RawErr; public List<Event> Events=new List<Event>();
 }
 public sealed class Identity { public uint PID; public long CreationFileTime; public bool VerifiedInOwnedJob; }
 public sealed class Observer:IDisposable {
  private K process; public uint PID; public long? Exit;
  internal Observer(Identity id){process=new K(N.OpenProcess(0x100400,false,id.PID));try{if(Poc.Creation(process.P)!=id.CreationFileTime)throw new InvalidOperationException("PID_IDENTITY_CHANGED");PID=id.PID;}catch{process.Dispose();throw;}}
  public bool Wait(int ms){uint w=N.WaitForSingleObject(process.P,(uint)ms);if(w==0){uint code;Poc.OK(N.GetExitCodeProcess(process.P,out code),"OBSERVE_EXIT");Exit=code;return true;}if(w==258)return false;throw new NativeFailure("OBSERVE_WAIT",Marshal.GetLastWin32Error());}
  public void Dispose(){if(process!=null){process.Dispose();process=null;}}
 }
 public sealed class Session:IDisposable {
  internal K job,root,thread,output,error,outChild,errChild,inChild,inParent;
  private M attributes,jobArray,handleArray; private bool listInitialized;
  private MemoryStream outMemory=new MemoryStream(),errMemory=new MemoryStream(); private byte[] readBuffer=new byte[4096];
  private bool outEOF,errEOF; private Stopwatch clock=Stopwatch.StartNew(); internal Result r; internal uint rootPID;
  public uint RootPID {get{return rootPID;}} public string Output {get{return Encoding.UTF8.GetString(outMemory.ToArray());}}
  internal Session(Result result){r=result;}
  private void Mark(string code,uint? active=null){if(r.Events.Count<64)r.Events.Add(new Event{Code=code,Ms=clock.Elapsed.TotalMilliseconds,Active=active});}
  private void Pipe(out K read,out K write){SA sa=new SA{Length=(uint)Marshal.SizeOf<SA>(),Inherit=1};IntPtr a,b;Poc.OK(N.CreatePipe(out a,out b,ref sa,4096),"CREATE_PIPE");read=new K(a);write=new K(b);}
  internal void Create(string exe,string fixture,string mode,string[] argv){
   bool host;Poc.OK(N.IsProcessInJob(N.GetCurrentProcess(),IntPtr.Zero,out host),"HOST_JOB");r.HostInJob=host;
   Mark("JOB_REGISTER_BEGIN");IntPtr j=N.CreateJobObjectW(IntPtr.Zero,null);if(j==IntPtr.Zero)throw new NativeFailure("CREATE_JOB",Marshal.GetLastWin32Error());job=new K(j);Mark("JOB_REGISTERED");
   uint inherited;Poc.OK(N.GetHandleInformation(job.P,out inherited),"JOB_HANDLE_FLAGS");r.JobHandleNonInherited=(inherited&1)==0;if(!r.JobHandleNonInherited)throw new InvalidOperationException("JOB_HANDLE_INHERITED");
   Limits limits=new Limits{Basic=new BasicLimits{Flags=0x2208,ActiveLimit=4},JobMemory=new UIntPtr(256UL*1024*1024)};
   Poc.OK(N.SetInformationJobObject(job.P,9,ref limits,(uint)Marshal.SizeOf<Limits>()),"SET_LIMITS");Limits actual;Poc.OK(N.QueryLimits(job.P,9,out actual,(uint)Marshal.SizeOf<Limits>(),IntPtr.Zero),"READBACK_LIMITS");
   r.MemoryLimitBytes=actual.JobMemory.ToUInt64();r.ActiveLimitActual=actual.Basic.ActiveLimit;r.LimitFlagsActual=actual.Basic.Flags;
   r.LimitsVerified=actual.Basic.Flags==0x2208&&actual.Basic.ActiveLimit==4&&actual.JobMemory.ToUInt64()==268435456;if(!r.LimitsVerified)throw new InvalidOperationException("LIMIT_READBACK");Mark("LIMITS_VERIFIED");
   Pipe(out output,out outChild);Pipe(out error,out errChild);Pipe(out inChild,out inParent);
   foreach(K h in new K[]{output,error,inParent})Poc.OK(N.SetHandleInformation(h.P,1,0),"PIPE_PARENT_NOINHERIT");
   UIntPtr size=UIntPtr.Zero;bool initial=N.InitializeProcThreadAttributeList(IntPtr.Zero,2,0,ref size);int initialError=Marshal.GetLastWin32Error();if(initial||initialError!=122||size.ToUInt64()==0)throw new NativeFailure("ATTRIBUTE_SIZE",initialError);
   attributes=new M(checked((int)size.ToUInt64()));Poc.OK(N.InitializeProcThreadAttributeList(attributes.P,2,0,ref size),"ATTRIBUTE_INIT");listInitialized=true;
   jobArray=new M(IntPtr.Size);Marshal.WriteIntPtr(jobArray.P,job.P);handleArray=new M(3*IntPtr.Size);Marshal.Copy(new IntPtr[]{inChild.P,outChild.P,errChild.P},0,handleArray.P,3);
   Poc.OK(N.UpdateProcThreadAttribute(attributes.P,0,new UIntPtr(0x2000D),jobArray.P,new UIntPtr(mode=="attribute-failure"?1u:(uint)IntPtr.Size),IntPtr.Zero,IntPtr.Zero),"ATTRIBUTE_JOB_LIST");
   Poc.OK(N.UpdateProcThreadAttribute(attributes.P,0,new UIntPtr(0x20002),handleArray.P,new UIntPtr((uint)(3*IntPtr.Size)),IntPtr.Zero,IntPtr.Zero),"ATTRIBUTE_HANDLE_LIST");Mark("ATTRIBUTES_READY");
   SIX startup=new SIX{Startup=new SI{cb=(uint)Marshal.SizeOf<SIX>(),Flags=0x100,Input=inChild.P,Output=outChild.P,Error=errChild.P},Attributes=attributes.P};
   List<string> words=new List<string>{exe,"--max-old-space-size=32",fixture,mode};if(argv!=null)words.AddRange(argv);
   if(mode=="create-failure"){exe=Path.Combine(Path.GetDirectoryName(fixture),"OFFLINE_TEST_ONLY_MISSING.exe");words[0]=exe;}
   StringBuilder command=new StringBuilder(Poc.CommandLine(words));PI pi;Mark("CREATE_AT_JOB_BEGIN");
   bool created=N.CreateProcessW(exe,command,IntPtr.Zero,IntPtr.Zero,true,0x08080000,IntPtr.Zero,Path.GetDirectoryName(fixture),ref startup,out pi);int errorCode=created?0:Marshal.GetLastWin32Error();
   if(!created)throw new NativeFailure("CREATE_PROCESS",errorCode);
   root=new K(pi.Process);thread=new K(pi.Thread);rootPID=pi.PID;r.Created=true;Mark("CREATE_AT_JOB_END");
   bool member;Poc.OK(N.IsProcessInJob(root.P,job.P,out member),"ROOT_JOB_MEMBERSHIP");r.RootInOwnJob=member;if(!member)throw new InvalidOperationException("NOT_IN_OWN_JOB");
   thread.Dispose();thread=null;outChild.Dispose();outChild=null;errChild.Dispose();errChild=null;inChild.Dispose();inChild=null;inParent.Dispose();inParent=null;ReleaseAttributes();
  }
  private void ReleaseAttributes(){if(listInitialized){N.DeleteProcThreadAttributeList(attributes.P);listInitialized=false;}if(attributes!=null){attributes.Dispose();attributes=null;}if(jobArray!=null){jobArray.Dispose();jobArray=null;}if(handleArray!=null){handleArray.Dispose();handleArray=null;}}
  internal uint Active(){Accounting a;Poc.OK(N.QueryAccounting(job.P,1,out a,(uint)Marshal.SizeOf<Accounting>(),IntPtr.Zero),"QUERY_ACTIVE");r.PeakActive=Math.Max(r.PeakActive??0,a.Active);return a.Active;}
  private void Drain(K pipe,MemoryStream memory,ref bool eof,bool stderr){
   if(eof)return;uint available;bool ok=N.PeekNamedPipe(pipe.P,IntPtr.Zero,0,IntPtr.Zero,out available,IntPtr.Zero);int e=ok?0:Marshal.GetLastWin32Error();if(!ok){if(e==109){eof=true;return;}throw new NativeFailure("PEEK_PIPE",e);}if(available==0)return;
   uint n;Poc.OK(N.ReadFile(pipe.P,readBuffer,Math.Min(available,4096),out n,IntPtr.Zero),"READ_AVAILABLE");if(stderr)r.StderrBytes+=n;else r.StdoutBytes+=n;
   int keep=Math.Min((int)n,Math.Max(0,r.ByteCap-(int)(outMemory.Length+errMemory.Length)));if(keep>0)memory.Write(readBuffer,0,keep);
   if(r.StdoutBytes+r.StderrBytes>r.ByteCap)r.ByteCapExceeded=true;
  }
  public void Pump(){Drain(output,outMemory,ref outEOF,false);Drain(error,errMemory,ref errEOF,true);}
  private void Stop(){if(!r.TerminationRequested){Poc.OK(N.TerminateJobObject(job.P,0xE0000001),"TERMINATE_OWN_JOB");r.TerminationRequested=true;Mark("TERMINATE_OWN_JOB");}}
  internal void ObserveRoot(){if(root==null)return;uint wait=N.WaitForSingleObject(root.P,0);if(wait==258)return;if(wait!=0)throw new NativeFailure("WAIT_ROOT",Marshal.GetLastWin32Error());uint code;Poc.OK(N.GetExitCodeProcess(root.P,out code),"ROOT_EXIT");r.RootExit=code;r.BeforeRootRelease=Active();Mark("ROOT_EXIT_CAPTURED",r.BeforeRootRelease);root.Dispose();root=null;Mark("ROOT_HANDLE_RELEASED");r.AfterRootRelease=Active();}
  internal void Finish(){
   while(clock.ElapsedMilliseconds<r.LimitMs){Pump();ObserveRoot();uint active=Active();
    if(r.RootExit.HasValue&&active>0)Stop();
    if(r.ByteCapExceeded)Stop();
    if(!r.RootExit.HasValue&&clock.ElapsedMilliseconds>=r.LimitMs-400){r.Timeout=true;Stop();}
    if(r.RootExit.HasValue&&active==0&&outEOF&&errEOF)break;
    System.Threading.Thread.Sleep(2);
   }
   ObserveRoot();r.FinalActive=Active();r.TreeClosed=r.FinalActive==0;r.PipesEOF=outEOF&&errEOF;
   Limits info;Poc.OK(N.QueryLimits(job.P,9,out info,(uint)Marshal.SizeOf<Limits>(),IntPtr.Zero),"PEAK_MEMORY");r.PeakJobMemory=info.PeakJob.ToUInt64();
   r.Status=r.RootExit==0&&r.TreeClosed&&r.PipesEOF&&!r.Timeout&&!r.TerminationRequested&&!r.ByteCapExceeded?"PASS":"FAIL";Mark("FINAL_JOB_QUERY",r.FinalActive);
  }
  public Identity MemberIdentity(uint pid){using(K p=new K(N.OpenProcess(0x100400,false,pid))){bool member;Poc.OK(N.IsProcessInJob(p.P,job.P,out member),"IDENTITY_MEMBERSHIP");if(!member)throw new InvalidOperationException("FOREIGN_FIXTURE_PID");return new Identity{PID=pid,CreationFileTime=Poc.Creation(p.P),VerifiedInOwnedJob=true};}}
  public void Dispose(){
   try{if(job!=null){uint active=Active();if(active>0){Stop();long allowance=Math.Max(0,Math.Min(400,r.LimitMs-clock.ElapsedMilliseconds));Stopwatch cleanup=Stopwatch.StartNew();while(cleanup.ElapsedMilliseconds<allowance){ObserveRoot();if(Active()==0)break;System.Threading.Thread.Sleep(2);}}ObserveRoot();r.FinalActive=Active();r.TreeClosed=r.FinalActive==0;}}
   catch(NativeFailure x){r.Phase=x.Phase;r.Win32Error=x.Error;r.TreeClosed=false;r.Status="FAIL";}
   finally{foreach(K h in new K[]{root,thread,output,error,outChild,errChild,inChild,inParent})if(h!=null)h.Dispose();root=null;ReleaseAttributes();if(job!=null){job.Dispose();job=null;}r.RetainedBytes=(int)(outMemory.Length+errMemory.Length);r.RawOut=Encoding.UTF8.GetString(outMemory.ToArray());r.RawErr=Encoding.UTF8.GetString(errMemory.ToArray());outMemory.Dispose();errMemory.Dispose();r.LiveHandles=K.Live;r.LiveBuffers=M.Live;r.CloseErrors=K.CloseErrors;r.BackgroundReaders=0;r.ElapsedMs=clock.Elapsed.TotalMilliseconds;r.CleanupClosed=r.TreeClosed&&r.LiveHandles==0&&r.LiveBuffers==0&&r.CloseErrors==0;}
  }
 }
 public static class Poc {
  internal static void OK(bool value,string phase){if(!value){int error=Marshal.GetLastWin32Error();throw new NativeFailure(phase,error);}}
  internal static long Creation(IntPtr process){FT c,e,k,u;OK(N.GetProcessTimes(process,out c,out e,out k,out u),"IDENTITY_TIME");return c.Value;}
  public static Observer Observe(Identity id){if(!id.VerifiedInOwnedJob)throw new InvalidOperationException("NO_OWNED_IDENTITY");return new Observer(id);}
  public static uint HandleCount(){uint count;OK(N.GetProcessHandleCount(N.GetCurrentProcess(),out count),"HANDLE_COUNT");return count;}
  public static Dictionary<string,int> Ownership(){return new Dictionary<string,int>{{"liveHandles",K.Live},{"liveBuffers",M.Live},{"closeErrors",K.CloseErrors},{"backgroundReaders",0}};}
  private static string Quote(string word){if(word.IndexOf('\0')>=0)throw new InvalidOperationException("ARGUMENT_NUL");StringBuilder b=new StringBuilder("\"");int slash=0;foreach(char c in word){if(c=='\\'){slash++;continue;}if(c=='\"'){b.Append('\\',slash*2+1);b.Append(c);}else{b.Append('\\',slash);b.Append(c);}slash=0;}b.Append('\\',slash*2);b.Append('"');return b.ToString();}
  internal static string CommandLine(IEnumerable<string> words){List<string> result=new List<string>();foreach(string word in words)result.Add(Quote(word));string command=string.Join(" ",result);if(command.Length>=32767)throw new InvalidOperationException("COMMAND_CAP");return command;}
  public static Dictionary<string,int> Layout(){
   if(IntPtr.Size!=8)throw new InvalidOperationException("X64_ONLY");var d=new Dictionary<string,int>();
   Type[] types={typeof(SA),typeof(SI),typeof(SIX),typeof(PI),typeof(BasicLimits),typeof(IO),typeof(Limits),typeof(Accounting),typeof(FT)};int[] sizes={24,104,112,24,64,48,144,48,8};
   for(int i=0;i<types.Length;i++){int actual=Marshal.SizeOf(types[i]);d[types[i].Name]=actual;if(actual!=sizes[i])throw new InvalidOperationException("LAYOUT_SIZE");}
   Action<Type,string,int> offset=(type,name,expected)=>{int actual=(int)Marshal.OffsetOf(type,name);d[type.Name+"."+name]=actual;if(actual!=expected)throw new InvalidOperationException("LAYOUT_OFFSET");};
   offset(typeof(SA),"Descriptor",8);offset(typeof(SA),"Inherit",16);offset(typeof(SI),"Flags",60);offset(typeof(SI),"Reserved2",72);offset(typeof(SI),"Input",80);offset(typeof(SI),"Output",88);offset(typeof(SI),"Error",96);offset(typeof(SIX),"Attributes",104);offset(typeof(PI),"PID",16);offset(typeof(BasicLimits),"Flags",16);offset(typeof(BasicLimits),"Minimum",24);offset(typeof(BasicLimits),"ActiveLimit",40);offset(typeof(BasicLimits),"Affinity",48);offset(typeof(Limits),"Io",64);offset(typeof(Limits),"JobMemory",120);offset(typeof(Limits),"PeakJob",136);offset(typeof(Accounting),"Active",40);return d;
  }
  public static Result Run(string exe,string fixture,string mode,string[] argv,int limitMs,int cap){
   Layout();if(limitMs<800||limitMs>5000||cap<256||cap>1048576||!Path.IsPathFullyQualified(exe)||!Path.IsPathFullyQualified(fixture))throw new InvalidOperationException("POC_LIMITS");
   Result r=new Result{Case=mode,ByteCap=cap,LimitMs=limitMs,HandleCountBefore=HandleCount()};Session s=new Session(r);
   try{s.Create(exe,fixture,mode,argv);s.Finish();}catch(NativeFailure x){r.Phase=x.Phase;r.Win32Error=x.Error;r.FaultKind="ACTUAL_WIN32_RETURN";}catch{r.Phase="MANAGED_GUARD";r.FaultKind="MANAGED_GUARD_NO_MESSAGE";}
   finally{s.Dispose();r.HandleCountAfter=HandleCount();if(!r.CleanupClosed)r.Status="FAIL";}return r;
  }
  public static Session StartCrashOwner(string exe,string fixture){Layout();Result r=new Result{Case="CRASH_OWNER",ByteCap=8192,LimitMs=5000};Session s=new Session(r);try{s.Create(exe,fixture,"hold",null);return s;}catch{s.Dispose();throw;}}
 }
}
