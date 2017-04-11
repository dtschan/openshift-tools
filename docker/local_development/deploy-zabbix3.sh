#!/bin/bash -e

cd $(dirname "$0")

OS_TEMPLATE="./zabbix_monitoring_cent7_local_dev.yaml"
OS_TEMPLATE_NAME="ops-cent7-zabbix-monitoring"
OPENSHIFT_TOOLS_REPO=$(readlink -f ./repo_root)

# Make sure 'oc' binary in path
OC=$(which oc)
if [ "$?" -ne "0" ]; then
	echo "Could not find 'oc' binary in path"
	exit 1
fi

${OC} new-project monitoring || ${OC} project monitoring

${OC} secrets new monitoring-secrets ./monitoring-secrets/* || true

# Create SSL certs if necessary
if [ ! -e "rootCA.pem" ] || [ ! -e "rootCA.key" ]; then
	echo "Creating root CA files..."
	NEW_ROOT_CA="true"
	openssl genrsa -out rootCA.key 2048
	openssl req -x509 -new -nodes -key rootCA.key -sha256 -days 1024 \
		-out rootCA.pem \
		-subj "/C=US/ST=North Carolina/L=Raleigh/O=Local Zabbix/CN=root"
fi

if [ "$NEW_ROOT_CA" == "true" ] || \
   [ ! -e "zabbix-web.key" ] || \
   [ ! -e "zabbix-web.crt" ]; then
	echo "Creating zabbix-web cert files..."
	openssl genrsa -out zabbix-web.key 2048
	openssl req -new -key zabbix-web.key -out zabbix-web.csr \
		-subj "/C=US/ST=North Carolina/L=Raleigh/O=Zabbix Web/CN=oso-cent7-zabbix-web"
	openssl x509 -req -in zabbix-web.csr -CA rootCA.pem -CAkey rootCA.key \
		-CAcreateserial -out zabbix-web.crt -days 500 -sha256
fi

if [ "$NEW_ROOT_CA" == "true" ] || \
   [ ! -e "zagg-web.key" ] || \
   [ ! -e "zagg-web.crt" ]; then
	echo "Creating zagg-web cert files..."
	openssl genrsa -out zagg-web.key 2048
	openssl req -new -key zagg-web.key -out zagg-web.csr \
		-subj "/C=US/ST=North Carolina/L=Raleigh/O=Zagg Web/CN=oso-cent7-zagg-web"
	openssl x509 -req -in zagg-web.csr -CA rootCA.pem -CAkey rootCA.key \
		-CAcreateserial -out zagg-web.crt -days 500 -sha256
fi

# Insert SSL certs into template
IFS=''
while read LINE; do
	case "$LINE" in
		*PLACE_ROOT_CA_HERE*) sed -e 's/^/        /' rootCA.pem
			;;
		*PLACE_ZABBIX_WEB_SSL_CERT_HERE*) sed -e 's/^/        /' zabbix-web.crt
			;;
		*PLACE_ZABBIX_WEB_SSL_KEY_HERE*) sed -e 's/^/        /' zabbix-web.key
			;;
		*PLACE_ZAGG_WEB_SSL_CERT_HERE*) sed -e 's/^/        /' zagg-web.crt
			;;
		*PLACE_ZAGG_WEB_SSL_KEY_HERE*) sed -e 's/^/        /' zagg-web.key
			;;
		*) echo "$LINE"
			;;
	esac
done < $OS_TEMPLATE > template_with_certs.yaml

#${OC} create -f template_with_certs.yaml
#${OC} process ${OS_TEMPLATE_NAME} | ${OC} create -f -

echo "Deploying mysql pod"
#${OC} deploy --latest mysql --follow

echo "Deploying zabbix-server pod"
#${OC} deploy --latest oso-cent7-zabbix-server --follow

echo "Deploying zabbix-web pod"
#${OC} deploy --latest oso-cent7-zabbix-web --follow

#exit 0

#while [ "$(curl -k -s -o /dev/null -w %{http_code} https://oso-cent7-zabbix-web/zabbix/)" != "200" ]; do
#	echo "Waiting for zabbix to be ready"
#	sleep 5
#done
# sleep another 10 so zabbix-web is really up
#sleep 10

echo "Config zabbix"
#PYTHONPATH=${OPENSHIFT_TOOLS_REPO}:${PYTHONPATH} ansible-playbook ../../ansible/playbooks/adhoc/zabbix_setup/oo-clean-zaio.yml -e g_server="https://oso-cent7-zabbix-web-monitoring.ospa.pnet.ch/zabbix/api_jsonrpc.php"
PYTHONPATH=${OPENSHIFT_TOOLS_REPO}:${PYTHONPATH} ansible-playbook ../../ansible/playbooks/adhoc/zabbix_setup/oo-config-zaio.yml -e g_server="https://oso-cent7-zabbix-web-monitoring.ospa.pnet.ch/zabbix/api_jsonrpc.php"

echo "Deploying zagg pod"
#${OC} deploy --latest oso-cent7-zagg-web --follow

exit 0

echo "Give zagg container time to finish starting up"
sleep 10

#echo "Starting host monitoring"
CONTAINER_SETUP_DIR=$(readlink -f ./container_setup)
sudo docker run --name oso-centos7-host-monitoring -d \
	--privileged \
	--pid=host \
	--net=host \
	--ipc=host \
	-v /etc/localtime:/etc/localtime:ro \
	-v /sys:/sys:ro \
	-v /sys/fs/selinux \
	-v /var/lib/docker:/var/lib/docker:ro \
	-v /var/run/docker.sock:/var/run/docker.sock \
	-v ${CONTAINER_SETUP_DIR}:/container_setup:ro \
	--memory 512m \
       docker.io/openshifttools/oso-centos7-host-monitoring:latest

echo "Log into the OpenShift console at https://localhost:8443/console/ (username: developer / password: developer)"
echo "Log into zabbix at https://oso-cent7-zabbix-web/zabbix/ (username: Admin / password: zabbix)"
echo "Connect to host-monitoring with: sudo docker exec -ti oso-centos7-host-monitoring bash"
