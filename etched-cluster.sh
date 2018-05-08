#!/usr/bin/env bash

membership(){
    docker run -d \
        --name $1 \
        --network ${networkName} \
        --ip $2 \
        -name $1 \
        -initial-cluster $3 \
        -initial-cluster-state new \
        -advertise-client-urls http://$2:${port2379},http://$2:${port4001} \
        -listen-client-urls http://0.0.0.0:${port2379},http://0.0.0.0:${port4001} \
        -initial-advertise-peer-urls http://$2:${port2380} \
        -listen-peer-urls http://0.0.0.0:${port2380} \
        -initial-cluster-token ${clusterToken} \
        ${image} ${exeCmd} 
}

parsePrams(){
    initialcluster=""
    endpoints=""
    for name in ${!members[@]};do
        if [[ ${initialcluster} != "" ]];then
            initialcluster="${initialcluster},${name}=http://${members[${name}]}:${port2380}"
            endpoints="${endpoints},http://${members[${name}]}:${port2379}"
        else
            initialcluster="${name}=http://${members[${name}]}:${port2380}"
            endpoints="${endpoints},http://${members[${name}]}:${port2379}"
        fi
    done
}

memberCreate(){
    # create network
    docker network \
        create ${networkName} \
        --subnet ${subnet}

    # create member
    for name in ${!members[@]};do
        membership ${name} ${members[${name}]}  ${initialcluster}
    done
}

client(){
    # create client & test cluster with etcdctl
    docker run -it \
        --name client \
        --network ${networkName} \
        ${image} sh

    etcdctl --endpoints ${endpoints} set /foo bar
    etcdctl --endpoints ${endpoints} get /foo

    echo "\n\nETCDCTL_API=3"
    ETCDCTL_API=3 etcdctl --endpoints ${endpoints} put foo bar
    ETCDCTL_API=3 etcdctl --endpoints ${endpoints} get foo
}

memberMap(){
    for(( i=$2;i<=$3;i++ ));do
        members["etcd$i"]="$1.$i"
    done
}

main(){
    #basic images define
    image=quay.io/coreos/etcd
    exeCmd=etcd

    networkName=etcd
    subnet=172.19.0.0/16

    clusterToken=etcd-cluster-1

    port2379=2379
    port2380=2380
    port4001=4001

    declare -A members=()
    # member ip： 172.19.1.2 172.19.1.0 172.19.1.1
    memberMap 172.19.1 0 2

    parsePrams

    memberCreate

    client
}

main $@
