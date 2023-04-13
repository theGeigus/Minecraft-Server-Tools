A collection of Minecraft Bedrock server scripts <br />
Created by Geigus<br />
<br />
This set of bash scripts allows for easy starting and stopping of a Minecraft bedrock server on a Linux machine.<br />
I use this set of scripts to run a Minecraft Bedrock server on an Oracle Cloud VM (avalible for free!).<br />
<br />
TO USE:<br />
1. Download bedrock server zip and extract into this directory <br />
2. Set server path and name in config_server.sh<br />
3. Run start_server.sh to start<br />
4. Run stop_server.sh to shut down<br />
5. Allow connections on the ports you will be using. If you are using firewalld, this can be done by running firewall-cmd --zone=public --add-port=19132-19133/tcp && firewall-cmd --zone=public --add-port=19132-19133/udp (Change the port numbers if not using the default)<br />
6. Mark all downloaded files as executable (chmod +x \*_server.sh && chmod +x bedrock_server\*)<br />
<br />
DEPENDENCIES:<br />
This makes use of the following programs that may need to be installed seperately:<br />
1. Screen<br />
2. inotify-tools<br />
