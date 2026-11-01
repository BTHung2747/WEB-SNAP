# AGPL-3.0 lab glue: fixed labels/numbers only, standard subprocess APIs.
import contextlib,json,os,pathlib,subprocess,time
OPS={'DOWNLOADER','OUTPUT_CHECK','FFPROBE','CONTRACT','DECODE','HASH','MUX','STREAM_HASH'}
POLICY_CODES={'MP4_CONTAINER_REQUIRED','H264_AUDIO_REQUIRED','HEVC_AUDIO_REQUIRED','VIDEO_CODEC_POLICY','AUDIO_CODEC_MISMATCH','DURATION_POLICY','METADATA_DURATION_POLICY',
 'VIDEO_DIMENSION_POLICY','TIMELINE_MISMATCH','MUX_FAIL','STREAM_HASH_FAIL','STREAM_COPY_MISMATCH','FILE_METADATA_DURATION_MISMATCH','FILE_LIMIT_OR_MISSING','FFPROBE_FAIL','DECODE_FAIL','PREPARE_DEADLINE'}
class Operations:
    def __init__(self,deadline=None,sink='tiktok-operations.jsonl',root=None):
        self.deadline=deadline if deadline is not None else time.monotonic()+180
        root=pathlib.Path(root).resolve() if root is not None else pathlib.Path('/media')
        self.path=root/sink;self.terminals=[];self.events=0
        if self.path.parent!=root or not sink.endswith('.jsonl') or self.path.is_symlink():raise ValueError('TRACE_PATH_POLICY')
    def emit(self,row):
        if self.events>=32:raise RuntimeError('TRACE_EVENT_CAP')
        self.events+=1
        fd=os.open(self.path,os.O_WRONLY|os.O_CREAT|os.O_APPEND|os.O_NOFOLLOW,0o600)
        with os.fdopen(fd,'a',encoding='utf8') as f:f.write(json.dumps(row,separators=(',',':'))+'\n')
    def timeout(self,cap,reserve=0):
        remaining=self.deadline-time.monotonic()-reserve
        if remaining<=0:raise RuntimeError('PREPARE_DEADLINE')
        return min(cap,remaining)
    @contextlib.contextmanager
    def step(self,operation,timeout=None):
        if operation not in OPS:raise ValueError('OPERATION_POLICY')
        start=time.monotonic();row={'operation':operation,'event':'BEGIN','code':'BEGIN','elapsed':0,
                                  'timeout':timeout,'returncode':None}
        self.emit(row.copy())
        try:
            yield row
        except Exception as error:
            row['event']='ERROR'
            if type(error) is subprocess.TimeoutExpired:row['code']='SUBPROCESS_TIMEOUT'
            elif type(error) is RuntimeError and len(error.args)==1 and type(error.args[0]) is str and error.args[0] in POLICY_CODES:row['code']=error.args[0]
            else:row['code']='UNKNOWN_ERROR'
            raise
        else:row.update(event='END',code='OK')
        finally:
            row['elapsed']=round(time.monotonic()-start,6);self.emit(row.copy());self.terminals.append(row.copy())
    def native(self,operation,argv,cap,capture=False,reserve=0):
        try:timeout=self.timeout(cap,reserve)
        except RuntimeError:
            # Record a rejected operation without spawning; no zero timeout reaches Popen.
            with self.step(operation,0):raise
        with self.step(operation,timeout) as row:
            p=subprocess.Popen(argv,stdin=subprocess.DEVNULL,stdout=subprocess.PIPE if capture else subprocess.DEVNULL,
                               stderr=subprocess.DEVNULL)
            try:out,_=p.communicate(timeout=timeout)
            except subprocess.TimeoutExpired:
                p.kill();p.communicate();row['returncode']=p.returncode
                raise # cmd/output stay inside RAM; whitelist exports the type only.
            row['returncode']=p.returncode
            if p.returncode:raise RuntimeError({'FFPROBE':'FFPROBE_FAIL','MUX':'MUX_FAIL','STREAM_HASH':'STREAM_HASH_FAIL'}.get(operation,'DECODE_FAIL'))
            return subprocess.CompletedProcess(argv,p.returncode,out,None)
