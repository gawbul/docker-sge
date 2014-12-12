# Dockerfile to build SGE enabled container
#
# VERSION 0.1

# use vanilla ubuntu base image
FROM ubuntu:14.04

# maintained by me
MAINTAINER Steve Moss <gawbul@gmail.com>

# add pin priority to some graphical packages to stop them installing and borking the build
RUN echo "Package: xserver-xorg*\nPin: release *\nPin-Priority: -1" >> /etc/apt/preferences
RUN echo "Package: unity*\nPin: release *\nPin-Priority: -1" >> /etc/apt/preferences
RUN echo "Package: gnome*\nPin: release *\nPin-Priority: -1" >> /etc/apt/preferences

# install required software as per README.BUILD
RUN apt-get update -y
RUN apt-get upgrade -y
RUN apt-get install -y wget darcs git mercurial tcsh build-essential automake autoconf openssl libssl-dev munge libmunge2 libmunge-dev libjemalloc1 libjemalloc-dev db5.3-util libdb-dev libncurses5 libncurses5-dev libpam0g libpam0g-dev libpacklib-lesstif1-dev libmotif-dev libxmu-dev libxpm-dev hwloc libhwloc-dev openjdk-7-jre openjdk-7-jdk ant ant-optional javacc junit libswing-layout-java libxft2 libxft-dev libreadline-dev man gawk

# set environment variables
ENV HOME /root

# expose ports
EXPOSE 6444
EXPOSE 6445
EXPOSE 6446

# add files to container from local directory
ADD izpack-auto-install.xml $HOME/izpack-auto-install.xml
ADD sge-auto-install.conf $HOME/sge-auto-install.conf
ADD docker-sge-init.sh $HOME/docker-sge-init.sh

# change to home directory
WORKDIR $HOME

# retrieve required files
RUN wget -c http://dist.codehaus.org/izpack/releases/4.3.5/IzPack-install-4.3.5.jar
RUN wget -c http://www.mirrorservice.org/sites/archive.ubuntu.com/ubuntu/pool/main/libz/libzip/libzip1_0.9-3_amd64.deb
RUN wget -c http://www.mirrorservice.org/sites/archive.ubuntu.com/ubuntu/pool/main/libz/libzip/libzip-dev_0.9-3_amd64.deb
RUN wget -c http://archive.cloudera.com/one-click-install/lucid/cdh3-repository_1.0_all.deb

# install izpack
RUN java -jar IzPack-install-4.3.5.jar ~/izpack-auto-install.xml
ENV PATH /usr/local/izpack/bin:$PATH

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
RUN echo "This takes ages! Please be patient..."
RUN git clone http://arc.liv.ac.uk/repos/git/sge

# change to the SGE source directory
WORKDIR $HOME/sge/source

# install SGE
ENV SGE_ROOT /opt/sge
RUN mkdir /opt/sge
RUN useradd -m -s /bin/bash -U sgeadmin
RUN sh scripts/bootstrap.sh && ./aimk && ./aimk -man
RUN echo Y | ./scripts/distinst -local -allall -libs -noexit
WORKDIR $SGE_ROOT
RUN ./inst_sge -m -x -s -auto ~/sge-auto-install.conf
ENV PATH /opt/sge/bin:/opt/sge/bin/lx-amd64/:/opt/sge/utilbin/lx-amd64:$PATH

# return to home directory
WORKDIR $HOME

# clean up
RUN rm *.deb
RUN rm *.jar

# set hostname
#RUN sudo su root -c hostname docker-sge && \
#echo "docker-sge" > /etc/hostname && \
#cat /etc/hosts | sed "1s/.*/`hostname -i` docker-sge/" > /etc/hosts

# commands to run on execution
RUN chmod ug+x docker-sge-init.sh
CMD ./docker-sge-init.sh