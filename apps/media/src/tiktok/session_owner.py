"""AGPL-3.0: shared Response/Session ownership; moved unchanged from photo_core."""
from .photo_contract import require

class SessionOwner:
    """Delegate public Session/Adapter APIs; retain responses until physical close.

    GuardedYDL can reject a deadline/cancel after Adapter.send returns and before
    its body wrapper exists. Owning that returned Response closes this gap without
    changing HTTP/TLS, exceptions, redirect behavior or cookie preparation.
    """
    def __init__(self, base):
        self.base = base
        self.responses = []
        self.closed = False

    @property
    def cookies(self):
        return self.base.cookies

    @cookies.setter
    def cookies(self, value):
        self.base.cookies = value

    @property
    def trust_env(self):
        return self.base.trust_env

    @trust_env.setter
    def trust_env(self, value):
        self.base.trust_env = value

    def prepare_request(self, request):
        return self.base.prepare_request(request)

    def get_adapter(self, url):
        adapter = self.base.get_adapter(url)
        owner = self

        class ResponseOwner:
            def send(self, *args, **kwargs):
                response = adapter.send(*args, **kwargs)
                owner.responses.append(response)
                return response
        return ResponseOwner()

    def close(self):
        if self.closed:
            return
        self.closed = True
        failed = False
        for response in self.responses:
            try:
                response.close()
            except Exception:
                failed = True
        self.responses.clear()
        try:
            self.base.close()
        except Exception:
            failed = True
        finally:
            self.base.cookies.clear()
        require(not failed, 'CONTENT_UNAVAILABLE')
