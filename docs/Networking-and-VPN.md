# Networking and VPN

This page details the networking architecture of CodyOS, covering system-level security, the Tailscale mesh VPN, Mullvad VPN integration, and the advanced `vpn-confinement` mechanism used to isolate specific services into dedicated network namespaces.

## System Networking and Security

CodyOS utilizes a hardened networking stack by default. Base networking configuration is defined in `modules/system/networking.nix` and imported into the base system profile [modules/system/base.nix19](../modules/system/base.nix#L19-L19)

### Hardening and Firewall

The system employs `nftables` as the primary firewall backend [modules/system/networking.nix28](../modules/system/networking.nix#L28-L28) SSH access is strictly controlled via `services.openssh`:

- **Authentication**: Password authentication is disabled in favor of SSH keys [modules/system/networking.nix13](../modules/system/networking.nix#L13-L13)
- **Root Access**: Root login is completely prohibited [modules/system/networking.nix15](../modules/system/networking.nix#L15-L15)
- **Brute Force Protection**: `fail2ban` is enabled to monitor and block malicious authentication attempts [modules/system/networking.nix25](../modules/system/networking.nix#L25-L25)

### Host-Specific Configuration

Individual hosts manage their own interface logic. For example, the `nas` host uses `networkmanager` and enables DHCP by default [hosts/nas/default.nix97-98](../hosts/nas/default.nix#L97-L98).

---

## VPN Infrastructure

The repository supports multiple VPN technologies tailored for different use cases: mesh networking (Tailscale), privacy-focused browsing (Mullvad), and service-level isolation (Wireguard via vpn-confinement).

### Tailscale Mesh VPN

Tailscale is used for secure, zero-config point-to-point connectivity between hosts.

- **Implementation**: Enabled via `services.tailscale.enable`[modules/desktop/vpn/tailscale.nix5](../modules/desktop/vpn/tailscale.nix#L5-L5)
- **Usage**: Applied to both the `nas`[hosts/nas/default.nix84](../hosts/nas/default.nix#L84-L84) and desktop environments.

### Mullvad VPN

Mullvad is provided as a system service for general-purpose desktop privacy.

- **Implementation**: Defined in `modules/desktop/vpn/mullvad.nix` using the `mullvad-vpn` package [modules/desktop/vpn/mullvad.nix3-6](../modules/desktop/vpn/mullvad.nix#L3-L6)

### Data Flow: VPN Services

The following diagram illustrates how different VPN modules are integrated into the system.

**VPN Integration Architecture**

```mermaid
flowchart LR
    subgraph HostConfigs
        NAS["hosts/nas/default.nix"]
        BEAST["hosts/beast/default.nix"]
    end
    subgraph VPNModules
        TS["modules/desktop/vpn/tailscale.nix"]
        MV["modules/desktop/vpn/mullvad.nix"]
        VPN_DEF["modules/desktop/vpn/default.nix"]
    end
    subgraph SystemModules
        BASE["modules/system/base.nix"]
        NET["modules/system/networking.nix"]
    end
    BASE --> NET
    NAS --> BASE
    NAS --> TS
    BEAST --> VPN_DEF
    VPN_DEF --> TS
    VPN_DEF --> MV
```

---

## VPN Confinement (Wireguard Namespaces)

A critical feature of the `nas` host is the isolation of the `transmission` bittorrent client. This is achieved using the `vpn-confinement` NixOS module, which forces a systemd service to run inside a dedicated Wireguard network namespace.

### Namespace Configuration

The namespace, named `wg`, is configured with a Wireguard configuration file managed by SOPS [modules/nas/media/default.nix161-163](../modules/nas/media/default.nix#L161-L163)

| Attribute          | Configuration    | Purpose                                   |
| ------------------ | ---------------- | ----------------------------------------- |
| **Namespace Name** | `wg`             | Identifier for the network namespace      |
| **Config File**    | `server-wg.conf` | Wireguard keys and peer info (from SOPS)  |
| **Accessibility**  | `192.168.0.0/24` | LAN range allowed to access the namespace |
| **Port Mapping**   | `9091 -> 9091`   | Maps Transmission Web UI to the host      |
| **Wireguard Port** | `60729`          | Port used for peer-to-peer traffic        |

### Service Isolation: Transmission

The `transmission` service is confined to the `wg` namespace, ensuring its traffic only exits via the Wireguard tunnel.

1. **Namespace Assignment**: The `vpnConfinement` option is applied to the `transmission` systemd service [modules/nas/media/default.nix180-183](../modules/nas/media/default.nix#L180-L183)
2. **RPC Binding**: Transmission is configured to bind its RPC/WebUI to `192.168.15.1`, which is the internal address within the namespace [modules/nas/media/default.nix150](../modules/nas/media/default.nix#L150-L150)
3. **Local Whitelisting**: To allow other services (like Sonarr/Radarr) to communicate with Transmission, the RPC whitelist includes the namespace gateway [modules/nas/media/default.nix148](../modules/nas/media/default.nix#L148-L148)

### Data Flow: Confined Service

The diagram below shows the relationship between the host network, the namespace, and the SOPS-managed secrets.

**Transmission VPN Confinement Flow**

```mermaid
flowchart LR
    INTERNET["Mullvad/Wireguard Peer"]
    subgraph Secrets
        SOPS_WG["sops.secrets.'server-wg.conf'"]
    end
    subgraph subGraph1 ["NetworkNamespace: wg"]
        TRANS["transmission.service"]
        WG0["Interface: wg0"]
    end
    subgraph HostNetwork
        LAN["LAN (192.168.0.0/24)"]
        NGINX["Nginx Proxy"]
    end
    SOPS_WG -.-> WG0
    NGINX --> TRANS
    TRANS --> WG0
    WG0 --> INTERNET
    LAN --> TRANS
```

---

## Nginx Reverse Proxy and SSL

The `nas` host acts as a gateway for various services, routing traffic via Nginx and securing it with ACME-provisioned SSL certificates.

### ACME and Cloudflare

SSL certificates for `*.homehub.tv` are managed via the `homehub.tv` ACME host [modules/nas/media/default.nix195](../modules/nas/media/default.nix#L195-L195) Nginx is configured with `kTLS` (Kernel TLS) for performance [modules/nas/media/default.nix200](../modules/nas/media/default.nix#L200-L200)

### Proxy Configuration

Services are exposed via subdomains. For example:

- **Jellyfin**: `media.homehub.tv` proxies to `127.0.0.1:8096`[modules/nas/media/default.nix193-197](../modules/nas/media/default.nix#L193-L197)
- **Calibre-Web**: `books.homehub.tv` proxies to `localhost:8083` with specific buffer tuning for Kobo synchronization [modules/nas/media/default.nix211-223](../modules/nas/media/default.nix#L211-L223)
- **Prowlarr**: `prowlarr.homehub.tv` proxies to `127.0.0.1:9696`[modules/nas/media/default.nix237-242](../modules/nas/media/default.nix#L237-L242)
