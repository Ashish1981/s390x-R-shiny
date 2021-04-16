FROM docker.io/ashish1981/s390x-clefos-shiny

COPY Rprofile.site /usr/lib64/R/etc/

RUN mkdir -p /var/lib/shiny-server/bookmarks && \
    chown shiny:0 /var/lib/shiny-server/bookmarks && \
    chmod g+wrX /var/lib/shiny-server/bookmarks && \
    mkdir -p /var/log/shiny-server && \
    chown shiny:0 /var/log/shiny-server && \
    chmod g+wrX /var/log/shiny-server 

## Also touch the packrat folder which is backed up and restored between incremental builds (use s2i with --incremental)
RUN id && echo " " && whoami && mkdir -p /opt/app-root/src/packrat/ && \
    chgrp -R 0 /opt/app-root/src/packrat/ && \
    chmod g+wrX /opt/app-root/src/packrat/

### Setup user for build execution and application runtime
### https://github.com/RHsyseng/container-rhel-examples/blob/master/starter-arbitrary-uid/Dockerfile.centos7
ENV APP_ROOT=/opt/app-root
ENV PATH=${APP_ROOT}/bin:${PATH} HOME=${APP_ROOT}
RUN chmod -R u+x ${APP_ROOT}/bin && \
    chgrp -R 0 ${APP_ROOT} && \
    chmod -R g=u ${APP_ROOT} /etc/passwd
# # #

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
