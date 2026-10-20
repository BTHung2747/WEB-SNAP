"""Deadline/admission glue only. Public library owns staggered TCP and socket closing."""
import asyncio,math,time
PAIR_MIN=1.0;SINGLE_MIN=.6;GROUP_MAX=2.0;REAP=.1;MAX_GROUPS=4
class BudgetStop(RuntimeError):
    def __init__(self,code):self.code=code;super().__init__(code)
def allocation(remaining,addresses_left,trace_groups):
    minimum=SINGLE_MIN if addresses_left==1 else PAIR_MIN
    if not math.isfinite(remaining) or remaining<minimum:raise BudgetStop('TCP_BUDGET_EXHAUSTED')
    k=min(math.ceil(addresses_left/2),trace_groups,math.floor(remaining/minimum))
    if k<=0:raise BudgetStop('TRACE_ADMISSION_LIMIT')
    return min(remaining,GROUP_MAX,max(minimum,remaining/k))

async def library_group(call,active_end,total_end,registry):
    # One scoped public-library task, not a new race. All candidate tasks are
    # library-owned and must be reaped by its finally before this returns.
    task=asyncio.create_task(call());registry.pending.add(task)
    timeout=False
    try:
        done,_=await asyncio.wait({task},timeout=max(0,active_end-time.monotonic()))
        if not done:
            timeout=True;registry.epoch_active=False;task.cancel()
            done,_=await asyncio.wait({task},timeout=max(0,total_end-time.monotonic()))
            if not done:
                registry.epoch_active=False;registry.close();registry.reap_failed=True
                # Abort cleanup may use remaining *global* TCP time. Never start
                # another group after missing the local reap deadline.
                await asyncio.wait({task},timeout=max(0,registry.deadline-time.monotonic()))
                if task.done():
                    try:task.result()
                    except BaseException:pass
                raise BudgetStop('GROUP_REAP_DEADLINE')
        if time.monotonic()>total_end:
            registry.epoch_active=False;registry.close();raise BudgetStop('GROUP_REAP_DEADLINE')
        if timeout:
            try:task.result()
            except asyncio.CancelledError:pass
            except BaseException as exc:registry.secondary.append(type(exc).__name__)
            raise BudgetStop('GROUP_TIMEOUT')
        return task.result()
    except asyncio.CancelledError:
        registry.epoch_active=False;task.cancel()
        await asyncio.wait({task},timeout=max(0,total_end-time.monotonic()))
        if not task.done():registry.reap_failed=True;registry.close()
        else:
            try:task.result()
            except BaseException:pass
        raise
    finally:
        if task.done():registry.pending.discard(task)
        extra=[t for t in registry.worker_tasks if not t.done()]
        if extra:registry.reap_failed=True;registry.epoch_active=False

async def connect_groups(addresses,deadline,registry,*,loop,staggered,library):
    registry.deadline=deadline if registry.deadline is None else min(registry.deadline,deadline)
    deadline=registry.deadline;trace=registry.trace;ctx=getattr(loop,'ctx',None)
    ctx_id=getattr(ctx,'cid',registry.context_id)
    registry.context_id=ctx_id
    if trace and not trace.attach_connection(registry.cid,ctx_id):raise BudgetStop('TRACE_ADMISSION_LIMIT')
    last=None
    try:
        for offset in range(0,len(addresses),2):
            if registry.groups>=MAX_GROUPS:raise BudgetStop('TRACE_ADMISSION_LIMIT')
            group=addresses[offset:offset+2];remaining=deadline-time.monotonic()
            registry.remaining_at_admission=remaining
            capacity=trace.group_capacity(registry.cid,ctx_id,len(group)) if trace else MAX_GROUPS-registry.groups
            q=allocation(remaining,len(addresses)-offset,min(capacity,MAX_GROUPS-registry.groups))
            if trace and not trace.admit_group(registry.cid,ctx_id,len(group)):raise BudgetStop('TRACE_ADMISSION_LIMIT')
            registry.groups+=1;number=registry.groups;started=time.monotonic();h=min(deadline,started+q);a=h-REAP
            registry.epoch=number;registry.epoch_active=True;registry.active_deadline=a
            before=len(registry.sockets);registry.group_index=number;success=False;error=None
            if trace:trace.observe(registry.cid,'LIBRARY_SELECT','BEGIN',code='BEGIN',groupIndex=number,totalSeconds=q,activeSeconds=q-REAP,remaining=remaining,live=registry.live())
            def factory(info,epoch=number):
                if not registry.epoch_active or registry.epoch!=epoch or time.monotonic()>=a:
                    registry.late_denied+=1;raise BudgetStop('EPOCH_CLOSED')
                return registry.factory(info)
            registry.last_factory=factory # RAM-only epoch control, never serialized
            try:
                winner=await library_group(lambda:library(group,happy_eyeballs_delay=.25 if staggered else None,interleave=0,socket_factory=factory,loop=loop),a,h,registry)
                if registry.reap_failed:raise BudgetStop('GROUP_REAP_DEADLINE')
                if any(s is not winner and s.fileno()!=-1 for s in registry.sockets):raise BudgetStop('LOSER_NOT_CLOSED')
                success=True;registry.stop_code='WINNER';return winner
            except BudgetStop as exc:
                error=exc
                if exc.code!='GROUP_TIMEOUT':raise
                last=exc
            except OSError as exc:error=exc;last=exc
            except BaseException as exc:error=exc;raise
            finally:
                registry.epoch_active=False
                if trace:trace.observe(registry.cid,'LIBRARY_SELECT','END' if success else 'ERROR',code='OK' if success else 'ERROR',groupIndex=number,live=registry.live(),pending=len(registry.pending),closed=sum(s.fileno()==-1 for s in registry.sockets[before:]))
                registry.records.append({'group':number,'q':q,'active':q-REAP,'elapsed':time.monotonic()-started,'created':len(registry.sockets)-before,'closed':sum(s.fileno()==-1 for s in registry.sockets[before:]),'live':registry.live(),'pending':len(registry.pending),'success':success})
                if trace and not registry.pending:trace.release_group(registry.cid,ctx_id)
            if registry.pending or registry.reap_failed or registry.live():raise BudgetStop('LOSER_NOT_CLOSED')
            if trace and trace.incomplete:raise BudgetStop('TRACE_INCOMPLETE')
        if last is not None:raise last # exact exception object from the public call
        raise BudgetStop('NO_ADDRESSES')
    except BaseException as exc:
        registry.stop_code=exc.code if isinstance(exc,BudgetStop) else 'CANCELLED' if isinstance(exc,asyncio.CancelledError) else 'LIBRARY_ERROR'
        registry.epoch_active=False
        raise
    finally:registry.suffix_unknown=max(0,len(addresses)-len(registry.order))
