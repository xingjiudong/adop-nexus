FROM sonatype/nexus:2.13.0-01

MAINTAINER Robert Northard, <robert.a.northard>

ENV LDAP_ENABLED=true \
    CONTEXT_PATH=/nexus \
    NEXUS_HOME=/sonatype-work/ \
    DEBUG_LOGGING=false \
    LDAP_SEARCH_BASE="" \
    LDAP_URL="" \
    LDAP_PORT=389 \
    LDAP_AUTH_PROTOCOL=ldap \
    LDAP_USER_EMAIL_ATTRIBUTE=mail \
    LDAP_GROUPS_AS_ROLES=true \
    LDAP_GROUP_BASE_DN=ou=groups \
    LDAP_GROUP_ID_ATTRIBUTE=cn \
    LDAP_GROUP_MEMBER_ATTRIBUTE=uniqueMember \
    LDAP_GROUP_OBJECT_CLASS=groupOfUniqueNames \
    LDAP_PREFERRED_PASSWORD_ENCODING=crypt \
    LDAP_USER_ID_ATTRIBUTE=uid \
    LDAP_USER_PASSWORD_ATTRIBUTE=userPassword \
    LDAP_USER_OBJECT_CLASS=inetOrgPerson \
    LDAP_USER_BASE_DN=ou-people \
    LDAP_USER_REAL_NAME_ATTRIBUTE=cn \
    LDAP_GROUP_MEMBER_FORMAT=dn \
    LDAP_USER_SUBTREE=false \
    LDAP_GROUP_SUBTREE=false \
    NEXUS_CREATE_CUSTOM_ROLES=false \
    ADMIN_EMAIL=changeme@yourcompany.com

USER root

COPY resources/nexus.sh /usr/local/bin/
COPY resources/ /resources/

RUN chmod u+x /usr/local/bin/nexus.sh

ENTRYPOINT ["/usr/local/bin/nexus.sh"]
