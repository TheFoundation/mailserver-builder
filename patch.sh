#!/bin/bash 

test -e debian-mail-overlay.custom && rm -rf debian-mail-overlay.custom
cp -aurv debian-mail-overlay/ debian-mail-overlay.custom
cd  debian-mail-overlay.custom
sed 's/RSPAMD_SHA256_HASH/RSPAMD_SHA256_HASH_amd64/g' -i Dockerfile

[[ -z "$APT_PROXY" ]] ||  (  
insertpoint=$(nl Dockerfile |grep "ARG BUILD_CORES"|sed 's/\t/ /g;s/ \+/ /g;s/^ \+//g'|cut -d" " -f1)
echo patching proxy at LINE $insertpoint
(   
    head -n $insertpoint Dockerfile
    echo 'ARG APT_PROXY='$APT_PROXY

    tail -n $((1+$insertpoint)) Dockerfile
) > Dockerfile.tmp
mv  Dockerfile.tmp Dockerfile

)

sed 's/GUCCI_BINARY="gucci-v${GUCCI_VER}-linux-amd64".\+/GUCCI_BINARY="gucci-v${GUCCI_VER}-linux-"$(uname -m|sed s\/x86_64\/amd64\/|sed s\/aarch64\/arm64\/)/g' Dockerfile -i
sed 's/.\+libhyperscan//g' Dockerfile -i
sed 's/ENABLE_HYPERSCAN=ON/ENABLE_HYPERSCAN=OFF/g' -i Dockerfile 
