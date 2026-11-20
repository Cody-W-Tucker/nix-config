-- Fluent Bit filter for the egress-audit aspect (egress-audit.nix).
--
-- Recognises three kinds of journal lines and turns them into structured
-- records tagged with an `egress` source field:
--   nft         kernel lines logged by the egress-audit nftables table
--               ("egress-out: " for host traffic, "egress-fwd: " for forwarded
--               container/router traffic)
--   opensnitch  CONNECTION events from opensnitchd's syslog logger (process
--               attribution)
--   dns         Unbound log-queries / log-local-actions lines (NAS resolver)
-- The rewrite_tag filter that follows moves records with `egress` set to the
-- "egress" tag. Every other record passes through unchanged.
--
-- A parsed record is rebuilt from the parsed fields plus `hostname` (the Loki
-- host label). The original message, the raw syslog line and the journal
-- metadata are dropped: they repeat the parsed fields, and the journal's
-- exe/comm/pid/uid describe the logging daemon, not the connecting program.
--
-- Internal traffic is dropped outright (not shipped anywhere): OpenSnitch
-- events to private/Tailscale addresses, and DNS lookups of names in
-- EGRESS_INTERNAL_SUFFIXES (defined by egress-audit.nix ahead of this file),
-- reverse lookups and single-label names. So are Unbound's own upstream
-- lookups seen by OpenSnitch, matching the nftables resolver skip; its client
-- queries are logged instead.

local internal_suffixes = EGRESS_INTERNAL_SUFFIXES or {}

local function nz(v)
  if v == nil or v == "" or v == "<nil>" then
    return nil
  end
  return v
end

local function strip_dot(name)
  return (name:gsub("%.$", ""))
end

-- Same ranges as the nftables private4/private6 sets.
local function is_private(ip)
  if ip:find(":", 1, true) then
    local l = ip:lower()
    return l == "::1" or l:match("^f[cd]") ~= nil or l:match("^fe[89ab]") ~= nil or l:match("^ff") ~= nil
  end
  local a, b = ip:match("^(%d+)%.(%d+)%.")
  a, b = tonumber(a), tonumber(b)
  if not a then
    return false
  end
  return a == 0 or a == 10 or a == 127 or a >= 224
    or (a == 100 and b >= 64 and b <= 127)
    or (a == 169 and b == 254)
    or (a == 172 and b >= 16 and b <= 31)
    or (a == 192 and b == 168)
end

local function is_internal_name(name)
  if not name:find(".", 1, true) then
    return true
  end
  for _, sfx in ipairs(internal_suffixes) do
    if name == sfx or name:sub(-(#sfx + 1)) == "." .. sfx then
      return true
    end
  end
  return false
end

-- The kernel logs IPv6 addresses fully expanded; OpenSnitch and Unbound use
-- the compressed form (RFC 5952). Compress so the same address matches across
-- sources.
local function compress6(ip)
  if ip == nil or not ip:find(":", 1, true) or ip:find("::", 1, true) then
    return ip
  end
  local g = {}
  for part in ip:gmatch("[^:]+") do
    g[#g + 1] = (part:lower():gsub("^0+(%x)", "%1"))
  end
  if #g ~= 8 then
    return ip
  end
  -- Longest run of zero groups (first one on a tie), if at least two long.
  local best_start, best_len, start, len = 0, 0, 0, 0
  for i = 1, 8 do
    if g[i] == "0" then
      if len == 0 then
        start = i
      end
      len = len + 1
      if len > best_len then
        best_start, best_len = start, len
      end
    else
      len = 0
    end
  end
  if best_len < 2 then
    return table.concat(g, ":")
  end
  return table.concat(g, ":", 1, best_start - 1) .. "::" .. table.concat(g, ":", best_start + best_len, 8)
end

-- Each parser returns the new record, false to drop the line, or nil when
-- the line is not one of its events.
local function parse_nft(msg)
  local chain = msg:match("egress%-(%a+): ")
  if not chain then
    return nil
  end
  local f = {}
  for k, v in msg:gmatch("(%u+)=(%S*)") do
    f[k] = v
  end
  return {
    egress = "nft",
    chain = chain,
    iif = nz(f.IN),
    oif = nz(f.OUT),
    src = compress6(nz(f.SRC)),
    dst = compress6(nz(f.DST)),
    proto = nz(f.PROTO),
    sport = nz(f.SPT),
    dport = nz(f.DPT),
    uid = nz(f.UID),
  }
end

local function parse_opensnitch(msg)
  if not msg:find(" CONNECTION ", 1, true) then
    return nil
  end
  local f = {}
  for k, v in msg:gmatch('(%u+)="([^"]*)"') do
    f[k] = v
  end
  -- LAN, Tailscale and loopback traffic is not egress.
  if f.DST == nil or is_private(f.DST) then
    return false
  end
  -- The resolver's own recursion (see the header).
  if (f.DPT == "53" or f.DPT == "853") and (f.PATH or ""):match("/bin/unbound$") then
    return false
  end
  return {
    egress = "opensnitch",
    src = nz(f.SRC),
    dst = nz(f.DST),
    -- Not "dsthost": geoip2 matches its lookup key ("dst") by prefix, so a
    -- key starting with "dst" can be looked up instead and leave no country.
    remote_host = nz(f.DSTHOST),
    proto = nz(f.PROTO),
    dport = nz(f.DPT),
    pid = nz(f.PID),
    uid = nz(f.UID),
    path = nz(f.PATH),
    cmdline = nz(f.CMDLINE),
  }
end

local function parse_unbound(msg)
  -- log-local-actions: "info: <zone>. <action> <client>@<port> <qname>. <type> IN"
  local zone, action, client, qname, qtype =
    msg:match("info: (%S+) ([%l_]+) (%S+)@%d+ (%S+) (%S+) IN$")
  if not zone then
    -- log-queries: "info: <client> <qname>. <type> IN"
    client, qname, qtype = msg:match("info: (%S+) (%S+) (%S+) IN$")
    if not client or not client:find("[%.:]") or qname:sub(-1) ~= "." then
      return nil
    end
  end
  qname = strip_dot(qname)
  if is_internal_name(qname) then
    return false
  end
  return {
    egress = "dns",
    client = client,
    qname = qname,
    qtype = qtype,
    action = zone and action or nil,
    zone = zone and strip_dot(zone) or nil,
  }
end

local parsers = {
  kernel = parse_nft,
  opensnitch = parse_opensnitch,
  unbound = parse_unbound,
}

function egress_parse(tag, timestamp, record)
  local parse = parsers[record["syslog_identifier"]]
  local msg = record["message"]
  if parse == nil or type(msg) ~= "string" then
    return 0, timestamp, record
  end
  local out = parse(msg)
  if out == nil then
    return 0, timestamp, record
  elseif out == false then
    return -1, timestamp, record
  end
  out.hostname = record["hostname"]
  return 2, timestamp, out
end

-- geoip2 writes null for records it cannot resolve (DNS lines, private
-- addresses), which would become a "null" Loki label. Lua already sees those
-- keys as nil, so returning the record as modified re-encodes it without them.
function egress_geo_clean(tag, timestamp, record)
  return 2, timestamp, record
end
