# VPN stack: NordVPN over native WireGuard (NordLynx), the `vpn-hop` country
# switcher that swaps the active endpoint live, and an nftables kill-switch
# that drops all egress when the tunnel is down (independent of wg-quick's
# unit lifecycle). systemd-resolved is enabled here too because wg-quick's
# `dns =` directive pushes Nord's resolver via resolvconf — without resolved
# nothing receives that push.

{ pkgs, ... }:

let
  # Default startup endpoint for the wg-quick peer below. `vpn-hop`
  # swaps this live at runtime; the value here is what reloads on
  # `systemctl restart wg-quick-nordlynx` or boot.
  nordlynxEndpoint = "180.149.231.154";
  nordlynxPort = 51820;

  # Live country-switcher. See `vpn-hop --help`.
  # NORDLYNX_PORT is the only Nix-side value the script needs; pass it via
  # env so scripts/vpn-hop.sh stays pure shell (editor highlighting, shellcheck).
  vpnHop = pkgs.writeShellApplication {
    name = "vpn-hop";
    runtimeInputs = with pkgs; [ curl jq wireguard-tools iproute2 ];
    text = ''
      export NORDLYNX_PORT=${toString nordlynxPort}
      ${builtins.readFile ./scripts/vpn-hop.sh}
    '';
  };
in
{
  # wg-quick owns the nordlynx interface — keep NM from touching it.
  networking.networkmanager.unmanaged = [ "interface-name:nordlynx" ];

  # systemd-resolved owns /etc/resolv.conf. wg-quick's `dns =` directive
  # below pushes Nord's resolver into it via resolvconf when the tunnel
  # comes up.
  services.resolved.enable = true;

  # NordVPN via native WireGuard (NordLynx). Pinned to nz94 — lowest-load
  # Auckland gateway at config time (load 21%). NordLynx publishes one
  # WireGuard public key for the whole NZ cluster, so rotating to another
  # NZ server only requires changing the endpoint IP (re-query
  # api.nordvpn.com/v1/servers/recommendations with country_id=156 and
  # technology wireguard_udp; the `station` field is the endpoint IP).
  #
  # Private key lives at /etc/nordlynx/private.key (root:root 0400) so the
  # secret never enters the nix store or git. Regenerate via
  # `curl -u token:<access_token> https://api.nordvpn.com/v1/users/services/credentials`
  # whenever NordVPN rotates the credential.
  #
  # DNS is set on the interface to Nord's resolver (103.86.96.100) so
  # name resolution rides the tunnel when up, without depending on any
  # host-level DNS config.
  networking.wg-quick.interfaces.nordlynx = {
    address = [ "10.5.0.2/32" ];
    privateKeyFile = "/etc/nordlynx/private.key";
    dns = [ "103.86.96.100" ];
    peers = [{
      publicKey = "P7Dv2WoopPHomMq6jnvwV2hnV2BnI/7LklaIUTEzSQ8=";
      allowedIPs = [ "0.0.0.0/0" "::/0" ];
      endpoint = "${nordlynxEndpoint}:${toString nordlynxPort}";
      persistentKeepalive = 25;
    }];
  };

  # VPN kill-switch. Independent of wg-quick's systemd unit lifecycle —
  # if the tunnel isn't up (boot window, service crash, wg-quick stopped
  # for any reason) the only egress permitted is: loopback, LAN/link-local,
  # DHCP, ICMPv6 neighbor discovery, and the WG handshake to the Nord
  # endpoint itself. Result: no clear-net leak even when nordlynx is gone.
  #
  # Switching to nftables changes the firewall backend; iptables still
  # works through the nft-backed shim, so wg-quick's own PostUp rules
  # continue to apply.
  networking.nftables.enable = true;
  networking.nftables.tables.killswitch = {
    family = "inet";
    content = ''
      chain output {
        type filter hook output priority filter; policy drop;

        # Loopback and replies to flows we already permitted.
        oifname "lo" accept
        ct state established,related accept

        # LAN / link-local / multicast / broadcast (v4 + v6).
        ip daddr { 10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16,
                   169.254.0.0/16, 224.0.0.0/4, 255.255.255.255 } accept
        ip6 daddr { fe80::/10, fc00::/7, ff00::/8 } accept

        # DHCP (v4 + v6) so we can still get a LAN lease pre-tunnel.
        udp dport { 67, 68, 546, 547 } accept

        # IPv6 neighbor discovery — required for IPv6 to work on any LAN.
        icmpv6 type { nd-router-solicit, nd-router-advert,
                      nd-neighbor-solicit, nd-neighbor-advert,
                      nd-redirect } accept

        # WireGuard handshake/keepalive on UDP/51820 to any destination,
        # so `vpn-hop <country>` can swap the peer to a different NordVPN
        # server live without rebuilding the firewall. The port itself
        # isn't a useful exfil channel (the other side has to speak the
        # WireGuard handshake or the packets achieve nothing), so the
        # accidental-leak protection this kill-switch exists for is
        # preserved.
        udp dport ${toString nordlynxPort} accept

        # Anything that's already been routed into the tunnel.
        oifname "nordlynx" accept
      }
    '';
  };

  environment.systemPackages = [ vpnHop ];
}
