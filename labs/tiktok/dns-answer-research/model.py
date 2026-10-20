"""Research models only: no DNS, sockets, runtime integration or source gate.

Counting/equivalence policy is WED SNAP glue. Numeric parsing delegates to
Python3.11.2 ipaddress; connection tests delegate to public aiohappyeyeballs.
"""
import ipaddress
import socket
import time

RAW_CAP = 64
UNIQUE_CAP = 64
WITNESS_RAW_BOUND = 65  # Minimum experimental witness, NOT a proposed runtime cap.
COUNT_BYTES = 512


def number(value, top):
    return type(value) is int and 0 <= value <= top


def endpoint_key(row):
    """Conservative key; retain the original first row for any simulated connect.

    canonname is not used by start_connection. Never merge proto0 with TCP6,
    mapped IPv6 with IPv4, different flow/scope, or interpret textual zones.
    """
    if type(row) not in (tuple, list) or len(row) != 5:
        raise ValueError('ROW_INVALID')
    family, kind, proto, canon, addr = row
    if isinstance(family, bool) or not isinstance(family, int) or family not in (socket.AF_INET, socket.AF_INET6):
        raise ValueError('ROW_INVALID')
    if isinstance(kind, bool) or not isinstance(kind, int) or kind not in (socket.SOCK_STREAM, socket.SOCK_DGRAM):
        raise ValueError('ROW_INVALID')
    if not number(proto, 2147483647) or type(canon) is not str or len(canon) > 255 or '\x00' in canon:
        raise ValueError('ROW_INVALID')
    if type(addr) not in (tuple, list) or len(addr) != (2 if family == socket.AF_INET else 4):
        raise ValueError('ROW_INVALID')
    host, port = addr[:2]
    if type(host) is not str or not 1 <= len(host) <= 45 or '%' in host or not number(port, 65535):
        raise ValueError('ROW_INVALID')
    ip = ipaddress.ip_address(host)  # Public API, no name resolution.
    if ip.version != (4 if family == socket.AF_INET else 6):
        raise ValueError('ROW_INVALID')
    extras = ()
    if family == socket.AF_INET6:
        flow, scope = addr[2:]
        if not number(flow, 1048575) or not number(scope, 4294967295):
            raise ValueError('ROW_INVALID')
        extras = (flow, scope)
    return (int(family), int(kind), proto, int(ip), port, *extras)


def source_row_valid(row):
    endpoint_key(row)
    family, kind, proto, _, addr = row
    return (kind == socket.SOCK_STREAM and proto in (0, socket.IPPROTO_TCP)
            and addr[1] == 443 and ipaddress.ip_address(addr[0]).is_global)


def unknown_counts(reason, raw=None, raw_mode='UNKNOWN'):
    return dict(version=1, policy='RAW64_OBSERVATION_ONLY', evidence='PARTIAL', reason=reason,
                rawCount=raw, rawCountMode=raw_mode, endpointCount=None, duplicateCount=None,
                ipv4Rows=None, ipv6Rows=None)


def diagnostics_a(rows, end, clock=time.monotonic):
    """A: <=64 scanned; >64 saturates at65, no scan/truncate/connect acceptance."""
    if clock() >= end:
        return unknown_counts('DEADLINE')
    if type(rows) is not list:
        return unknown_counts('ROW_INVALID')
    count = len(rows)
    if count > RAW_CAP:
        return unknown_counts('RAW_CAP', 65, 'AT_LEAST_65')
    keys = set()
    ipv4 = 0
    try:
        for row in rows:
            if clock() >= end:
                return unknown_counts('DEADLINE', count, 'EXACT')
            keys.add(endpoint_key(row))
            ipv4 += row[0] == socket.AF_INET
    except (ValueError, TypeError, IndexError):
        return unknown_counts('ROW_INVALID', count, 'EXACT')
    if clock() >= end:
        return unknown_counts('DEADLINE', count, 'EXACT')
    return dict(version=1, policy='RAW64_OBSERVATION_ONLY', evidence='COMPLETE', reason='OK',
                rawCount=count, rawCountMode='EXACT', endpointCount=len(keys),
                duplicateCount=count-len(keys), ipv4Rows=ipv4, ipv6Rows=count-ipv4)


def counts_valid(row):
    expected = {'version', 'policy', 'evidence', 'reason', 'rawCount', 'rawCountMode',
                'endpointCount', 'duplicateCount', 'ipv4Rows', 'ipv6Rows'}
    if type(row) is not dict or set(row) != expected or type(row['version']) is not int or row['version'] != 1:
        return False
    if row['policy'] != 'RAW64_OBSERVATION_ONLY' or row['reason'] not in ('OK', 'RAW_CAP', 'ROW_INVALID', 'DEADLINE', 'IPC_CAP', 'MISSING'):
        return False
    raw, mode = row['rawCount'], row['rawCountMode']
    if mode == 'EXACT':
        if not number(raw, 64):
            return False
    elif mode == 'AT_LEAST_65':
        if not number(raw, 65) or raw != 65 or row['reason'] != 'RAW_CAP':
            return False
    elif mode == 'UNKNOWN':
        if raw is not None:
            return False
    else:
        return False
    counts = [row[k] for k in ('endpointCount', 'duplicateCount', 'ipv4Rows', 'ipv6Rows')]
    if row['evidence'] == 'COMPLETE':
        return (mode == 'EXACT' and row['reason'] == 'OK' and all(number(x, 64) for x in counts)
                and counts[0]+counts[1] == raw and counts[2]+counts[3] == raw
                and (raw == 0 and counts[0] == 0 or 1 <= counts[0] <= raw))
    return row['evidence'] == 'PARTIAL' and row['reason'] != 'OK' and all(x is None for x in counts)


def policy_b(rows, end, clock=time.monotonic):
    """B experiment only: validate ALL <=65 rows BEFORE stable dedup, unique<=64.

    Return data is RAM-only.65 is a counterexample boundary, not authorization
    to change64 anywhere. No production caller imports this module.
    """
    if clock() >= end:
        return 'DEADLINE', []
    if type(rows) is not list or not rows:
        return 'ROW_INVALID', []
    if len(rows) > WITNESS_RAW_BOUND:
        return 'RAW_BOUND', []
    for row in rows:
        if clock() >= end:
            return 'DEADLINE', []
        try:
            if not source_row_valid(row):
                return 'POLICY_DENIED', []
        except (ValueError, TypeError, IndexError):
            return 'ROW_INVALID', []
    if clock() >= end:
        return 'DEADLINE', []
    seen, result = set(), []
    for row in rows:
        if clock() >= end:
            return 'DEADLINE', []
        key = endpoint_key(row)
        if key not in seen:
            seen.add(key)
            result.append(row)
    if clock() >= end:
        return 'DEADLINE', []
    if len(result) > UNIQUE_CAP:
        return 'UNIQUE_BOUND', []
    return 'MODEL_ACCEPT_ONLY', result
