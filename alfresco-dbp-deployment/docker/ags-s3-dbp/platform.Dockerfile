FROM alfresco/alfresco-content-repository-aws:6.1.0.2
MAINTAINER Alexander Mahabir
USER root
COPY alfresco-rm-api.war /usr/local/tomcat/webapps/alfresco-rm-api.war
COPY alfresco-rm-enterprise-repo-3.0.0.amp /usr/local/tomcat/amps/

RUN  java -jar /usr/local/tomcat/alfresco-mmt/alfresco-mmt-6.0.jar install /usr/local/tomcat/amps /usr/local/tomcat/webapps/alfresco -directory -nobackup -force
RUN  cd /usr/local/tomcat/webapps; mkdir rm-api-explorer; cd rm-api-explorer; jar -xf ../alfresco-rm-api.war ; rm ../alfresco-rm-api.war