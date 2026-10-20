"""Lab-only CPython child search path; source/vendor readonly mounts, no fixture hooks."""
import os
PATH='/repo/apps/egress/src:/repo/apps/egress/vendor'
def configure():
    os.environ['PYTHONPATH']=PATH
