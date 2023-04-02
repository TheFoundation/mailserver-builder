#!/bin/bash
<<<<<<< HEAD

test -e  /tmp/buildcache_persist || mkdir /tmp/buildcache_persist

test -e  /tmp/buildcache_persist/config || mkdir /tmp/buildcache_persist/config


##echo  '# listen_address is the listening address of go-apt-cacher.
### Default is ":3142".
##listen_address = ":3142"
##
### Interval to check updates for Release/InRelease files.
### Default: 600 seconds
##check_interval = 600
##
### Cache period for bad HTTP response statuses.
### Default: 3 seconds
##cache_period = 3
##
### Directory for meta data files.
### The directory owner must be the same as the process owner of go-apt-cacher.
##meta_dir = "/var/spool/go-apt-cacher/meta"
##
### Directory for non-meta data files.
### This directory must be different from meta_dir.
### The directory owner must be the same as the process owner of go-apt-cacher.
##cache_dir = "/var/spool/go-apt-cacher/cache"
##
### Capacity for cache_dir.
### Default: 1 GiB
##cache_capacity = 1
##
### Maximum concurrent connections for an upstream server.
### Setting this 0 disables limit on the number of connections.
### Default: 10
##max_conns = 10
##
### log specifies logging configurations.
### Details at https://godoc.org/github.com/cybozu-go/well#LogConfig
##[log]
###filename = "/var/log/go-apt-cacher.log"
##level = "info"
##format = "plain"
##
### mapping declares which prefix maps to a Debian repository URL.
### prefix must match this regexp: ^[a-z0-9._-]+$
##[mapping]
##ubuntu = "http://archive.ubuntu.com/ubuntu"
##security = "http://security.ubuntu.com/ubuntu"
##
##' |tee  /tmp/buildcache_persist/config/go-apt-cacher.toml |nl
##
##
## docker run -d --restart unless-stopped --name go-apt-cacher \
##    -v /tmp/buildcache_persist/config/go-apt-cacher.toml:/etc/go-apt-cacher.toml:ro \
##    -v /tmp/buildcache_persist/go-apt-cacher:/var/spool/go-apt-cacher \
##    jacksgt/aptutil /go-apt-cacher
##
##proxydetect=$(
    
##     docker inspect go-apt-cacher|grep IPAddress|cut -d'"' -f4|grep -v ^$|sort -u |while read testip;do curl -s $testip:3142/page-not-found |grep -q  "404 page not found" && echo $testip:3142 ;done|head -n1
##)
( cd /tmp/;test -e buildcache_persist ||  (
            docker pull $CICACHETAG &&             (
                cd /tmp/;docker save $CICACHETAG > /tmp/.importCI ; 
                                               cat /tmp/.importCI |tar xv --to-stdout  $(cat /tmp/.importCI|tar t|grep layer.tar) |tar xv)
    )

docker run  -d --restart unless-stopped --name ultra-apt-cacher  -v /tmp/buildcache_persist/apt-cacher-ng:/var/cache/apt-cacher-ng registry.gitlab.com/the-foundation/ultra-apt-cacher-ng
proxydetect=$(
     docker inspect ultra-apt-cacher |grep IPAddress|cut -d'"' -f4|grep -v ^$|sort -u |while read testip;do curl -s $testip:80/|grep apt|grep -q cache && echo $testip:80 ;done|head -n1
)


[[ -z "$proxydetect" ]] || export APT_PROXY=$proxydetect
echo "PROXYING TO : $APT_PROXY"

_ping_docker_registry_v2() {
    res=$(curl $1"/v2/_catalog" 2>/dev/null)
    echo "$res"|grep repositories -q && echo "OK"
    echo "$res"|grep repositories -q || echo "FAIL"
}
_ping_localhost_registry() {
    _ping_docker_registry_v2 127.0.0.1:5000
}
_get_docker_localhost_registry_ip() {
         docker inspect registry |grep IPAddress|cut -d'"' -f4|grep -v ^$|sort -u |while read testip;do 
         _ping_docker_registry_v2 $testip:5000|grep -q OK && echo $testip:5000 ;done|head -n1

}

[[ -z "$LOCAL_REGISTRY_CACHE" ]] && LOCAL_REGISTRY_CACHE=/tmp/buildcache_persist/registry

docker run -d -p 5000:5000 --restart=always   --name registry   -v $LOCAL_REGISTRY_CACHE:/var/lib/registry   registry:2
echo -n "LOCAL_REGISTRY: "
_ping_localhost_registry && CACHE_REGISTRY_HOST=$(_get_docker_localhost_registry_ip)

#BUILD_TARGET_PLATFORMS="linux/amd64,linux/arm64,linux/arm/v7,darwin"
#BUILD_TARGET_PLATFORMS="linux/amd64,linux/arm64,linux/arm/v7"
BUILD_TARGET_PLATFORMS="linux/amd64,linux/arm64"
#BUILD_TARGET_PLATFORMS="linux/amd64"


test -e debian-mail-overlay/Dockerfile ||git submodule update --init

( bash patch.sh ; 
  cd debian-mail-overlay.custom/;
sed 's~^ && cd /tmp.\+~ \&\& echo BUILD_OK\n RUN cd /tmp \\~g' -i Dockerfile;
docker pull 127.0.0.1:5000/mailserver2/debian-mail-overlay;
BUILDKIT_PRE=$DOCKER_BUILDKIT
export  DOCKER_BUILDKIT=0
time docker build  . --progress plain -t 127.0.0.1:5000/mailserver2/debian-mail-overlay 
docker push 127.0.0.1:5000/mailserver2/debian-mail-overlay 
export  DOCKER_BUILDKIT=$BUILDKIT_PRE

)
echo "MULTIARCH"
(
test -e /tmp/BUILDER_TOK|| (echo "$RANDOM"'-BUILD-'$(date +%Y%m%d-%s)>/tmp/BUILDER_TOK)
BUILDER_TOK=$(cat /tmp/BUILDER_TOK)
export DOCKER_BUILDKIT=1
docker buildx install
docker buildx ls |grep -B1 inactive|sed 's/^ \+//g'|cut -d" " -f1|while read builder;do docker buildx rm $builder;done
docker buildx rm mybuilder_${BUILDER_TOK} ;
echo -n "buildx:create:qemu"  ;
docker run --rm --privileged multiarch/qemu-user-static --reset -p yes &>/dev/shm/.setup.2.qemu
echo -n "buildx:create:qemu" ;
docker buildx create  --use --driver=docker-container  --buildkitd-flags '--allow-insecure-entitlement network.host' --use --driver-opt network=host  --name mybuilder_${BUILDER_TOK} &>/dev/shm/.setup.3.build
docker buildx inspect --bootstrap &>/dev/shm/.setup.4.buildx.bootstrap

cd debian-mail-overlay.custom/
REGISTRY_HOST=127.0.0.1:5000
REGISTRY_PROJECT=thefoundation
PROJECT_NAME=mailserver2
IMAGETAG_SHORT=debian-mailoverlay
CACHE_REGISTRY_HOST=127.0.0.1:5000

DFILENAME=Dockerfile

BUILDX_OUT="--output=type=docker "
BUILDX_OUT="--output=type=registry,push=false "

[[ -z "$CACHE_REGISTRY_HOST" ]]    && CACHE_REGISTRY_HOST=$REGISTRY_HOST
[[ -z "$CACHE_REGISTRY_PROJECT" ]] && CACHE_REGISTRY_PROJECT=$REGISTRY_PROJECT
[[ -z "$CACHE_PROJECT_NAME" ]] && CACHE_PROJECT_NAME=$PROJECT_NAME




docker buildx build  $BUILDX_OUT  --pull --progress plain --network=host --memory-swap -1 --memory 1024M --platform=linux/amd64 --cache-from=type=daemon --cache-to=type=registry,ref=${CACHE_REGISTRY_HOST}/${CACHE_REGISTRY_PROJECT}/${CACHEPROJECT_NAME}:zzz_buildcache_${IMAGETAG_SHORT} -t ${REGISTRY_HOST}/${REGISTRY_PROJECT}/${PROJECT_NAME}:${IMAGETAG_SHORT} . -f ${DFILENAME}

docker buildx build  $BUILDX_OUT  --pull --push --progress plain --network=host --memory-swap -1 --memory 1024M --platform=${BUILD_TARGET_PLATFORMS} --cache-from=type=registry,ref=${CACHE_REGISTRY_HOST}/${CACHE_REGISTRY_PROJECT}/${CACHEPROJECT_NAME}:zzz_buildcache_${IMAGETAG_SHORT} -t ${REGISTRY_HOST}/${REGISTRY_PROJECT}/${PROJECT_NAME}:${IMAGETAG_SHORT} . -f ${DFILENAME}

)


( cd /tmp/;test -e /tmp/buildcache_persist &&  (
    
    CICACHETAG=${CACHE_REGISTRY_HOST}/${CACHE_REGISTRY_PROJECT}/${CACHEPROJECT_NAME}:cicache_${REGISTRY_PROJECT}_${PROJECT_NAME}_${IMAGETAG_SHORT}
    sudo tar cv buildcache_persist |docker import - "$CICACHETAG" && docker push "$CICACHETAG"  )
     )

##    echo "${IMAGETAG_SHORT}" |grep -e baseimage -e base-image &&      
=======
teste -e debian-mail-overlay||git submodule update --init
( bash patch.sh ; cd debian-mail-overlay.custom/;sed 's~^ && cd /tmp.\+~ \&\& echo BUILD_OK\n RUN cd /tmp \\~g' -i Dockerfile;time docker build .)
>>>>>>> parent of 2b71a86 (.)
