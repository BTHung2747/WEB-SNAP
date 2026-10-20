function FrozenMount([string]$from,[string]$to){@('--mount',"type=bind,source=$((Resolve-Path -LiteralPath $from).Path),target=$to,readonly")}
function ProxyMounts {
 @(FrozenMount 'labs/tiktok/photo-dns-diagnostics-fix' '/lab')+@(FrozenMount 'labs/tiktok/photo-dns-child-offline/common' '/base')+@(FrozenMount 'apps/egress' '/repo/apps/egress')
}
function AppCommonMounts {FrozenMount 'labs/tiktok/photo-app-source-executor/common' '/lab'}
function ProxyCommand {@('-I','/lab/overlay_entry.py')}
