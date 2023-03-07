#!/bin/bash
teste -e debian-mail-overlay||git submodule update --init
( bash patch.sh ; cd debian-mail-overlay.custom/;sed 's~^ && cd /tmp.\+~ \&\& echo BUILD_OK\n RUN cd /tmp \\~g' -i Dockerfile;time docker build .)
