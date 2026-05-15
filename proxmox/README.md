# How to configure Proxmox in a WLAN

## Introduction

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
    5. Follow steps 1 to 3 in [Guide: How to configure Proxmox with WiFi](https://blog.vivekkaushik.com/guide-how-to-configure-proxmox-with-wifi) : 
  
        - **Use previously found WiFi SSID and password** in `/etc/wpa_supplicant/wpa_supplicant.conf`.

        - Copy [`/proxmox/interfaces`](/proxmox/interfaces) to `/etc/network/interfaces` :

            - Replace `wlp1s0` with **the corresponding network interface** in all `-i` arguments of the NAT rules.
            
            -  Verify NAT rules for AdGuard Home are **before** NAT rules for NPM to avoid sending traffic for AdGuard Home to NPM (`-I PREROUTING 1` is to ensure rule priority).

            - `post-up iptables` is for NAT configuration, `post-up ip` is for routing.
5. NPM
    - Create a *VM*, static IP **10.1.1.4**.
    - Follow instructions in the [Nginx Proxy Manager](#nginx-proxy-manager) section.
      
6. DNS LXC (AdGuard Home)
    
    - Create a small LXC, static IP **10.1.1.6**
    - Install AdGuard Home
    - Define local DNS names for all your machines (e.g. wireguard.home → **10.1.1.2**)
    - Set your router's DHCP DNS to **10.1.1.6** → all LAN devices get it automatically
7. VPN server
   
    - Create a small LXC for wg-easy and Wireguard, static IP **10.1.1.2**
    - If using OpenVPN instead, enable TUN/TAP via Proxmox web UI (Features → TUN/TAP)
    - Follow instructions in [VPN](#section) to install wg-easy.
    - Configure peers (one per client device — laptop, phone, etc.)
    - Set DNS = **10.1.1.6** in each peer config → VPN clients resolve your local names automatically

8. Router

    - Add static route: 10.1.1.0/24 via 192.168.0.67 → LAN devices can reach your VMs
    - Port forward UDP 51820 → 192.168.0.67 → internet clients can reach WireGuard
    - Set DHCP DNS to **10.1.1.6** → LAN devices use AdGuard

</br>

> IPs are representative; just be consistent everywhere.

</br>

## Creating a new VM

To create a new VM :

1. Go to *local > ISO* through the local storage entry on the left panel.
2. Click Download from URL and use an official Debian ISO.

**If package URLs cannot be resolved during Debian installation (or any Linux distro)**:

1. Open Console > no VNC`
2. Switch to the Debian installer console with Ctrl+Alt+F2`
3. Set DNS:

    ```bash
    echo "nameserver 8.8.8.8" > /etc/resolv.conf
    ```
4. Verify resolution with `ping google.com`.
5. Return to the installer with Ctrl+Alt+F1

<br>

**After creating a new VM :**

- **Assign static IP via Proxmox web UI.**
- **Set DNS server**:
    ```bash
    echo "nameserver 10.1.1.6" > /etc/resolv.conf
    ```
- Since Proxmox's NoVNC console doesn't support clipboard operations, use SSH as a workaround.

<br>

> If you plan to access it from other VMs, LXCs, or physical machines using domain names, register it in AdGuard Home (10.1.1.6).


## Creating a new LXC

**After creating a new LXC :**

- **Assign static IP via Proxmox web UI.**
- **Set DNS server**:
    ```bash
    echo "nameserver 10.1.1.6" > /etc/resolv.conf
    ```

<br>

> If you plan to access it from other VMs, LXCs, or physical machines using domain names, register it in AdGuard Home (10.1.1.6).


## External access through a public domain

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

Wireguard and wg-easy can be run as Docker containers, Wireguard for the VPN and wg-easy for the GUI. For security reason official documentation recommends running wg-easy with a proxy to provide **HTTPS** access. Official documentation explains how to it using Caddy or Trefix : 

1. Install Docker.
2. Follow instructions in [wg-easy basic installation](https://wg-easy.github.io/wg-easy/v15.2/examples/tutorials/basic-installation/) guide with these changes before starting containers : 

    - Copy [`wg-easy-and-caddy-docker-compose.yaml`](/proxmox/wg-easy-and-caddy-docker-compose.yaml) to `docker-compose.yaml` (or `compose.yaml` / `compose.yml`).

    - Copy [`Caddyfile`](/proxmox/Caddyfile) to the **same** folder as the compose file :

        - Replace `yourmail@mail.com` with you mail address. 

        - Replace `wg-easy.internal` with the domain name defined in AdGuardHome for the LXC/VM running wg-easy.
10. Enter **https://wg-easy.internal** and follow the setup instructions.


Notes :

- Default Wireguard VPN interface is `wg0`.
- Configuration for `wg0` is in `/etc/wireguard/wg0.conf`.
- `AllowedIps` configuration in `/etc/wireguard/wg0.conf` defines what IPs can client takes, **not** what IPs can client access.

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

## Nginx Proxy Manager

To install and configure NPM follow these steps:

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

<br>

> Follow instructions in the [Creating your DuckDNS SSL Certificate](https://learntohomelab.com/docs/HomeLab-Series/EP26_nginxproxymanagerssl/#creating-your-duckdns-ssl-certificate) section of the [How to Setup The Nginx Proxy Manager and DuckDNS for Local SSL Certificates](https://learntohomelab.com/docs/HomeLab-Series/EP26_nginxproxymanagerssl/) blog article to provide HTTPS access to a VM or LXC.

</br>

## DNS Server

1. Install AdGuard Home as described in the [Getting started](https://adguard-dns.io/kb/es/adguard-home/getting-started/#installation) section of the Adguard Home official documentation.
2. Change WiFi router configuration to use **10.1.1.6** as **primary** DNS server (for primary set 8.8.8.8 or another one).
3. If not added before, add a NAT rule in the `/etc/network/interfaces` of the **Proxmox node** to forward TCP traffic on 80 to the corresponding VM and ports with AdGuard Home web GUI :
   
    ```interfaces
    post-up iptables -t nat -I PREROUTING 1 -i wlp1s0 -p tcp -d 10.1.1.6 --dport 80 -j ACCEPT
    post-down iptables -t nat -D PREROUTING -i wlp1s0 -p tcp -d 10.1.1.6 --dport 80 -j ACCEPT
    ```

    This rules must be **before** rules for NPM to avoid using the same port.
   
4. Go to *Filters > DNS Rewrites > Add DNS Rewrite* in the AdGuard Home web.
5. Map the corresponding domains to the corresponding IPs th

**After creating any VM or LXC, set the DNS server**:

```bash
echo "nameserver 10.1.1.6" > /etc/resolv.conf
```

## Home Assistant

For Home Assistant, in order **to allow requests from NPM**, the following configuration must be added to the `configuration.yaml` :

```yaml
http:
  use_x_forwarded_for: true
  trusted_proxies:
    - 10.1.1.4
```

## Troubleshooting 

### SSH Permission denied (publickey)


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


> Revert the previous configuration as soon as posible, it's not recommended to permit `root` access through SSH.

### VPN not working

- Check VPN interface:
    
    1. Enter in Docker container:

        ```bash
        docker exec -it wg-easy sh
        ```

    2. Verify the `wg0` interface for VPN is created:

        ```bash
        ip link
        ```

- Check IP range for clients:

    1. Enter in Docker container:    

        ```bash
        docker exec -it wg-easy sh
        ```

    2. Check VPN client IPs in `/etc/wireguard/wg0.conf`:

        ```bash
        cat /etc/wireguard/wg0.conf
        ```

        By default it should be **10.8.0.0/24**.

### Cannot access to the wg-easy web page

Test with it with `curl`:

```bash
curl -k https://wg.internal
```

or

```bash
curl -vk https://wg-easy.internal
```

If `curl` returns something like this : 

```
*   Trying 10.1.1.2:443...
* Connected to wg-easy.internal (10.1.1.2) port 443 (#0)
* ALPN, offering h2
* ALPN, offering http/1.1
* successfully set certificate verify locations:
*  CAfile: /etc/ssl/cert.pem
*  CApath: none
* (304) (OUT), TLS handshake, Client hello (1):
* error:1404B438:SSL routines:ST_CONNECT:tlsv1 alert internal error
* Closing connection 0
curl: (35) error:1404B438:SSL routines:ST_CONNECT:tlsv1 alert internal error
```

It means the TCP connection succeeded (routing + DNS are fine), but the TLS handshake failed on the server side : 

- Verify the `Caddyfile` is correct.
- Verify the compose file for wg-easy and Caddy is correct.

Notes about `curl`: 

- `-k` is to ignore SSL validation
- `-v` is for verbosity

### Docker containers should be recreated

To completely delete Docker containers (containers and volumes) created with `docker compose up` :

```bash
docker compose down -v
```

### Domains are not being resolved 

Check that AdGuard Home is working (resolves Proxmox VMs and LXCs) with `dig`:

```bash
dig @10.1.1.6 proxmox-vm.internal
```

Sometimes DNS caches are outdated, for example it MacOS it can be flushed with : 

```bash
sudo dscacheutil -flushcache
```

and : 

```bash
sudo killall -HUP mDNSResponder
```

If it's a Linux physical machine or VM/LXC, verify DNS server (10.1.1.6) is set in `/etc/resolv.conf`.

## Future improvements

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

<!-- 
TODO: explain how to add new restricted VPN clients
TODO: configure wg-easy with NPM as proxy, remove all caddy configurations in Docker compose YAML
-->


