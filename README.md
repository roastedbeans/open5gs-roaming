<!-- Add the Initial steps done in from the  -->

Open5gs Roaming Docker and Kubernetes Setup

- Setup VM with Ubuntu 22.04, minimum requirement. 8gb memory, 50gb storage, 2 cores
- Clone open5gs-roaming repository from https://github.com/roastedbeans05/open5gs-roaming.git
- Install dependencies, you can use /scripts/install-dep.sh script to automate
- Build open5gs from the repository. 
- Deploy open5gs with docker buildx bake -> docker compose 

- show all cluster ip in a namespace: sudo microk8s kubectl get services -n <your-namespace> -o wide

- Access kubernetes microk8s dashboard with the command microk8s dashboard-proxy
- Open the kube-system namespace inside the dashboard
- Open the Config Maps and edit the coredns file

Rewrite the cluster domain names to 3gppnetwork format by adding the following:
{
	"Corefile": ".:53 {
		    errors
		    health {
		        lameduck 5s
		    }
		    ready
		    rewrite name nrf.5gc.mnc001.mcc001.3gppnetwork.org nrf.hplmn.svc.cluster.local
		    rewrite name scp.5gc.mnc001.mcc001.3gppnetwork.org scp.hplmn.svc.cluster.local
		    rewrite name udr.5gc.mnc001.mcc001.3gppnetwork.org udr.hplmn.svc.cluster.local
		    rewrite name udm.5gc.mnc001.mcc001.3gppnetwork.org udm.hplmn.svc.cluster.local
		    rewrite name pcf.5gc.mnc001.mcc001.3gppnetwork.org pcf.hplmn.svc.cluster.local
		    rewrite name upf.5gc.mnc001.mcc001.3gppnetwork.org upf.hplmn.svc.cluster.local
		    rewrite name smf.5gc.mnc001.mcc001.3gppnetwork.org smf.hplmn.svc.cluster.local
		    rewrite name amf.5gc.mnc001.mcc001.3gppnetwork.org amf.hplmn.svc.cluster.local
		    rewrite name bsf.5gc.mnc001.mcc001.3gppnetwork.org bsf.hplmn.svc.cluster.local
		    rewrite name nssf.5gc.mnc001.mcc001.3gppnetwork.org nssf.hplmn.svc.cluster.local
		    rewrite name ausf.5gc.mnc001.mcc001.3gppnetwork.org ausf.hplmn.svc.cluster.local
		    rewrite name nrf.5gc.mnc070.mcc999.3gppnetwork.org nrf.vplmn.svc.cluster.local
		    rewrite name scp.5gc.mnc070.mcc999.3gppnetwork.org scp.vplmn.svc.cluster.local
		    rewrite name udr.5gc.mnc070.mcc999.3gppnetwork.org udr.vplmn.svc.cluster.local
		    rewrite name udm.5gc.mnc070.mcc999.3gppnetwork.org udm.vplmn.svc.cluster.local
		    rewrite name pcf.5gc.mnc070.mcc999.3gppnetwork.org pcf.vplmn.svc.cluster.local
		    rewrite name upf.5gc.mnc070.mcc999.3gppnetwork.org upf.vplmn.svc.cluster.local
		    rewrite name smf.5gc.mnc070.mcc999.3gppnetwork.org smf.vplmn.svc.cluster.local
		    rewrite name amf.5gc.mnc070.mcc999.3gppnetwork.org amf.vplmn.svc.cluster.local
		    rewrite name bsf.5gc.mnc070.mcc999.3gppnetwork.org bsf.vplmn.svc.cluster.local
		    rewrite name nssf.5gc.mnc070.mcc999.3gppnetwork.org nssf.vplmn.svc.cluster.local
		    rewrite name ausf.5gc.mnc070.mcc999.3gppnetwork.org ausf.vplmn.svc.cluster.local
		    rewrite name sepp.5gc.mnc001.mcc001.3gppnetwork.org sepp.hplmn.svc.cluster.local
		    rewrite name sepp1.5gc.mnc001.mcc001.3gppnetwork.org sepp-n32c.hplmn.svc.cluster.local
		    rewrite name sepp2.5gc.mnc001.mcc001.3gppnetwork.org sepp-n32f.hplmn.svc.cluster.local
		    rewrite name sepp.5gc.mnc070.mcc999.3gppnetwork.org sepp.vplmn.svc.cluster.local
		    rewrite name sepp1.5gc.mnc070.mcc999.3gppnetwork.org sepp-n32c.vplmn.svc.cluster.local
		    rewrite name sepp2.5gc.mnc070.mcc999.3gppnetwork.org sepp-n32f.vplmn.svc.cluster.local
		    kubernetes cluster.local in-addr.arpa ip6.arpa {
		        pods insecure
		        fallthrough in-addr.arpa ip6.arpa
		        ttl 30
		    }
		    prometheus :9153
		    forward . /etc/resolv.conf {
		        max_concurrent 1000
		    }
		    cache 30
		    loop
		    reload
		    loadbalance
		}
		"
}

Rewrite the Kubernetes cluster names to the 3gppnetwork format in open5gs. Open 

- Setup script for subscription

- 
