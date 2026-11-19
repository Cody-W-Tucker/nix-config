-- Fluent Bit filter for the egress-audit aspect (egress-audit.nix).
--
-- Recognises three kinds of journal lines and turns them into structured
-- records tagged with an `egress` source field:
--   nft         kernel lines logged by the egress-audit nftables table
--               ("egress-out: " for host traffic, "egress-fwd: " for forwarded
--               container/router traffic)
--   opensnitch  CONNECTION events from opensnitchd's syslog logger (process
--               attribution; Beast only)
--   dns         Unbound log-queries / log-local-actions lines (NAS resolver)
-- The rewrite_tag filter that follows moves records with `egress` set to the
-- "egress" tag. Every other record passes through unchanged.
--
-- Internal traffic is dropped outright (not shipped anywhere): OpenSnitch
-- events to private/Tailscale addresses, and DNS lookups of names in
-- EGRESS_INTERNAL_SUFFIXES (defined by egress-audit.nix ahead of this file),
-- reverse lookups and single-label names.

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

local function parse_nft(record, msg)
  local chain = msg:match("egress%-(%a+): ")
  if not chain then
    return 0
  end
  local f = {}
  for k, v in msg:gmatch("(%u+)=(%S*)") do
    f[k] = v
  end
  record.egress = "nft"
  record.chain = chain
  record.iif = nz(f.IN)
  record.oif = nz(f.OUT)
  record.src = nz(f.SRC)
  record.dst = nz(f.DST)
  record.proto = nz(f.PROTO)
  record.sport = nz(f.SPT)
  record.dport = nz(f.DPT)
  record.uid = nz(f.UID)
  return 2
end

local function parse_opensnitch(record, msg)
  if not msg:find(" CONNECTION ", 1, true) then
    return 0
  end
  local f = {}
  for k, v in msg:gmatch('(%u+)="([^"]*)"') do
    f[k] = v
  end
  -- LAN, Tailscale and loopback traffic is not egress.
  if f.DST == nil or is_private(f.DST) then
    return -1
  end
  record.egress = "opensnitch"
  record.src = nz(f.SRC)
  record.dst = nz(f.DST)
  record.dsthost = nz(f.DSTHOST)
  record.proto = nz(f.PROTO)
  record.dport = nz(f.DPT)
  record.pid = nz(f.PID)
  record.uid = nz(f.UID)
  record.path = nz(f.PATH)
  record.cmdline = nz(f.CMDLINE)
  record.action = nz(f.ARG1)
  record.rule = nz(f.ARG2)
  return 2
end

local function parse_unbound(record, msg)
  -- log-local-actions: "info: <zone>. <action> <client>@<port> <qname>. <type> IN"
  local zone, action, client, qname, qtype =
    msg:match("info: (%S+) ([%l_]+) (%S+)@%d+ (%S+) (%S+) IN$")
  if not zone then
    -- log-queries: "info: <client> <qname>. <type> IN"
    client, qname, qtype = msg:match("info: (%S+) (%S+) (%S+) IN$")
    if not client or not client:find("[%.:]") or qname:sub(-1) ~= "." then
      return 0
    end
  end
  qname = strip_dot(qname)
  if is_internal_name(qname) then
    return -1
  end
  record.egress = "dns"
  record.client = client
  record.qname = qname
  record.qtype = qtype
  if zone then
    record.action = action
    record.zone = strip_dot(zone)
  end
  return 2
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
  return parse(record, msg), timestamp, record
end

-- geoip2 writes null for records it cannot resolve (DNS lines, private
-- addresses), which would become a "null" Loki label. Lua already sees those
-- keys as nil, so returning the record as modified re-encodes it without them.
function egress_geo_clean(tag, timestamp, record)
  return 2, timestamp, record
end
