# WED SNAP lab glue, AGPL-3.0. Discard the whole URL: paths can contain credentials.
function Clean([string]$s){
    $s=[regex]::Replace($s,'(?i)https?://[^\s''"<>]+','[url-redacted]')
    return [regex]::Replace($s,'(?im)\b(cookie|authorization|proxy-authorization|set-cookie)\s*:[^\r\n]*','$1: [redacted]')
}
