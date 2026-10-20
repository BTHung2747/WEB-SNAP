"""Extend owned Budget only: aggregate quota, absolute album and item deadlines."""
from tiktok.core import Budget
from album_contract import MIB,require,item_deadline
class AlbumBudget(Budget):
    def __init__(self,end):
        super().__init__(input_cap=116*MIB,output_cap=16*MIB,deadline=end)
        self.metadata_bytes=0;self.output_bytes=0;self.image_requests=0;self.selected_count=0;self.prepare_end=None
    def begin_album(self,n,end):
        require(self.mode=='metadata' and type(n) is int and 1<=n<=5,'ALBUM_BUDGET')
        self.metadata_bytes=self.total;self.mode='prepare';self.max_requests=n;self.selected_count=n
        self.input_cap=(16+20*n)*MIB;self.total_cap=(16+20*n)*MIB
        self.prepare_end=end;self.phase_deadline=end;self.response_cap=20*MIB
        # requests/total/network_total never reset; metadata already consumed allowance.
        self.deadline=item_deadline(end)
    def begin_item(self):self.deadline=item_deadline(self.prepare_end)
    def sent(self):
        if self.mode=='metadata':return super().sent()
        self.check()
        if self.image_requests>=self.selected_count:self.fail('REQUEST_LIMIT')
        self.image_requests+=1;self.requests+=1
        row={'index':self.image_requests,'phase':'prepare','method':'GET','url':'[url-redacted]','decodedBytes':0}
        self.rows.append(row);return row
    def write_check(self,item_bytes,increment):
        if item_bytes+increment>16*MIB or self.output_bytes+increment>16*self.selected_count*MIB:self.fail('OUTPUT_LIMIT')
        self.output_bytes+=increment;self.check()
    def prepare(self):raise RuntimeError('ALBUM_RESET_DENIED')
