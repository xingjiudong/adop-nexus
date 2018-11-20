FROM xingjiudong/nexus:2.13.0-01

MAINTAINER xingjiudong <xing.jiudong@trans-cosmos.com.cn>

USER root


ENV JAVA_VERSION=1.8.0 \
    OPENJDK_VERSION=1.8.0.181-3.b13.el7_5

RUN  set -x && mv /opt/jdk* /tmp/ && rm -rf /opt/java && \
     yum install -y \
     java-${JAVA_VERSION}-openjdk-${OPENJDK_VERSION} && \
     ln -s /usr/lib/jvm/java-${JAVA_VERSION}-openjdk-${OPENJDK_VERSION}.x86_64/jre ${JAVA_HOME}

USER nexus

CMD ${JAVA_HOME}/bin/java \
  -Dnexus-work=${SONATYPE_WORK} -Dnexus-webapp-context-path=${CONTEXT_PATH} \
  -Xms${MIN_HEAP} -Xmx${MAX_HEAP} \
  -cp 'conf/:lib/*' \
  ${JAVA_OPTS} \
  org.sonatype.nexus.bootstrap.Launcher ${LAUNCHER_CONF}
