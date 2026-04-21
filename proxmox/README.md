# How to configure Proxmox through a WLAN

1. Install Proxmox as described in the [Home Assistant: Proxmox VE 8.4 Quick Start Guide](https://www.derekseaman.com/2023/10/home-assistant-proxmox-ve-8-0-quick-start-guide-2.html) blog article.
2. In the Proxmox machine through the web GUI :
   
    1. Install `wpa-supplicant` :
       
        ```bash
        apt-get install wpa-supplicant
        ```
    3. Create the `/etc/wpa_supplicant/wpa_supplicant.conf` with this:
       
        ```bash
        ctrl_interface=/run/wpa_supplicant
        update_config=1
        ```
    5. Find the corresponding Wi-Fi interface :
        
        ```bash
        ip link
        ```
    2. Assuming the corresponding Wi-Fi interface is named `wlp1s0`, start `wpa_supplicant` :
       
        ```bash
        wpa_supplicant -B -i wlp1s0 -c /etc/wpa_supplicant/wpa_supplicant.conf
        ```
    4. Use the scan feature of `wpa_cli` to find the SSID for your Wi-Fi network.
    5. Follow steps 1 to 3 in [this](https://blog.vivekkaushik.com/guide-how-to-configure-proxmox-with-wifi) blog with previously found SSID and Wi-Fi network password but using interfaces configuration defined in **[`/proxmox/interfaces`](/proxmox/interfaces)** configuration. 

         
        - `post-up iptables` is for NAT configuration, `post-up ip` is for routing.
        
        - Check all NAT rules are set for the **correct interface** of the proxmox node (`-i` argument), for example in previous `/etc/network/interfaces` the corresponding interface is wlp1s0.
        
        -  Verify NAT rules for AdGuard Home are **before** NAT rules for Nginx Proxy Manager to avoid sending traffic for AdGuard Home to NPM (`-I PREROUTING 1` is to ensure rule priority).
5. Nginx Proxy Server (NPM)

    - Create a *VM*, static IP **10.1.1.4**.
    - Follow instructions in the [Nginx Proxy Manager](#nginx-proxy-manager) section.
      
6. DNS LXC (AdGuard Home)
    
    - Create a small LXC, static IP **10.1.1.6**
    - Install AdGuard Home
    - Define local DNS names for all your machines (e.g. wireguard.home → **10.1.1.2**)
    - Set your router's DHCP DNS to **10.1.1.6** → all LAN devices get it automatically
7. VPN server
   
    - Create a small LXC for wg-easy + Wireguard, static IP **10.1.1.2**
    - If using OpenVPN instead, enable TUN/TAP via Proxmox web UI (Features → TUN/TAP)
    - Follow instructions in [VPN](#section) to install wg-easy + Wireguard (both together).
    - Configure peers (one per client device — laptop, phone, etc.)
    - Set DNS = **10.1.1.6** in each peer config → VPN clients resolve your local names automatically

8. Router

    - Add static route: 10.1.1.0/24 via 192.168.0.67 → LAN devices can reach your VMs
    - Port forward UDP 51820 → 192.168.0.67 → internet clients can reach WireGuard
    - Set DHCP DNS to **10.1.1.6** → LAN devices use AdGuard

</br>

For remaining VMs/LXCs :

   - Assign static IPs from 10.1.1.10 upward via Proxmox web UI
   - Register their names in AdGuard

</br>

> It's not mandatory to use the same IPs for all servers, it's possible to use other IPs

</br>

## Public IP with DuckDNS

1. Create the folder to store a file with the last IP :
   
    ```bash
    mkdir -p /var/lib/duckdns
    ```
3. Create the script `/usr/local/bin/duckdns.sh` replacing `YOUR_DOMAIN` and `YOUR_TOKEN` with the corresponding values in [`/proxmox/duckdns.sh`](/proxmox/duckdns.sh).
4. Create the duckdns service :
   
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
6. Create the timer service :
   
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
8. Enable service :

    ```bash
    sudo systemctl daemon-reloadsudo systemctl enable --now duckdns.timer
    ```
10. Test the service : 

    ```bash
    sudo systemctl start duckdns.servicejournalctl -u duckdns.service
    ```

## VPN 

Wireguard and wg-easy can be run as Docker containers, Wireguard for the VPN and wg-easy as a web UI. wg-easy should run with a proxy to provide **HTTPS** access to the UI. Official documentation explains how to it using Caddy another or Trefix as proxy but in order to be compatabile with instructions in [How to configure Proxmox through a WLAN](#how-to-configure-proxmox-through-a-wlan), particularly for NAT rules defined in `/etc/network/interfaces` of the proxmox node, wg-easy must be used with **Nginx Proxy Manager**.

### Configuring wg-easy with Nginx Proxy Manager as proxy for the web interface

1. Install Docker.
2. Follow instructions [here](https://wg-easy.github.io/wg-easy/v15.2/examples/tutorials/basic-installation/) to install wg-easy but creating the `docker-compose.yaml` as defined in [`/proxmox/wg-easy-docker-compose.yaml`](/proxmox/wg-easy-docker-compose.yaml).

    Important:
    
    - 10.42.42.0/24 IP range is for Docker **not** for the VPN.
    
    - Use `compose.yaml`, `compose.yml`, `docker-compose.yaml`, or `docker-compose.yml` so the docker compose up command can automatically detect and use the file.
    
3. Connect to the VPN from another machine.   
4. Check VPN interface inside Docker container :

   ```bash
    docker exec -it wg-easy sh
    ```

    and then:

    ```bash
    ip link
    ```

    Check the `wg0` interface for VPN is created.

5. Check VPN IP range (inside Docker container) :
    
    ```bash
    docker exec -it wg-easy sh
    ```

    and then check wireguard configuration in `/etc/wireguard/wg0.conf`:

    ```bash
    cat /etc/wireguard/wg0.conf
    ```
6. Follow instructions in the [Nginx Proxy Manager](#nginx-proxy-manager) section to redirect traffic via HTTPS from NPM to 10.1.1.2:51821 for the web GUI.
    

### Configuring wg-easy with Caddy as proxy for the web interface

Instructions below explains how to set wg-easy with **Caddy** with automatically created **self-signed SSL certificates** :

1. Install Docker.
2. Follow instructions [here](https://wg-easy.github.io/wg-easy/v15.2/examples/tutorials/basic-installation/) to install wg-easy but creating the `docker-compose.yaml` as defined in [`/proxmox/wg-easy-and-caddy-docker-compose.yaml`](/proxmox/wg-easy-and-caddy-docker-compose.yaml).

    Important:
    
    - 10.42.42.0/24 IP range is for Docker **not** for the VPN.
    
    - Use `compose.yaml`, `compose.yml`, `docker-compose.yaml`, or `docker-compose.yml` so the docker compose up command can automatically detect and use the file.
    
4. Create Caddy configuration `Caddyfile` in the **same** folder as the Docker compose YML :

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
6. Connect to the VPN from another machine.
7. Test with `curl` from a real machine in LAN: 
    ```
    curl -k https://wg.internal
    ```

    or

    ```
    curl -vk https://ng.internal
    ```

    `-k` ignore SSL validation 
    
    `-v` for verbosity
    
    If DNS server (AdGuard Home) was not configured, set `wg.internal` in `/etc/hosts` to point to **10.1.1.2** (LXC proxmox IP), assuming the WiFi router was previously configured to route traffic from 192.168.0.1/24 to 10.1.1.1/24. Following this instructions, the wg-easy web GUI can be accessed **only** after connecting to the VPN.
    
8. Check VPN interface inside Docker container :

   ```bash
    docker exec -it wg-easy sh
    ```

    and then:

    ```bash
    ip link
    ```

    Check the `wg0` interface for VPN is created.

9. Check VPN IP range (inside Docker container) :
    
    ```bash
    docker exec -it wg-easy sh
    ```

    and then check wireguard configuration in `/etc/wireguard/wg0.conf`:

    ```bash
    cat /etc/wireguard/wg0.conf
    ```
    
10. Enter https://wg.internal and follow instructions there.

### Configuring a full access client

1. Enter https://wg.internal
2. Add one client with default configuration.
3. Install the corresponding VPN [client](https://www.wireguard.com/install/) on client machine.

### Important 

- Default Wireguard VPN interface (in its Docker container, *not* LXC network interfaces) is `wg0`
- Configuration for `wg0` is in `/etc/wireguard/wg0.conf`
- `AllowedIps` configuration in `/etc/wireguard/wg0.conf` defines what IPs can client takes, **not** what IPs can client access.
- Due to how NAT rules are configured (refer to the `/etc/network/interfaces` in one of the steps of [proxmox_1.md](#how-to-configure-proxmox-through-a-wlan) section), the only way to access wg.internal is **connecting to the VPN**.
- [Configuring wg-easy with Caddy as proxy for the web interface](#configuring-wg-easy-with-caddy-as-proxy-for-the-web-interface) as the title says, explains how to configure wg-easy with Caddy as proxy to provide HTTPS access, another approach is using NPM.

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

## Virtual machines (VM)

1. Go to *local > ISO* through the local storage entry on the left panel.
2. Click Download from URL and use an official Debian ISO.
3. Before installing any package : 
    1. Enter to *Console > no VNC*
    2. Enter in Debian installation console with *Ctrl + Alt + F2*.
    3. Set the DNS server:
       
        ```bash
        echo "nameserver 8.8.8.8" > /etc/resolv.conf
        ```
    5. Check with `ping google.com` that domains are being resolved correctly.
    6. Return to installation with *Ctrl + Alt + F1*.
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
- As the NoVNC don't support Ctrl + V, access to the VM through SSH as described in the [SSH root access](#ssh-root-access) section.

## Nginx Proxy Manager

To install and configure Nginx (Nginx Proxy Manager or NPM) follow these steps:

1. Add port forwarding rule in **router** (LAN) to send TCP traffic on port 443 to the Proxmox node LAN IP in the same port.
2. If not added before, add a NAT rule in the `/etc/network/interfaces` of the **proxmox node** to forward TCP traffic on port 443 and 80 to the corresponding VM and ports with Nginx :
   
    ```interfaces
    post-up iptables -t nat -A PREROUTING -i wlp1s0 -p tcp --dport 80 -j DNAT --to-destination 10.1.1.4:80
    post-down iptables -t nat -D PREROUTING -i wlp1s0 -p tcp --dport 80 -j DNAT --to-destination 10.1.1.4:80
    post-up iptables -t nat -A PREROUTING -i wlp1s0 -p tcp --dport 443 -j DNAT --to-destination 10.1.1.4:443
    post-down iptables -t nat -D PREROUTING -i wlp1s0 -p tcp --dport 443 -j DNAT --to-destination 10.1.1.4:443
    ```
   
   This is assuming NPM was previously installed in a VM (recommended for security reasons) or LXC on 10.1.1.4. 
4. Check in proxmox node that NAT rule are correctly added :
   
    ```bash
    iptables -t nat -L PREROUTING -n -v
    ```
6. Check in an external (LAN) machine that NPM is accessible :
   
    ```bash
    curl http://192.168.0.2
    ``` 
8. [Install Docker](https://docs.docker.com/engine/install/debian/). 
9. Install NPM as described in [official documentation](https://nginxproxymanager.com/setup/), replacing the `TZ` with the corresponding time zone (refer to [List of tz database time zones](https://en.wikipedia.org/wiki/List_of_tz_database_time_zones))
10. Follow instructions in the [Creating your DuckDNS SSL Certificate](https://learntohomelab.com/docs/HomeLab-Series/EP26_nginxproxymanagerssl/#creating-your-duckdns-ssl-certificate) section of the [How to Setup The Nginx Proxy Manager and DuckDNS for Local SSL Certificates](https://learntohomelab.com/docs/HomeLab-Series/EP26_nginxproxymanagerssl/) blog article.

</br>

For Home Assistant, in order to allow requests from NPM the following configuration must be added to the `configuration.yaml` :

```yaml
http:
  use_x_forwarded_for: true
  trusted_proxies:
    - 10.1.1.4
```

</br> 

## DNS Server

1. Install AdGuard Home as described in the [Getting started](https://adguard-dns.io/kb/es/adguard-home/getting-started/#installation) section of the official documentation.
2. Change WiFi router configuration to use **10.1.1.6** as **primary** DNS server (for primary set 8.8.8.8 or another one).
3. If not added before, add a NAT rule in the `/etc/network/interfaces` of the **proxmox node** to forward TCP traffic on 80 to the corresponding VM and ports with AdGuard Home web GUI :
   
    ```interfaces
    post-up iptables -t nat -I PREROUTING 1 -i wlp1s0 -p tcp -d 10.1.1.6 --dport 80 -j ACCEPT
    post-down iptables -t nat -D PREROUTING -i wlp1s0 -p tcp -d 10.1.1.6 --dport 80 -j ACCEPT
    ```

    This rules must be **before** rules for Nginx (NPM) to avoid using the same port.
   
4. Go to *Filters > DNS Rewrites > Add DNS Rewrite* in the AdGuard Home web.
5. Map the corresponding domains to the corresponding IPs th

To check that AdGuard Home is working (resolves proxmox VMs and LXCs) :

```bash
dig @10.1.1.6 proxmox-vm.internal
```

### Future improvements

- Automatically assign domain to IPs with the DHCP-based hostnames feature of AdGuard Home web GUI (*Settings > DHCP Settings*) 
## References

- [Home Assistant: Proxmox VE 8.4 Quick Start Guide](https://www.derekseaman.com/2023/10/home-assistant-proxmox-ve-8-0-quick-start-guide-2.html)
- [How to Setup The Nginx Proxy Manager and DuckDNS for Local SSL Certificates](https://learntohomelab.com/docs/HomeLab-Series/EP26_nginxproxymanagerssl/)
- [Install Docker Engine on Debian](https://docs.docker.com/engine/install/debian/)
- [wg-easy basic installation](https://wg-easy.github.io/wg-easy/v15.2/examples/tutorials/basic-installation/)
- [wg-easy Caddy](https://wg-easy.github.io/wg-easy/v15.2/examples/tutorials/caddy/)
- [Wireguard client installation](https://www.wireguard.com/install/)
- [Debian ISOs](https://www.debian.org/download)
- [Nginx Proxy Manager Full Setup Instructions](https://nginxproxymanager.com/setup/)
- [AdGuard Home Getting started](https://adguard-dns.io/kb/es/adguard-home/getting-started/#installation)
- Claude 😆
- ChatGPT 😆 
