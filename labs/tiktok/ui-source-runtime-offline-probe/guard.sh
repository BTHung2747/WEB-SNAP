#!/bin/sh
# Kernel observer glue only; id/awk/sha256sum implement identity/text/hash work.
set -u
role=$1
uid=$(id -u); gid=$(id -g)
cap=$(awk '$1=="CapEff:"{print $2}' /proc/self/status)
bnd=$(awk '$1=="CapBnd:"{print $2}' /proc/self/status)
nnp=$(awk '$1=="NoNewPrivs:"{print $2}' /proc/self/status)
sec=$(awk '$1=="Seccomp:"{print $2}' /proc/self/status)
mem=$(cat /sys/fs/cgroup/memory.max 2>/dev/null || printf UNKNOWN)
swap=$(cat /sys/fs/cgroup/memory.swap.max 2>/dev/null || printf UNKNOWN)
pids=$(cat /sys/fs/cgroup/pids.max 2>/dev/null || printf UNKNOWN)
cpu=$(cat /sys/fs/cgroup/cpu.max 2>/dev/null || printf UNKNOWN)
rootro=false; awk '$5=="/" && $6 ~ /(^|,)ro(,|$)/{found=1} END{exit !found}' /proc/self/mountinfo && rootro=true
net=false; [ "$(ls /sys/class/net)" = lo ] && net=true
count=$(awk 'END{print NR}' /probe/expected.tsv); bad=0
sha256sum -c /probe/expected.sha256 >/dev/null 2>&1 || bad=$((bad+1))
awk 'FNR==NR{split($0,a,"\t");want[a[2]]=1;n++;next}{split($0,a," ");if(a[5] in want && a[6]~/(^|,)ro(,|$)/)seen[a[5]]=1}END{for(p in seen)ok++;exit ok!=n}' /probe/expected.tsv /proc/self/mountinfo || bad=$((bad+1))
tmp=false
f="$PROBE_TMP/wed-offline-$role"
if (umask 077; printf 'SYNTHETIC_OFFLINE_SENTINEL' > "$f") && [ -f "$f" ]; then tmp=true; rm "$f"; fi
cpumatch=false
printf '%s\n' "$cpu" | awk -v expected="$PROBE_CPU" 'NF==2 && $1~/^[0-9]+$/ && $2~/^[0-9]+$/ && $2>0{d=$1/$2-expected;if(d<0)d=-d;if(d<0.000001)ok=1}END{exit !ok}' && cpumatch=true
ok=false
if [ "$uid:$gid" = "$PROBE_UID" ] && [ "$cap" = 0000000000000000 ] && [ "$bnd" = 0000000000000000 ] && [ "$nnp" = 1 ] && [ "$sec" = 2 ] && [ "$mem" = "$PROBE_MEM" ] && [ "$swap" = 0 ] && [ "$pids" = "$PROBE_PIDS" ] && [ "$rootro" = true ] && [ "$net" = true ] && [ "$tmp" = true ] && [ "$cpumatch" = true ] && [ "$bad" = 0 ] && [ "$count" = "$PROBE_MAP_COUNT" ]; then ok=true; fi
# Fields are fixed kernel numeric/enum strings, no user names/env/command dump.
printf '{"kind":"kernel","role":"%s","ok":%s,"uid":%s,"gid":%s,"capEff":"%s","capBnd":"%s","noNewPrivs":"%s","seccomp":"%s","memoryMax":"%s","swapMax":"%s","pidsMax":"%s","cpuMax":"%s","rootRO":%s,"onlyLoopback":%s,"tmpfsWrite":%s,"mappedFiles":%s,"mappingErrors":%s}\n' "$role" "$ok" "$uid" "$gid" "$cap" "$bnd" "$nnp" "$sec" "$mem" "$swap" "$pids" "$cpu" "$rootro" "$net" "$tmp" "$count" "$bad"
[ "$ok" = true ]
