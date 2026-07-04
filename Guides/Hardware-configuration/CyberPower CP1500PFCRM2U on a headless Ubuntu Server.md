To monitor and manage your [CyberPower CP1500PFCRM2U](https://www.cyberpowersystems.com/product/ups/pfc-sinewave/cp1500pfcrm2u/) on a headless **Ubuntu Server**, you should use **NUT (Network UPS Tools)**.

NUT is the open-source industry standard for Linux servers. It runs natively in the background, consumes negligible resources, and cleanly executes automatic shutdowns. \[1, 2, 3, 4, 5\]

## ---

**Step 1: Connect the Hardware**

1. Connect the square USB-B end of your cable into the **USB to PC** port on the back of the UPS.  
2. Connect the flat USB-A end into your Ubuntu Server.  
3. Verify your server detects the UPS hardware by running:  
   `lsusb`  
   *Look for a line mentioning **"Cyber Power System"** to confirm the connection.* \[6\]

## ---

**Step 2: Install and Configure NUT**

Install the software daemon and client packages via the terminal: \[2\]

`sudo apt update && sudo apt install -y nut nut-client`

Next, configure the four primary configuration files located in /etc/nut/: \[7\]

## **1\. Define the UPS Driver (/etc/nut/ups.conf) \[8\]**

Open the file with sudo nano /etc/nut/ups.conf and append the configuration for the standard CyberPower USB driver: \[2, 9\]

`[cyberpower]`  
    `driver = usbhid-ups`  
    `port = auto`  
    `desc = "CyberPower CP1500PFCRM2U"`

## **2\. Set the Operation Mode (/etc/nut/nut.conf) \[10\]**

Open sudo nano /etc/nut/nut.conf. Find the MODE line and change it to standalone so it runs locally on this single server: \[2, 11\]

`MODE=standalone`

## **3\. Configure the Monitoring Daemon (/etc/nut/upsmon.conf)**

Open sudo nano /etc/nut/upsmon.conf. Add this line to tell the system to monitor your newly named cyberpower UPS, acting as the system master user (MONITOR upsname@localhost numcomputers username password type): \[9, 12\]

`MONITOR cyberpower@localhost 1 upsmonadmin mysecurepassword master`

## **4\. Define the Local Security Credentials (/etc/nut/upsd.users) \[13\]**

Open sudo nano /etc/nut/upsd.users. Create the corresponding internal user account you specified in the monitoring step above:

`[upsmonadmin]`  
    `password = mysecurepassword`  
    `upsmon master`

## ---

**Step 3: Start and Verify the Service**

Restart the NUT tools to apply your updates:

`sudo systemctl restart nut-server nut-client`

Verify that your Ubuntu Server is successfully pulling real-time data from the CyberPower unit:

`upsc cyberpower`

*This command will output live diagnostics, including battery.charge (percentage), ups.status (OL for On Line / OB for On Battery), and ups.load.* \[14\]

If you want to customize your setup further, let me know:

* Do you need instructions on how to **adjust the low-battery threshold** before it triggers a shutdown?  
* Are there **other Linux/Windows devices** on your local network that you want this server to remotely shut down during an outage?

I can provide the extra configuration blocks for those scenarios.

\[1\] [https://askubuntu.com](https://askubuntu.com/questions/44170/ups-compatibility-with-ubuntu-server)  
\[2\] [https://oneuptime.com](https://oneuptime.com/blog/post/2026-03-02-how-to-configure-ups-monitoring-with-nut-on-ubuntu/view)  
\[3\] [https://wiki.ubuntu.com](https://wiki.ubuntu.com/apcupsd)  
\[4\] [https://www.colocationamerica.com](https://www.colocationamerica.com/linux-dedicated-server/ubuntu)  
\[5\] [https://learnubuntu.com](https://learnubuntu.com/ubuntu-server-vs-desktop/)  
\[6\] [https://unixorn.github.io](https://unixorn.github.io/post/homelab/homelab-nut-upsd/)  
\[7\] [https://www.linux.com](https://www.linux.com/news/adding-ups-desktop-linux-machine/)  
\[8\] [https://chribonn.medium.com](https://chribonn.medium.com/setting-up-nut-ups-software-on-linux-a-journey-of-discovery-48f962977b9d)  
\[9\] [https://forum.proxmox.com](https://forum.proxmox.com/threads/apc-smart-ups-nut-or-apcupsd.20909/)  
\[10\] [https://gist.github.com](https://gist.github.com/Jiab77/0778ef11a441f49df62e2b65f3daef76)  
\[11\] [https://gist.github.com](https://gist.github.com/Jiab77/0778ef11a441f49df62e2b65f3daef76)  
\[12\] [https://www.jeffgeerling.com](https://www.jeffgeerling.com/blog/2025/nut-on-my-pi-so-my-servers-dont-die/)  
\[13\] [https://elpuig.xeill.net](https://elpuig.xeill.net/Members/rborrell/articles/ups-eaton-ellipse-600-with-ubuntu-lucid-10.04)  
\[14\] [https://networkupstools.org](https://networkupstools.org/docs/man/upsmon.conf.html)