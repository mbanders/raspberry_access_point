##################################################
# Update
#
apt-get update
apt-get -qy upgrade


##################################################
# Removed dhcpcd5 since it gets in the way
# Install dnsmasq to provide IP addresses (via dhcp)
# Install hostapd to be an access point
apt-get remove dhcpcd5
apt-get install -qy dnsmasq hostapd


##################################################
# Update network interfaces
#
cat << EOF > /etc/network/interfaces
# interfaces(5) file used by ifup(8) and ifdown(8)

# Please note that this file is written to be used with dhcpcd
# For static IP, consult /etc/dhcpcd.conf and 'man dhcpcd.conf'

# Include files from /etc/network/interfaces.d:
source-directory /etc/network/interfaces.d

auto lo
iface lo inet loopback

iface eth0 inet dhcp

auto wlan0
allow-hotplug wlan0
#iface wlan0 inet manual
iface wlan0 inet static
  address 192.168.5.1
  netmask 255.255.255.0
  network 192.168.5.0
#    wpa-conf /etc/wpa_supplicant/wpa_supplicant.conf

allow-hotplug wlan1
iface wlan1 inet manual
    wpa-conf /etc/wpa_supplicant/wpa_supplicant.conf
EOF


##################################################
# Setup hostapd
#
cat << EOF > /etc/hostapd/hostapd.conf
# This is the name of the WiFi interface we configured above
interface=wlan0

# Use the nl80211 driver with the brcmfmac driver
driver=nl80211

# This is the name of the network
ssid=MyPi3

# Use the 2.4GHz band
hw_mode=g

# Use channel 6
channel=6

# Enable 802.11n
ieee80211n=1

# Enable WMM
wmm_enabled=1

# Enable 40MHz channels with 20ns guard interval
ht_capab=[HT40][SHORT-GI-20][DSSS_CCK-40]

# Accept all MAC addresses
macaddr_acl=0

# Use WPA authentication
auth_algs=1

# Require clients to know the network name
ignore_broadcast_ssid=0

# Use WPA2
wpa=2

# Use a pre-shared key
wpa_key_mgmt=WPA-PSK

# The network passphrase
wpa_passphrase=raspberry

# Use AES, instead of TKIP
rsn_pairwise=CCMP
EOF

# make hostapd use new conf file
sed -i 's;\#DAEMON_CONF="";DAEMON_CONF="/etc/hostapd/hostapd.conf";' /etc/default/hostapd


##################################################
# Setup dnsmasq.conf
#
sudo mv /etc/dnsmasq.conf /etc/dnsmasq.conf.orig
cat << EOF > /etc/dnsmasq.conf
interface=wlan0      # Use interface wlan0
bind-interfaces      # Bind to wifi interface
server=8.8.8.8       # Forward DNS requests to Google DNS
domain-needed        # Don't forward short names
bogus-priv           # Never forward addresses in the non-routed address spaces.
dhcp-range=192.168.5.10,192.168.5.50,12h
EOF

##################################################
# IPV4 Forwarding
#
sed -i 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/' /etc/sysctl.conf
sh -c "echo 1 > /proc/sys/net/ipv4/ip_forward"

iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
iptables -A FORWARD -i eth0 -o wlan0 -m state --state RELATED,ESTABLISHED -j ACCEPT
iptables -A FORWARD -i wlan0 -o eth0 -j ACCEPT

apt-get install -qy iptables-persistent


##################################################
# Start it up!
sudo systemctl daemon-reload
sudo service hostapd restart
sudo service dnsmasq restart
