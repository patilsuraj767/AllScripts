require 'logger'
require 'socket'
$logger = Logger.new(STDOUT)

def getipfrominterface(ifname)
Socket.ip_address_list[1].ip_address
end

def getReverseDns(ip)
x = ip.split(".")
"#{x[2]}.#{x[1]}.#{x[0]}.in-addr.arpa"
end

def runCommand(message,cmd)
  $logger.info "#{message} \n - #{cmd}"
  #system(cmd)
end

def doInitialSetup

	cmd 'satellite-installer --scenario satellite --foreman-initial-organization "RedHat" --foreman-initial-location "Pune" --foreman-initial-admin-username admin --foreman-initial-admin-password redhat'
 	runCommand("Running satellite installer",cmd)

	cmd = "wget http://10.74.255.136/manifest.zip"
	runCommand("Downloading Manifest",cmd)

	cmd = "hammer subscription upload --organization RedHat --file ./manifest.zip"
	runCommand("Uploading Manifest",cmd)

	cmd = "hammer subscription refresh-manifest --organization RedHat"
	runCommand("Refreshing Manifest",cmd)

	cmd = 'hammer repository-set enable --organization RedHat --product "Red Hat Enterprise Linux Server" --basearch "x86_64" --releasever "7Server" --name "Red Hat Enterprise Linux 7 Server (RPMs)"'
	runCommand("Enabling 7Server repository",cmd)

	cmd = 'hammer repository-set enable --organization RedHat --product "Red Hat Enterprise Linux Server" --basearch "x86_64" --releasever "7Server" --name "Red Hat Satellite Tools 6.6 (for RHEL 7 Server) (RPMs)"'
	runCommand("Enabling 6.6 tools repository",cmd)

	cmd = 'hammer repository-set enable --organization RedHat --product "Red Hat Enterprise Linux Server" --basearch "x86_64" --releasever "7.6" --name "Red Hat Enterprise Linux 7 Server (Kickstart)"'
	runCommand("Enabling 7.6 Kickstart repository",cmd)

	cmd = 'hammer repository synchronize --name "Red Hat Enterprise Linux 7 Server Kickstart x86_64 7.6" --organization RedHat --product "Red Hat Enterprise Linux Server" --async'
	runCommand("Starting 6.6 Tools Repository Sync",cmd)
end


def doProvisioningSetup
	satelliteip = getipfrominterface("eth0")
	$logger.info "Satellite IP address - #{satelliteip}"
	
	reverseDNS = getReverseDns(satelliteip)
	$logger.info "Reverse DNS address - #{reverseDNS}"
	
	getwayIP = satelliteip[/\w*.\w*.\w*/] + ".1"
	$logger.info "Getway IP address - #{getwayIP}"
	
	ipRange = satelliteip[/\w*.\w*.\w*/] + ".100 " + satelliteip[/\w*.\w*.\w*/] + ".200"
	$logger.info "IP Range address - #{ipRange}"

	cmd = "satellite-installer --foreman-proxy-dns true --foreman-proxy-dns-forwarders 8.8.8.8 --foreman-proxy-dns-interface eth0 --foreman-proxy-dns-reverse #{reverseDNS} --foreman-proxy-dns-server #{satelliteip} --foreman-proxy-dns-zone example.com --foreman-proxy-dhcp true --foreman-proxy-dhcp-gateway #{getwayIP} --foreman-proxy-dhcp-interface eth0 --foreman-proxy-dhcp-nameservers #{satelliteip} --foreman-proxy-dhcp-range '#{ipRange}' --foreman-proxy-dhcp-server 127.0.0.1 --foreman-proxy-tftp true --foreman-proxy-tftp-servername #{satelliteip} --foreman-proxy-tftp-managed true --foreman-proxy-dhcp-managed true --foreman-proxy-dns-managed true"
	runCommand("Running satellite installer for provisioning",cmd)

	cmd = "hammer domain update --dns-id 1 --id 1"
	runCommand("Configure domain",cmd)

	cmd = "hammer subnet create --boot-mode DHCP --dhcp-id 1 --discovery-id 1 --dns-id 1 --dns-primary #{satelliteip} --domain-ids 1 --from #{satelliteip[/\w*.\w*.\w*/]}.100 --to #{satelliteip[/\w*.\w*.\w*/]}.200 --gateway #{getwayIP} --ipam DHCP --location-id 2 --mask 255.255.255.0 --network #{satelliteip[/\w*.\w*.\w*/] + ".0"} --organization-id 1 --tftp-id 1 --name libvirt"
	runCommand("Creating Subnet",cmd)

	cmd = "compute-resource create --name VMware --organizations RedHat --password QweMnb@123 --user 'suraj@gsslab.pnq2.redhat.com' --set-console-password false --server 'sysvcs.gsslab.pnq2.redhat.com' --provider 'Vmware' --datacenter 'T-Suraj' --location Pune --caching-enabled false"
	runCommand("Creating compute resource of personal vmware",cmd)
end




doInitialSetup
doProvisioningSetup






