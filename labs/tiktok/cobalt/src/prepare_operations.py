# AGPL-3.0 lab glue: fixed labels/numbers only, standard subprocess APIs.
import contextlib,json,pathlib,subprocess,time
OPS={'DOWNLOADER','OUTPUT_CHECK','FFPROBE','CONTRACT','DECODE','HASH'}
POLICY_CODES={'MP4_CONTAINER_REQUIRED','H264_AUDIO_REQUIRED','DURATION_POLICY','METADATA_DURATION_POLICY',
 'FILE_METADATA_DURATION_MISMATCH','FILE_LIMIT_OR_MISSING','FFPROBE_FAIL','DECODE_FAIL','PREPARE_DEADLINE'}
class Operations:
    def __init__(self,deadline=None,sink='prepare-operations.jsonl'):
        self.deadline=deadline if deadline is not None else time.monotonic()+180
        self.path=pathlib.Path('/out')/sink;self.terminals=[];self.events=0
        if self.path.parent!=pathlib.Path('/out') or not sink.endswith('.jsonl'):raise ValueError('TRACE_PATH_POLICY')
    def emit(self,row):
        if self.events>=32:raise RuntimeError('TRACE_EVENT_CAP')
        self.events+=1
        with self.path.open('a',encoding='utf8') as f:f.write(json.dumps(row,separators=(',',':'))+'\n')
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
            if p.returncode:raise RuntimeError('FFPROBE_FAIL' if operation=='FFPROBE' else 'DECODE_FAIL')
            return subprocess.CompletedProcess(argv,p.returncode,out,None)
