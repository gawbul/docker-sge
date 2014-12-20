# Dockerfile to build SGE enabled container
#
# VERSION 0.1

# use vanilla ubuntu base image
FROM phusion/baseimage:0.9.15

# maintained by me
MAINTAINER Steve Moss <gawbul@gmail.com>

# expose ports
EXPOSE 6444
EXPOSE 6445
EXPOSE 6446

# run everything as root to start with
USER root

# set environment variables
ENV HOME /root

# regenerate host ssh keys
RUN /etc/my_init.d/00_regen_ssh_host_keys.sh

# add pin priority to some graphical packages to stop them installing and borking the build
RUN echo "Package: xserver-xorg*\nPin: release *\nPin-Priority: -1" >> /etc/apt/preferences
RUN echo "Package: unity*\nPin: release *\nPin-Priority: -1" >> /etc/apt/preferences
RUN echo "Package: gnome*\nPin: release *\nPin-Priority: -1" >> /etc/apt/preferences

# turn off password requirement for sudo groups users
RUN sed -i "s/^\%sudo\tALL=(ALL:ALL)\sALL/%sudo ALL=(ALL) NOPASSWD:ALL/" /etc/sudoers

# install required software as per README.BUILD
RUN apt-get update -y
RUN apt-get upgrade -y
RUN apt-get install -y wget darcs git mercurial tcsh build-essential automake autoconf openssl libssl-dev munge libmunge2 libmunge-dev libjemalloc1 libjemalloc-dev db5.3-util libdb-dev libncurses5 libncurses5-dev libpam0g libpam0g-dev libpacklib-lesstif1-dev libmotif-dev libxmu-dev libxpm-dev hwloc libhwloc-dev openjdk-7-jre openjdk-7-jdk ant ant-optional javacc junit libswing-layout-java libxft2 libxft-dev libreadline-dev man gawk

# add files to container from local directory
ADD izpack_auto_install.xml /root/izpack_auto_install.xml
ADD sge_auto_install.conf /root/sge_auto_install.conf
ADD docker_sge_init.sh /etc/my_init.d/01_docker_sge_init.sh
ADD sge_exec_host.conf /root/sge_exec_host.conf
ADD sge_queue.conf /root/sge_queue.conf
RUN chmod ug+x /etc/my_init.d/01_docker_sge_init.sh

# change to home directory
WORKDIR $HOME

# retrieve required files
RUN wget -c http://dist.codehaus.org/izpack/releases/4.3.5/IzPack-install-4.3.5.jar
RUN wget -c http://www.mirrorservice.org/sites/archive.ubuntu.com/ubuntu/pool/main/libz/libzip/libzip1_0.9-3_amd64.deb
RUN wget -c http://www.mirrorservice.org/sites/archive.ubuntu.com/ubuntu/pool/main/libz/libzip/libzip-dev_0.9-3_amd64.deb
RUN wget -c http://archive.cloudera.com/one-click-install/lucid/cdh3-repository_1.0_all.deb

# install izpack
RUN java -jar IzPack-install-4.3.5.jar ~/izpack_auto_install.xml
ENV PATH /usr/local/izpack/bin:$PATH
RUN echo export PATH=/usr/local/izpack/bin:$PATH >> /etc/bashrc

# install hadoop
RUN dpkg -i libzip1_0.9-3_amd64.deb
RUN dpkg -i libzip-dev_0.9-3_amd64.deb
RUN dpkg -i cdh3-repository_1.0_all.deb
RUN apt-get update && apt-get -y install hadoop-0.20 hadoop-0.20-native

# clone the SGE git repository
# git repo takes forever
# issues with the hg repository currently
# probems with darcs too that docker doesn't like
#RUN hg clone http://arc.liv.ac.uk/repos/hg/sge
#RUN darcs get --lazy --set-scripts-executable http://arc.liv.ac.uk/repos/darcs/sge
#RUN git clone http://arc.liv.ac.uk/repos/git/sge
# download source tarball instead
RUN wget -c http://arc.liv.ac.uk/downloads/SGE/releases/8.1.8/sge-8.1.8.tar.gz
RUN tar -zxvf sge-8.1.8.tar.gz

# change working directory
WORKDIR $HOME/sge-8.1.8/source

# setup SGE env
ENV SGE_ROOT /opt/sge
ENV SGE_CELL default
RUN echo export SGE_ROOT=/opt/sge >> /etc/bashrc
RUN echo export SGE_CELL=default >> /etc/bashrc
RUN ln -s $SGE_ROOT/$SGE_CELL/common/settings.sh /etc/profile.d/sge_settings.sh

# install SGE
RUN mkdir /opt/sge
RUN useradd -r -m -U -d /home/sgeadmin -s /bin/bash -c "Docker SGE Admin" sgeadmin
RUN usermod -a -G sudo sgeadmin
RUN sh scripts/bootstrap.sh && ./aimk && ./aimk -man
RUN echo Y | ./scripts/distinst -local -allall -libs -noexit
WORKDIR $SGE_ROOT
RUN ./inst_sge -m -x -s -auto ~/sge_auto_install.conf \
&& /etc/my_init.d/01_docker_sge_init.sh && sed -i "s/HOSTNAME/`hostname`/" $HOME/sge_exec_host.conf \
&& /opt/sge/bin/lx-amd64/qconf -au sgeadmin arusers \
&& /opt/sge/bin/lx-amd64/qconf -Me $HOME/sge_exec_host.conf \
&& /opt/sge/bin/lx-amd64/qconf -Aq $HOME/sge_queue.conf

ENV PATH /opt/sge/bin:/opt/sge/bin/lx-amd64/:/opt/sge/utilbin/lx-amd64:$PATH
RUN echo export PATH=/opt/sge/bin:/opt/sge/bin/lx-amd64/:/opt/sge/utilbin/lx-amd64:$PATH >> /etc/bashrc

# return to home directory
WORKDIR $HOME

# clean up
RUN rm *.deb
RUN rm *.jar
RUN rm *.tar.gz
RUN rm -rf sge-8.1.8
RUN apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# start my_init on execution and pass bash to runit
ENTRYPOINT ["/sbin/my_init", "--"]
CMD ["/bin/bash"]
