#!/bin/bash

# get stored SGE hostname
export SGE_HOST=`cat /opt/sge/default/common/act_qmaster`

# rename files
find /opt/sge/ -name "*$SGE_HOST*" | sed -e "p;s/f7e33910641b/$HOSTNAME/" | xargs -n2 mv

# replace SGE_HOST text in files
grep -Rl "$SGE_HOST" /opt/sge/ | xargs sed -i "s/$SGE_HOST/$HOSTNAME/g"

# execute SGE
/etc/init.d/sgemaster.docker-sge restart
/etc/init.d/sgeexecd.docker-sge restart
