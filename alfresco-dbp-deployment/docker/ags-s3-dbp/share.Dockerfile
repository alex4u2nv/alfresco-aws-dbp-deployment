FROM alfresco/alfresco-share:6.1.0
MAINTAINER Alexander Mahabir
USER root
COPY alfresco-rm-enterprise-share-3.0.0.amp /usr/local/tomcat/amps_share/
RUN java -jar /usr/local/tomcat/alfresco-mmt/alfresco-mmt-*.jar install /usr/local/tomcat/amps_share /usr/local/tomcat/webapps/share -directory -nobackup -force
