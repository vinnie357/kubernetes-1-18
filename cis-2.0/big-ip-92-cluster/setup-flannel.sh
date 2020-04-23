#!/bin/bash
# clusterIP setup
# thanks @Eric Chen
# run from master, requires
# python
# jq
# curl
# sed
echo -n "Enter your BIG-IP Management host and press [ENTER]: "
read MGMT
echo -n "Enter your BIG-IP Node Network self-ip and press [ENTER]: "
read SELF
echo -n "Enter your BIG-IP Node Network cidr and press [ENTER]: "
read CIDR
echo -n "Enter your BIG-IP POD Network and press [ENTER]: "
read PODNETWORK
echo -n "Enter your BIG-IP POD Network self-ip and press [ENTER]: "
read PODSELF
echo -n "Enter your BIG-IP POD Network cidr and press [ENTER]: "
read PODCIDR
echo -n "Enter your BIG-IP Node Network cidr and press [ENTER]: "
read CIDR
echo -n "Enter your BIG-IP username and press [ENTER]: "
read ADMIN
echo -n "Enter your BIG-IP password and press [ENTER]: "
read -s PASS
echo ""
CREDS="$ADMIN:$PASS"

# partition 
curl -k -u "$CREDS" -H "Content-Type: application/json" -X POST -d '{"name":"k8s", "fullPath": "/k8s", "subPath": "/"}' https://$MGMT/mgmt/tm/sys/folder |python -m json.tool

# disable vxlan configsync on each device
curl -k -u "$CREDS" -H "Content-Type: application/json" -X PUT -d '{"value":"disable"}' https://$mgmt/mgmt/tm/sys/db/iptunnel.configsync 

# # tunnel profile
curl -k -u "$CREDS" -H "Content-Type: application/json" -X POST -d '{"name": "fl-vxlan","partition": "Common","defaultsFrom": "/Common/vxlan", "floodingType": "none","port": 8472 }' https://$mgmt/mgmt/tm/net/tunnels/vxlan
sleep 3
curl -k -u "$CREDS"  -H 'Content-Type: application/json' -X POST -d "{\"name\": \"flannel_vxlan\",\"partition\": \"Common\",\"key\": 1,\"localAddress\": \"$SELF\",\"profile\": \"/Common/fl-vxlan\" }" https://$mgmt/mgmt/tm/net/tunnels/tunnel

# wait
echo "wait for profiles"
sleep 10
# check version
# get mac address
curl  curl --stderr /dev/null -k -u "$CREDS" -H "Content-Type: application/json"  "https://$mgmt/mgmt/tm/sys" | jq .selfLink -r | grep -E ver=1[23]
if [ $? != 0 ]
  then
  macAddr1=$(curl --stderr /dev/null -k -u "$CREDS" -H "Content-Type: application/json"  "https://$mgmt/mgmt/tm/net/tunnels/tunnel/~Common~fl-vxlan/stats?options=all-properties"|jq '.entries."https://localhost/mgmt/tm/net/tunnels/tunnel/~Common~fl-vxlan/stats"."nestedStats".entries.macAddr.description' -r)
else
  # v13    
  macAddr1=$(curl --stderr /dev/null -k -u "$CREDS" -H "Content-Type: application/json"  "https://$mgmt/mgmt/tm/net/tunnels/tunnel/~Common~fl-vxlan/stats?options=all-properties"|jq '.entries."https://localhost/mgmt/tm/net/tunnels/tunnel/~Common~fl-vxlan/~Common~fl-vxlan/stats"."nestedStats".entries.macAddr.description' -r)
  fi

# create node network self
curl -k -u "$CREDS"  -H 'Content-Type: application/json' -X POST -d "{\"name\": \"internal-nf\",\"partition\": \"Common\",\"address\": \"$SELF/$CIDR\", \"floating\": \"disabled\",\"vlan\": \"/Common/internal\"}" https://$mgmt/mgmt/tm/net/self
# Create  POD self-ip
curl -k -u "$CREDS"  -H 'Content-Type: application/json' -X POST -d "{\"name\": \"vxlan-local\",\"partition\": \"Common\",\"address\": \"$PODSELF/$PODCIDR\", \"floating\": \"disabled\",\"vlan\": \"/Common/fl-vxlan\"}" https://$mgmt/mgmt/tm/net/self

#  Create node
cp f5-bigip-node.yaml.src > f5-bigip-node.yaml
sed -e "s/MAC_ADDR/$macAddr1/g" f5-bigip-node.yaml
sed -e "s/SELF/$SELF/g" f5-bigip-node.yaml
sed -e "s/PODNETWORK/$PODNETWORK/g" f5-bigip-node.yaml
sed -e "s/PODCIDR/$PODCIDR/g" f5-bigip-node.yaml

##
## Create BIG-IP kubectl secret
##
kubectl create secret generic bigip-login --namespace kube-system --from-literal=username="$ADMIN" --from-literal=password="$PASS" --from-literal=url=$MGMT
#create kubernetes bigip container connecter, authentication and RBAC
kubectl create serviceaccount k8s-bigip-ctlr -n kube-system
kubectl create clusterrolebinding k8s-bigip-ctlr-clusteradmin --clusterrole=cluster-admin --serviceaccount=kube-system:k8s-bigip-ctlr
kubectl create -f f5-cluster-deployment.yaml
kubectl create -f f5-bigip-node.yaml

##
## Create deployment and service
##
kubectl create -f  app/juiceshop-deployment.yaml
kubectl create -f  app/juiceshop-service.yaml
kubectl create -f  app/f5-as3-configmap-juiceshop.yaml

## see pods
kubectl get pods --all-namespaces

# watch logs
echo "type yes to tail the cis logs"
read answer
if [ $answer == "yes" ]; then
    cisPod=$(kubectl get pods --field-selector=status.phase=Running -n kube-system -o json | jq -r ".items[].metadata | select(.name | contains (\"k8s-bigip-ctlr\")).name")
    kubectl logs -f $cisPod -n kube-system | grep --color=auto -i '\[as3'
else
    echo "Finished"
fi