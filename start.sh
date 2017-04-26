#!/bin/sh
## EMQ docker image start script
# Huang Rui <vowstar@gmail.com>

## Shell setting
if [[ ! -z "$DEBUG" ]]; then
    set -ex
fi

## Local IP address setting
: ${LOCAL_IP='auto'}
: ${USE_RANCHER_IP=false}
if [ "$LOCAL_IP" = 'auto' ]; then
	if [ $USE_RANCHER_IP = true ]; then
		LOCAL_IP=$(curl http://rancher-metadata.rancher.internal/latest/self/container/primary_ip)
	else
		LOCAL_IP=$(hostname -i |grep -E -oh '((25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])\.){3,3}(25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])'|head -n 1)
	fi
fi
echo "LOCAL_IP: $LOCAL_IP"

# If we're given EMQ_RANCHER_CLUSTER_SERVICE, then use the ips
# from these services to join the cluster
CLUSTER_IP='x'
if [ -n "${EMQ_RANCHER_CLUSTER_SERVICE}" ]; then
  for SERVICE_IP in $(dig +short $EMQ_RANCHER_CLUSTER_SERVICE | grep -v $LOCAL_IP); do
    if [ $SERVICE_IP != $LOCAL_IP ]; then
      CLUSTER_IP=$SERVICE_IP
      break
    fi
  done

  if [ $CLUSTER_IP != "x" ]; then
    EMQ_JOIN_CLUSTER="EMQ@$CLUSTER_IP"
  fi

  echo "EMQ_JOIN_CLUSTER: $EMQ_JOIN_CLUSTER"
fi

## EMQ Base settings and plugins setting
# Base settings in /opt/emqttd/etc/emq.conf
# Plugin settings in /opt/emqttd/etc/plugins

_EMQ_HOME="/opt/emqtt"

if [[ -z "$PLATFORM_ETC_DIR" ]]; then
    export PLATFORM_ETC_DIR="$_EMQ_HOME/etc"
fi

if [[ -z "$PLATFORM_LOG_DIR" ]]; then
    export PLATFORM_LOG_DIR="$_EMQ_HOME/log"
fi

if [[ -z "$EMQ_LOG__ERROR__FILE" ]]; then
    export EMQ_LOG__ERROR__FILE="${PLATFORM_LOG_DIR}/error.log"
fi

if [[ -z "$EMQ_NAME" ]]; then
    export EMQ_NAME="EMQ"
fi

if [[ -z "$EMQ_HOST" ]]; then
    export EMQ_HOST="$LOCAL_IP"
fi

if [[ -z "$EMQ_NODE__NAME" ]]; then
    export EMQ_NODE__NAME="$EMQ_NAME@$EMQ_HOST"
fi

# Set hosts to prevent cluster mode failed

if [[ ! -z "$LOCAL_IP" && ! -z "$EMQ_HOST" ]]; then
    echo "$LOCAL_IP        $EMQ_HOST" >> /etc/hosts
fi

# unset EMQ_NAME
# unset EMQ_HOST

if [[ -z "$EMQ_NODE__PROCESS_LIMIT" ]]; then
    export EMQ_NODE__PROCESS_LIMIT=256000
fi

if [[ -z "$EMQ_NODE__MAX_PORTS" ]]; then
    export EMQ_NODE__MAX_PORTS=65536
fi

if [[ -z "$EMQ_NODE__MAX_ETS_TABLES" ]]; then
    export EMQ_NODE__MAX_ETS_TABLES=256000
fi

if [[ -z "$EMQ_LOG__CONSOLE" ]]; then
    export EMQ_LOG__CONSOLE="console"
fi

if [[ -z "$EMQ_MQTT__LISTENER__TCP__ACCEPTORS" ]]; then
    export EMQ_MQTT__LISTENER__TCP__ACCEPTORS=8
fi

if [[ -z "$EMQ_MQTT__LISTENER__TCP__MAX_CLIENTS" ]]; then
    export EMQ_MQTT__LISTENER__TCP__MAX_CLIENTS=1024
fi

if [[ -z "$EMQ_MQTT__LISTENER__SSL__ACCEPTORS" ]]; then
    export EMQ_MQTT__LISTENER__SSL__ACCEPTORS=4
fi

if [[ -z "$EMQ_MQTT__LISTENER__SSL__MAX_CLIENTS" ]]; then
    export EMQ_MQTT__LISTENER__SSL__MAX_CLIENTS=512
fi

if [[ -z "$EMQ_MQTT__LISTENER__HTTP__ACCEPTORS" ]]; then
    export EMQ_MQTT__LISTENER__HTTP__ACCEPTORS=4
fi

if [[ -z "$EMQ_MQTT__LISTENER__HTTP__MAX_CLIENTS" ]]; then
    export EMQ_MQTT__LISTENER__HTTP__MAX_CLIENTS=64
fi

# Catch all EMQ_ prefix environment variable and match it in configure file
CONFIG=/opt/emqttd/etc/emq.conf
CONFIG_PLUGINS=/opt/emqttd/etc/plugins
for VAR in $(env)
do
    # Config normal keys such like node.name = emqttd@127.0.0.1
    if [[ ! -z "$(echo $VAR | grep -E '^EMQ_')" ]]; then
        VAR_NAME=$(echo "$VAR" | sed -r "s|EMQ_(.*)=.*|\1|g" | tr '[:upper:]' '[:lower:]' | sed -r "s|__|\.|g")
        echo "$VAR == $VAR_NAME"
        VAR_FULL_NAME=$(echo "$VAR" | sed -r "s|(.*)=.*|\1|g")
        # echo "$VAR_NAME=$(eval echo \$$VAR_FULL_NAME)"
        # sed -r -i "s|(^#*\s*)($VAR_NAME)\s*=\s*(.*)|\2 = $(eval echo \$$VAR_FULL_NAME)|g" $CONFIG

        # Config in emq.conf
        if [[ ! -z "$(cat $CONFIG |grep -E "^(^|^#*|^#*\s*)$VAR_NAME")" ]]; then
            echo "$VAR_NAME=$(eval echo \$$VAR_FULL_NAME)"
            sed -r -i "s|(^#*\s*)($VAR_NAME)\s*=\s*(.*)|\2 = $(eval echo \$$VAR_FULL_NAME)|g" $CONFIG
        fi
        # Config in plugins/*
        if [[ ! -z "$(cat $CONFIG_PLUGINS/* |grep -E "^(^|^#*|^#*\s*)$VAR_NAME")" ]]; then
            echo "$VAR_NAME=$(eval echo \$$VAR_FULL_NAME)"
            sed -r -i "s|(^#*\s*)($VAR_NAME)\s*=\s*(.*)|\2 = $(eval echo \$$VAR_FULL_NAME)|g" $(ls $CONFIG_PLUGINS/*)
        fi
    fi
    # Config template such like {{ platform_etc_dir }}
    if [[ ! -z "$(echo $VAR | grep -E '^PLATFORM_')" ]]; then
        VAR_NAME=$(echo "$VAR" | sed -r "s/(.*)=.*/\1/g"| tr '[:upper:]' '[:lower:]')
        VAR_FULL_NAME=$(echo "$VAR" | sed -r "s/(.*)=.*/\1/g")
        sed -r -i "s@\{\{\s*$VAR_NAME\s*\}\}@$(eval echo \$$VAR_FULL_NAME)@g" $CONFIG
    fi
done

## EMQ Plugin load settings
# Plugins loaded by default

if [[ ! -z "$EMQ_LOADED_PLUGINS" ]]; then
    echo "EMQ_LOADED_PLUGINS=$EMQ_LOADED_PLUGINS"
    # First, remove special char at header
    # Next, replace special char to ".\n" to fit emq loaded_plugins format
    echo $(echo "$EMQ_LOADED_PLUGINS."|sed -e "s/^[^A-Za-z0-9_]\{1,\}//g"|sed -e "s/[^A-Za-z0-9_]\{1,\}/\. /g")|tr ' ' '\n' > /opt/emqttd/data/loaded_plugins
fi

## EMQ Main script

# Start and run emqttd, and when emqttd crashed, this container will stop

/opt/emqttd/bin/emqttd foreground &

# wait and ensure emqttd status is running
WAIT_TIME=0
while [[ -z "$(/opt/emqttd/bin/emqttd_ctl status |grep 'is running'|awk '{print $1}')" ]]
do
    sleep 1
    echo "['$(date -u +"%Y-%m-%dT%H:%M:%SZ")']:waiting emqttd"
    WAIT_TIME=$((WAIT_TIME+1))
    if [[ $WAIT_TIME -gt 5 ]]; then
        echo "['$(date -u +"%Y-%m-%dT%H:%M:%SZ")']:timeout error"
        exit 1
    fi
done

echo "['$(date -u +"%Y-%m-%dT%H:%M:%SZ")']:emqttd start"

# Run cluster script

if [[ -x "./cluster.sh" ]]; then
    ./cluster.sh &
fi

# Join an exist cluster

if [[ ! -z "$EMQ_JOIN_CLUSTER" ]]; then
    echo "['$(date -u +"%Y-%m-%dT%H:%M:%SZ")']:emqttd try join $EMQ_JOIN_CLUSTER"
    /opt/emqttd/bin/emqttd_ctl cluster join $EMQ_JOIN_CLUSTER &
fi

# Change admin password

if [[ ! -z "$EMQ_ADMIN_PASSWORD" ]]; then
    echo "['$(date -u +"%Y-%m-%dT%H:%M:%SZ")']:admin password changed to $EMQ_ADMIN_PASSWORD"
    /opt/emqttd/bin/emqttd_ctl admins passwd admin $EMQ_ADMIN_PASSWORD &
fi

if [[ -p $EMQ_LOG__ERROR__FILE ]]; then
  mkfifo $EMQ_LOG__ERROR__FILE
fi
tail -f $EMQ_LOG__ERROR__FILE
