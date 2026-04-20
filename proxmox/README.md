# Proxmox

## Network infrastructure using local WiFi

1. Install Proxmox as described in [this](https://www.derekseaman.com/2023/10/home-assistant-proxmox-ve-8-0-quick-start-guide-2.html) blog.
2. In the Proxmox machine (through the web GUI):
    1. Install `wpa-supplicant` :
        ```bash
        apt-get install wpa-supplicant
        ```
    3. Create the `/etc/wpa_supplicant/wpa_supplicant.conf` with this:
        ```bash
        ctrl_interface=/run/wpa_supplicant
        update_config=1
        ```
    4. Find the corresponding Wi-Fi interface : 
        ```bash
        ip link
        ```
    2. Assuming the corresponding Wi-Fi interface is named `wlp1s0`, start `wpa_supplicant` : 
        ```bash
        wpa_supplicant -B -i wlp1s0 -c /etc/wpa_supplicant/wpa_supplicant.conf
        ```
    3. Use the scan feature of `wpa_cli` to find the SSID for your Wi-Fi network.
    4. Follow steps 1 to 3 in [this](https://blog.vivekkaushik.com/guide-how-to-configure-proxmox-with-wifi) blog with previously found SSID, Wi-Fi network password and using this configuration:
        ```
        auto lo
        iface lo inet loopback

        # Wifi interface autoconnect using wpa_supplicant.conf
        auto wlp1s0
        iface wlp1s0 inet static
                address 192.168.0.2
                netmask 255.255.255.0
                gateway 192.168.0.1
                dns-nameservers 1.1.1.1 8.8.8.8
                wpa-conf /etc/wpa_supplicant/wpa_supplicant.conf

        # Virtual bridge network
        auto vmbr0
        iface vmbr0 inet static
                address 10.1.1.1/24
                bridge-ports none
                bridge-stp off
                bridge-fd 0

                post-up echo 1 > /proc/sys/net/ipv4/ip_forward
                post-up iptables -t nat -A POSTROUTING -s '10.1.1.0/24' -o wlp1s0 -j MASQUERADE
                post-down iptables -t nat -D POSTROUTING -s '10.1.1.0/24' -o wlp1s0 -j MASQUERADE
                post-up iptables -t raw -I PREROUTING -i fwbr+ -j CT --zone 1
                post-down iptables -t raw -D PREROUTING -i fwbr+ -j CT --zone 1
                
                # VPN 
                post-up ip route add 10.8.0.0/24 via 10.1.1.2
                post-up iptables -t nat -A PREROUTING -i wlp1s0 -p udp --dport 51820 -j DNAT --to-destination 10.1.1.2:51820
                post-down iptables -t nat -D PREROUTING -i wlp1s0 -p udp --dport 51820 -j DNAT --to-destination 10.1.1.2:51820
                
                # Nginx
                post-up iptables -t nat -A PREROUTING -i wlp1s0 -p tcp --dport 80 -j DNAT --to-destination 10.1.1.4:80
                post-down iptables -t nat -D PREROUTING -i wlp1s0 -p tcp --dport 80 -j DNAT --to-destination 10.1.1.4:80
                post-up iptables -t nat -A PREROUTING -i wlp1s0 -p tcp --dport 443 -j DNAT --to-destination 10.1.1.4:443
                post-down iptables -t nat -D PREROUTING -i wlp1s0 -p tcp --dport 443 -j DNAT --to-destination 10.1.1.4:443
                
                

        source /etc/network/interfaces.d/*
        ```

        `post-up iptables` is for NAT configuration, `post-up ip` is for routing.
        
         **Check all NAT rules are set for the correct interface of the proxmox node (`-i` argument), for example in previous `/etc/network/interfaces` the corresponding interface is wlp1s0**.
4. DNS LXC (AdGuard Home)
    - Create a small LXC, static IP 10.1.1.3
    - Install AdGuard Home
    - Define local DNS names for all your machines (e.g. wireguard.home → 10.1.1.2)
    - Set your router's DHCP DNS to 10.1.1.3 → all LAN devices get it automatically
5. VPN server 
    - Create a small LXC for wg-easy + Wireguard, static IP 10.1.1.2
    - If using OpenVPN instead, enable TUN/TAP via Proxmox web UI (Features → TUN/TAP)
    - Follow instructions [below](https://gist.github.com/brunopk/e16db5bb2bcf97ba7439e229d1e865eb#file-proxmox_3-md) to install wg-easy + Wireguard (both together).
    - Configure peers (one per client device — laptop, phone, etc.)
    - Set DNS = 10.1.1.3 in each peer config → VPN clients resolve your local names automatically
    - For more information about how to configure the VPN, refer to [proxmox_3.md](https://gist.github.com/brunopk/e16db5bb2bcf97ba7439e229d1e865eb#file-proxmox_3-md) file below
6. Router

    - Add static route: 10.1.1.0/24 via 192.168.0.67 → LAN devices can reach your VMs
    - Port forward UDP 51820 → 192.168.0.67 → internet clients can reach WireGuard
    - Set DHCP DNS to 10.1.1.3 → LAN devices use AdGuard
7. Remaining VMs/LXCs

    - Assign static IPs from 10.1.1.10 upward via Proxmox web UI
    - Register their names in AdGuard

### References

- [Proxmox WiFi setup](https://www.derekseaman.com/2023/10/home-assistant-proxmox-ve-8-0-quick-start-guide-2.html)
- [Docker installation in Debian](https://docs.docker.com/engine/install/debian/)
- Claude 😆

## Public IP with DuckDNS

1. Create the folder to store a file with the last IP :
    ```bash
    mkdir -p /var/lib/duckdns
    ```
2. Create the script for the service replacing `YOUR_DOMAIN` and `YOUR_TOKEN` with the corresponding values:
    ```bash
    #!/bin/bash

    DOMAIN="YOUR_DOMAIN"
    TOKEN="YOUR_TOKEN"
    IP_FILE="/var/lib/duckdns/last_ip"

    # Fetch current public IP from external service
    CURRENT_IP=$(curl -s https://api.ipify.org)

    # -z: true if CURRENT_IP is empty (curl failed or returned nothing)
    if [[ -z "$CURRENT_IP" ]]; then
        echo "ERROR: Could not retrieve current IP" >&2
        exit 1
    fi

    # Read last known IP from file; if file doesn't exist, LAST_IP will be empty
    LAST_IP=$(cat "$IP_FILE" 2>/dev/null)

    # Skip update if IP hasn't changed
    if [[ "$CURRENT_IP" == "$LAST_IP" ]]; then
        exit 0
    fi

    # IP changed — send update to DuckDNS
    # Token is passed via stdin (-K -) to avoid exposing it in the process list
    RESPONSE=$(echo url="https://www.duckdns.org/update?domains=${DOMAIN}&token=${TOKEN}&ip=${CURRENT_IP}" | curl -sk -K -)

    if [[ "$RESPONSE" == "OK" ]]; then
        # :-none: if LAST_IP is unset/empty (first run), print "none" instead
        echo "IP changed: ${LAST_IP:-none} -> ${CURRENT_IP}"
        echo "$CURRENT_IP" > "$IP_FILE"
    else
        echo "ERROR: DuckDNS update failed (response: ${RESPONSE})" >&2
        exit 1
    fi
    ```
3. Create the duckdns service
    ```bash
    sudo nano /etc/systemd/system/duckdns.service
    ```

    like this :

    ```
    [Unit]
    Description=Update DuckDNS IP

    [Service]
    Type=oneshot
    ExecStart=/bin/bash /usr/local/bin/duckdns.sh
    ```
4. Create the timer service
    ```bash
    sudo nano /etc/systemd/system/duckdns.timer
    ```

    like this : 

    ```
    [Unit]
    Description=Run DuckDNS update every 5 minutes

    [Timer]
    OnBootSec=2min
    OnUnitActiveSec=5min
    Persistent=true

    [Install]
    WantedBy=timers.target
    ```
5. Enable service
    ```bash
    sudo systemctl daemon-reloadsudo systemctl enable --now duckdns.timer
    ```
6. Test
    ```bash
    sudo systemctl start duckdns.servicejournalctl -u duckdns.service
    ```

### References

- ChatGPT 😆 
- Claude 😆

## VPN 

### Configuring the server with Caddy as proxy

Wireguard and wg-easy can be run as Docker containers, Wireguard for the VPN and wg-easy as a web UI. wg-easy should run with a proxy to provide **HTTPS** access to the UI. One option is using Caddy and another option is using Trefix. Instructions below explains how to set wg-easy with **Caddy** with automatically created **self-signed SSL certificates** :

1. Install Docker.
2. Follow instructions [here](https://wg-easy.github.io/wg-easy/v15.2/examples/tutorials/basic-installation/) to install wg-easy but using this Docker compose file :
    ```yaml
    volumes:
      etc_wireguard:
      caddy_date:
      caddy_config:

    services:
      wg-easy:
        #environment:
        #  Optional:
        #  - PORT=51821
        #  - HOST=0.0.0.0
        #  - INSECURE=false

        image: ghcr.io/wg-easy/wg-easy:15
        container_name: wg-easy
        networks:
          wg:
            ipv4_address: 10.42.42.42
            ipv6_address: fdcc:ad94:bacf:61a3::2a
        volumes:
          - etc_wireguard:/etc/wireguard
          - /lib/modules:/lib/modules:ro
        ports:
          - "51820:51820/udp"
          - "51821:51821/tcp"
        restart: unless-stopped
        cap_add:
          - NET_ADMIN
          - SYS_MODULE
          # - NET_RAW #  ^z   ^o Uncomment if using Podman
        sysctls:
          - net.ipv4.ip_forward=1
          - net.ipv4.conf.all.src_valid_mark=1
          - net.ipv6.conf.all.disable_ipv6=0
          - net.ipv6.conf.all.forwarding=1
          - net.ipv6.conf.default.forwarding=1
      caddy:
        image: caddy:latest
        container_name: caddy
        ports:
          - "443:443"
        volumes:
          - ./Caddyfile:/etc/caddy/Caddyfile
          - caddy_data:/data
          - caddy_config:/config
        restart: unless-stopped

    networks:
      wg:
        driver: bridge
        enable_ipv6: true
        ipam:
          driver: default
          config:
            - subnet: 10.42.42.0/24
            - subnet: fdcc:ad94:bacf:61a3::/64
    ``` 
    
    Important: 10.42.42.0/24 IP range is for Docker **not** for the VPN.
    
3. Create Caddy configuration `Caddyfile` in the **same** folder as the Docker compose YML :
    ```
    # Caddyfile

    {
            # setup your email address
            email mail@example.com
    }

    wg.internal {
            # since the container will share the network with wg-easy
            # we can use the proper container name
            reverse_proxy wg-easy:51821
            tls internal
    }
    ```
    
    Replace the `wg.internal` with another domain if needed, **take into account that following steps may adapt to the new domain**.
4. Test with `curl` from a real machine in LAN: 
    ```
    curl -k https://wg.internal
    ```

    or

    ```
    curl -vk https://ng.internal
    ```

    `-k` ignore SSL validation 
    
    `-v` for verbosity
    
    If DNS server (AdGuard Home) was not configured, set `wg.internal` in `/etc/hosts` to point to 10.1.1.2 (LXC proxmox IP), assuming the WiFi router was previously configured to route traffic from 192.168.0.1/24 to 10.1.1.1/24 .
    
5. Check VPN interface (inside Docker container) :
    ```bash
    docker exec -it wg-easy sh
    ```

    and then:

    ```bash
    ip link
    ```

    Check the `wg0` interface for VPN is created.

6. Check VPN IP range (inside Docker container) :
    ```bash
    docker exec -it wg-easy sh
    ```

    and then check wireguard configuration in `/etc/wireguard/wg0.conf`:

    ```bash
    cat /etc/wireguard/wg0.conf
    ```
    
7. Enter https://wg.internal and follow instructions there.

### Configuring a full access client

1. Enter https://wg.internal
2. Add one client with default configuration.
3. Install the corresponding VPN [client](https://www.wireguard.com/install/) on client machine.

### Future improvements
- Avoid manually setting `/etc/hosts` by configuring a DNS server in a LXC

### Important 

- Default Wireguard VPN interface (in its Docker container, *not* LXC network interfaces) is `wg0`
- Configuration for `wg0` is in `/etc/wireguard/wg0.conf`
- `AllowedIps` configuration in `/etc/wireguard/wg0.conf` defines what IPs can client takes, **not** what IPs can client access.
- Due to how NAT rules are configured (refer to the `/etc/network/interfaces` in [proxmox_1.md](https://gist.github.com/brunopk/e16db5bb2bcf97ba7439e229d1e865eb#file-proxmox_1-md)), the only way to access wg.internal is **connecting to the VPN**.
- [Configuring the server with Caddy as proxy](https://gist.github.com/brunopk/e16db5bb2bcf97ba7439e229d1e865eb#configuring-the-server-with-caddy-as-proxy) as it says explains how to configure wg-easy with Caddy as proxy to provide HTTPS access, another approach is using NPM.

<!-- 
TODO: explain how to add new restricted VPN clients
TODO: configure wg-easy with NPM as proxy, remove all caddy configurations in Docker compose YAML
-->

<!--

✅ Steps
Assign VPN IPs
Client A → 10.8.0.2
Other clients → 10.8.0.3+
Configure WireGuard (wg-easy)

Client A:

AllowedIPs = 0.0.0.0/0

Other clients:

AllowedIPs = 192.168.1.10/32
Set Nginx IP
Example: 192.168.1.10

Apply firewall rules (on routing node)

# Full access client
iptables -A FORWARD -s 10.8.0.2 -j ACCEPT

# Others → only Nginx
iptables -A FORWARD -s 10.8.0.0/24 -d 192.168.1.10 -j ACCEPT

# Block everything else
iptables -A FORWARD -s 10.8.0.0/24 -j DROP
Configure Nginx
Route traffic by domain to internal services

Ensure IP forwarding is enabled

sysctl -w net.ipv4.ip_forward=1
Persist firewall rules
Use iptables-save or nftables config


To remove all Docker resources :

```bash
docker compose down
```

-->

### References

- [wg-easy basic installation](https://wg-easy.github.io/wg-easy/v15.2/examples/tutorials/basic-installation/)
- [Caddy installation](https://wg-easy.github.io/wg-easy/v15.2/examples/tutorials/caddy/)
- [Docker installation in Debian](https://docs.docker.com/engine/install/debian/)
- [Wireguard client](https://www.wireguard.com/install/)
- Claude 😆 

## Creating a VM with Debian

1. Go to *local > ISO* through the local storage entry on the left panel.
2. Click Download from URL and use an official Debian ISO.
3. Before installing any package : 
    1. Enter to *Console > no VNC*
    2. Enter in Debian installation console with *Ctrl + Alt + F2*.
    3. Set the DNS server:
        ```bash
        echo "nameserver 8.8.8.8" > /etc/resolv.conf
        ```
    4. Check with `ping google.com` that domains are being resolved correctly.
    5. Return to installation with *Ctrl + Alt + F1*.
6. After installing and booting into Debian, set DNS server :
    ```bash
    echo "nameserver 8.8.8.8" > /etc/resolv.conf
    ```

### SSH root access

In case of installing a VM that for security reason is not apropiated to permit `root` access through SSH (for example for a public Nginx server) and it's necessary to have clipboard support (NoVNC console provided by Proxmox don't have clipboard support), follow these steps :

1. Edit `/etc/ssh/sshd_config` with this configuration:
    ```
    PasswordAuthentication yes
    PermitRootLogin yes
    ```
3. Reset SSH service :
    ```bash
    systemctl restart ssh
    ```
6. Access through SSH from another machine to do required tasks.
7. Comment out previously changes in `/etc/ssh/sshd_config`.
8. Reset SSH service again.

### Important

- IP must be static, this is because proxmox node (the VM gateway) it's not configured for DHCP (remember the whole infrastructure is a bridged network through local WiFi so VMs are not directly connected to the WiFi router).
- As the NoVNC don't support Ctrl + V, access to the VM through SSH as described [above](https://gist.github.com/brunopk/e16db5bb2bcf97ba7439e229d1e865eb#ssh-root-access).

### References

- [Debian ISOs](https://www.debian.org/download)

## Nginx

To install and configure Nginx (Nginx Proxy Manager or NPM) follow these steps:

1. Add port forwarding rule in **router** (LAN) to send TCP traffic on port 443 to the Proxmox node LAN IP in the same port.
2. If not added before, add a NAT rule in the `/etc/network/interfaces` of the **proxmox node** to forward TCP traffic on port 443 and 80 to the corresponding VM and ports with Nginx :
    ```
    post-up iptables -t nat -A PREROUTING -i wlp1s0 -p tcp --dport 80 -j DNAT --to-destination 10.1.1.4:80
    post-down iptables -t nat -D PREROUTING -i wlp1s0 -p tcp --dport 80 -j DNAT --to-destination 10.1.1.4:80
    post-up iptables -t nat -A PREROUTING -i wlp1s0 -p tcp --dport 443 -j DNAT --to-destination 10.1.1.4:443
    post-down iptables -t nat -D PREROUTING -i wlp1s0 -p tcp --dport 443 -j DNAT --to-destination 10.1.1.4:443
    ```
   
   This is assuming NPM was previously installed in a VM (recommended for security reasons) or LXC on 10.1.1.4. 
3. Check in proxmox node that NAT rule are correctly added :
    ```bash
    iptables -t nat -L PREROUTING -n -v
    ```
4. Check in an external (LAN) machine that NPM is accessible :
    ```bash
    curl http://192.168.0.2
    ``` 
5. [Install Docker](https://docs.docker.com/engine/install/debian/). 
6. Install NPM as described in [official documentation](https://nginxproxymanager.com/setup/), replacing the `TZ` with the corresponding time zone (refer to [List of tz database time zones](https://en.wikipedia.org/wiki/List_of_tz_database_time_zones))
7. Follow instructions in the [Creating your DuckDNS SSL Certificate](https://learntohomelab.com/docs/HomeLab-Series/EP26_nginxproxymanagerssl/#creating-your-duckdns-ssl-certificate) section of the [How to Setup The Nginx Proxy Manager and DuckDNS for Local SSL Certificates](https://learntohomelab.com/docs/HomeLab-Series/EP26_nginxproxymanagerssl/) blog article.

### References

- [Docker installation in Debian](https://docs.docker.com/engine/install/debian/)
- [NPM Setup](https://nginxproxymanager.com/setup/)
- [How to Setup The Nginx Proxy Manager and DuckDNS for Local SSL Certificates](https://learntohomelab.com/docs/HomeLab-Series/EP26_nginxproxymanagerssl/)

## DNS Server

TODO

https://adguard-dns.io/kb/es/adguard-home/getting-started/#installation


