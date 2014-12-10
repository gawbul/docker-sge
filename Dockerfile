# Dockerfile to build SGE enabled container
#
# VERSION 0.1

# use vanilla ubuntu base image
FROM ubuntu

# maintained by me
MAINTAINER Steve Moss <gawbul@gmail.com>

# set HOME environment variable is /root
ENV HOME /root

# install required software as per README.BUILD
RUN apt-get update && apt-get -y install wget darcs git mercurial vim tcsh build-essential automake autoconf openssl libssl-dev munge libmunge2 libmunge-dev libjemalloc1 libjemalloc-dev db5.3-util libdb-dev libncurses5 libncurses5-dev libpam0g libpam0g-dev libpacklib-lesstif1-dev libmotif-dev libxmu-dev libxpm-dev hwloc libhwloc-dev openjdk-7-jre openjdk-7-jdk ant ant-optional javacc junit libswing-layout-java libxft2 libxft-dev libreadline-dev

# change to home directory
WORKDIR $HOME

# install izpack
RUN wget -c http://dist.codehaus.org/izpack/releases/4.3.5/IzPack-install-4.3.5.jar
ADD auto-install.xml $HOME/auto-install.xml
RUN java -jar IzPack-install-4.3.5.jar auto-install.xml
ENV PATH $PATH:/usr/local/izpack/bin

# install hadoop
RUN wget -c http://www.mirrorservice.org/sites/archive.ubuntu.com/ubuntu/pool/main/libz/libzip/libzip1_0.9-3_amd64.deb
RUN wget -c http://www.mirrorservice.org/sites/archive.ubuntu.com/ubuntu/pool/main/libz/libzip/libzip-dev_0.9-3_amd64.deb
RUN dpkg -i libzip1_0.9-3_amd64.deb
RUN dpkg -i libzip-dev_0.9-3_amd64.deb
RUN wget -c http://archive.cloudera.com/one-click-install/lucid/cdh3-repository_1.0_all.deb
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

# change to SGE source directory
WORKDIR $HOME/sge/source

# install SGE
RUN sh scripts/bootstrap.sh && ./aimk && ./aimk -man
RUN mkdir /opt/sge
ENV SGE_ROOT /opt/sge
RUN echo Y | ./scripts/distinst -local -allall -libs -noexit
WORKDIR $SGE_ROOT
#RUN ./inst_sge -m -x -csp
ENV PATH /opt/sge/bin:/opt/sge/bin/lx-amd64/:$PATH

# return to home directory
WORKDIR $HOME

# clean up
RUN rm *.deb
RUN rm *.jar