       #!/bin/bash 

        test -e debian-mail-overlay.custom && rm -rf debian-mail-overlay.custom
        cp -aurv debian-mail-overlay/ debian-mail-overlay.custom
        cd  debian-mail-overlay.custom
        [[ -z "$APT_PROXY" ]] ||  (  
        insertpoint=$(nl Dockerfile |grep "ARG BUILD_CORES"|sed 's/\t/ /g;s/ \+/ /g;s/^ \+//g'|cut -d" " -f1)
        echo patching proxy at LINE $insertpoint
        (   
            head -n $insertpoint Dockerfile
            echo 'ARG APT_PROXY='$APT_PROXY
            echo 'RUN apt-get update && apt-get install -y ca-certificates && apt-get clean all'
            echo 'RUN sed "s~http://~http://"$APT_PROXY"/~g" -i /etc/apt/sources.list && apt update'
            tail -n +$((1+$insertpoint)) Dockerfile
        ) > Dockerfile.tmp
        mv  Dockerfile.tmp Dockerfile
        )

        insertpoint=$(nl Dockerfile |grep "ARG BUILD_CORES"|sed 's/\t/ /g;s/ \+/ /g;s/^ \+//g'|cut -d" " -f1)
        echo patching arm64 gucci at LINE $insertpoint

        (   
            head -n $insertpoint Dockerfile
            echo 'RUN $(curl -s https://github.com/noqcks/gucci/releases/download/$(cat Dockerfile|grep GUCCI_VER=|grep ARG|cut -d"=" -f2)/checksums.txt -kL |grep linux-arm64|cut -d" " -f1 |cut -f1) > /etc/GUCCI_SHA256_HASH-arm64 '
            echo 'RUN $(curl -s https://github.com/noqcks/gucci/releases/download/$(cat Dockerfile|grep GUCCI_VER=|grep ARG|cut -d"=" -f2)/checksums.txt -kL |grep linux-amd64|cut -d" " -f1 |cut -f1) > /etc/GUCCI_SHA256_HASH-amd64 '
            tail -n +$((1+$insertpoint)) Dockerfile
        ) > Dockerfile.tmp
        mv  Dockerfile.tmp Dockerfile


        #sed 's/GUCCI_BINARY="gucci-v${GUCCI_VER}-linux-amd64".\+/GUCCI_BINARY="gucci-v${GUCCI_VER}-linux-"$(uname -m|sed s\/x86_64\/amd64\/|sed s\/aarch64\/arm64\/) \\/g' Dockerfile -i
        sed 's/GUCCI_BINARY="gucci-v${GUCCI_VER}-linux-amd64"/GUCCI_BINARY="gucci-v${GUCCI_VER}-linux-${MYARCH}"/g' Dockerfile -i
        sed 's/"${GUCCI_SHA256_HASH_amd64}"/"$(cat \/etc\/GUCCI_SHA256_HASH)"/g' -i Dockerfile
        sed 's/.\+libhyperscan.\+//g' Dockerfile -i
        sed 's/ENABLE_HYPERSCAN=ON/ENABLE_HYPERSCAN=OFF/g' -i Dockerfile 
        sed 's/GUCCI_BINARY=/cat  \/etc\/GUCCI_SHA256_HASH-$( uname -m|sed s\/x86_64\/amd64\/|sed s\/aarch64\/arm64\/ ) >  \/etc\/GUCCI_SHA256_HASH \&\& echo ARCH $MYARCH \&\& varname=GUCCI_SHA256_HASH_$MYARCH \&\& GUCCI_SHA256_HASH_EXPECTED=${!varname} \&\& echo expecting $GUCCI_SHA256_HASH_EXPECTED  \&\& GUCCI_BINARY=/g'  Dockerfile -i
        sed 's~^ && cd /tmp.\+~ \&\& echo BUILD_OK\n RUN cd /tmp \\~g' -i Dockerfile
