FROM ubi8:latest

ENV JAVA_VERSON 1.8.0

RUN yum update -y && \
    yum install -y curl && \
    yum install -y java-$JAVA_VERSON-openjdk java-$JAVA_VERSON-openjdk-devel && \
    yum clean all

RUN yum install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm
RUN yum-config-manager --enable rhel-8-server-optional-rpms
# Install R
RUN yum -y install \
    gcc-c++ \
    gcc \
    make \
    bison \
    flex \
    binutils-devel \
    openldap-devel \
    libicu-devel \
    libxslt-devel \
    libarchive-devel \
    boost-devel \
    openssl-devel \
    apr-devel \
    apr-util-devel
RUN yum -y install R 
# Hack, I don't know why: html directory does not exist.
RUN mkdir -v /usr/share/doc/$(R -s -e 'f <- R.Version(); cat(sprintf("R-%s.%s",f[6],f[7]))')/html

# Hack, install libxml2-devel for R module tm
RUN yum -y install libxml2-devel
COPY Rprofile.site /usr/lib64/R/etc/

RUN mkdir /opt/app-root/R/
RUN chmod -R g+w /opt/app-root/R/
ENV R_LIBS_USER=/opt/app-root/R/

RUN R -s -e "install.packages('shiny', 'rmarkdown', 'devtools', 'RJDBC', 'packrat','plumber', repos = 'http://cran.rstudio.com/' )"
RUN R -s -e "install.packages('remotes', repos = 'http://cran.rstudio.com/' )"
RUN R -s -e "remotes::install_github('MilesMcBain/deplearning')"
# RUN su - -c "R -e \"install.packages(c('shiny', 'rmarkdown', 'devtools', 'RJDBC', 'packrat','plumber',), repos='http://cran.rstudio.com/')\""
COPY /shiny-server-1.5.17.0-s390x.rpm /tmp/shiny-server-1.5.17.0-s390x.rpm
RUN rpm -Uvh /tmp/shiny-server-1.5.17.0-s390x.rpm
# Configure default locale, see https://github.com/rocker-org/rocker/issues/19
RUN localedef -i en_US -f UTF-8 en_US.UTF-8
ENV LC_ALL en_US.UTF-8
ENV LANG en_US.UTF-8
RUN mkdir -p /var/lib/shiny-server/bookmarks && \
    chown default:0 /var/lib/shiny-server/bookmarks && \
    chmod g+wrX /var/lib/shiny-server/bookmarks && \
    mkdir -p /var/log/shiny-server && \
    chown default:0 /var/log/shiny-server && \
    chmod g+wrX /var/log/shiny-server 

## Also touch the packrat folder which is backed up and restored between incremental builds (use s2i with --incremental)
RUN id && echo " " && whoami && mkdir -p /opt/app-root/src/packrat/ && \
    chgrp -R 0 /opt/app-root/src/packrat/ && \
    chmod g+wrX /opt/app-root/src/packrat/

### Setup user for build execution and application runtime
### https://github.com/RHsyseng/container-rhel-examples/blob/master/starter-arbitrary-uid/Dockerfile.centos7
ENV APP_ROOT=/opt/app-root
ENV PATH=${APP_ROOT}/bin:${PATH} HOME=${APP_ROOT}
COPY bin/ ${APP_ROOT}/bin/
RUN chmod -R u+x ${APP_ROOT}/bin && \
    chgrp -R 0 ${APP_ROOT} && \
    chmod -R g=u ${APP_ROOT} /etc/passwd
# # #
RUN yum update && yum install -y \
    nano \
    supervisor 
RUN mkdir -p /var/log/supervisord
#copy application
COPY /app /srv/shiny-server/
#
# Copy configuration files into the Docker image
COPY shiny-server.conf  /etc/shiny-server/shiny-server.conf
COPY shiny-server.sh /usr/bin/shiny-server.sh
RUN chmod +x /usr/bin/shiny-server.sh
COPY run-myfile.R /srv/shiny-server/
COPY plumb.sh /usr/bin/plumb.sh
RUN chmod +x /usr/bin/plumb.sh
RUN rm -rf /tmp/*
# Make the ShinyApp available at port 1240
EXPOSE 9443 8000
#
COPY /supervisord.conf /etc/
RUN chgrp -Rf root /var/log/supervisord && chmod -Rf g+rwx /var/log/supervisord
RUN chgrp -Rf root /var/log/shiny-server && chmod -Rf g+rwx /var/log/shiny-server
RUN chgrp -Rf root /srv/shiny-server && chmod -Rf g+rwx /srv/shiny-server
RUN chgrp -Rf root /var/lib/shiny-server && chmod -Rf g+rwx /var/lib/shiny-server
RUN chgrp -Rf root /etc/shiny-server && chmod -Rf g+rwx /etc/shiny-server

RUN chmod -Rf g+rwx /var/log/supervisord
RUN chmod -Rf g+rwx /var/log/shiny-server 
RUN chmod -Rf g+rwx /srv/shiny-server
RUN chmod -Rf g+rwx /var/lib/shiny-server
RUN chmod -Rf g+rwx /etc/shiny-server

#VOLUME [ "/tmp/log/supervisord" ]
WORKDIR /var/log/supervisord
#

# ###Adjust permissions on /etc/passwd so writable by group root.
RUN chmod g+w /etc/passwd
### Access Fix 24
COPY /scripts/uid-set.sh /usr/bin/
RUN chmod +x /usr/bin/uid-set.sh
# RUN /usr/bin/uid-set.sh
####################
ENTRYPOINT ["/usr/bin/supervisord", "-c", "/etc/supervisord.conf"]  
