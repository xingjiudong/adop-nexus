#! /bin/bash
set -e

echo "Starting Nexus."
echo "$(date) - LDAP Enabled: ${LDAP_ENABLED}"

# Copy config files.
mkdir -p ${NEXUS_HOME}conf

# Nexus configuration is split into two catagories -
# * Managed : Configuration which is updated everytime container is restarted 
# * Unmanaged : Configuration which is copied only if the files is missing.
cp -R /resources/conf/managed/* ${NEXUS_HOME}conf
cp -R -n /resources/conf/unmanaged/* ${NEXUS_HOME}conf

# Copy in custom logback configuration which prints application and access logs to stdout if environment variable is set to true
cp /resources/conf/logback/logback.properties ${NEXUS_HOME}conf
if [[ ${DEBUG_LOGGING} == true ]]
  then
  cp /resources/conf/logback/logback-nexus.xml ${NEXUS_HOME}conf
  cp /resources/conf/logback/logback-access.xml /opt/sonatype/nexus/conf/
fi

# Delete lock file if instance was not shutdown cleanly.
if [ -e "${NEXUS_HOME}/nexus.lock" ] 
       then
       echo "$(date) Application was not shutdown cleanly, deleting lock file."
       rm -rf ${NEXUS_HOME}/nexus.lock
fi

if [ -n "${USER_AGENT}" ]
       then
       echo "nexus.browserdetector.excludedUserAgents=${USER_AGENT}" >> /opt/sonatype/nexus/conf/nexus.properties
fi

if [ -n "${NEXUS_BASE_URL}" ]
       then
       # Add base url - requests timeout if incorrect
       sed -i "s#<baseUrl>.*#<baseUrl>${NEXUS_BASE_URL}</baseUrl>#" ${NEXUS_HOME}/conf/nexus.xml
       echo "$(date) - Base URL: ${NEXUS_BASE_URL}"
fi

# Update Remote proxy configuration
if [[ -n "${NEXUS_PROXY_HOST}" ]] && [[ -n "${NEXUS_PROXY_PORT}" ]]
    then
    echo "$(date) - Proxy Host: ${NEXUS_PROXY_HOST}"
    echo "$(date) - Proxy Port: ${NEXUS_PROXY_PORT}"
    REMOTE_PROXY_SETTINGS="<remoteProxySettings>\
    \n    <httpProxySettings>\
    \n      <proxyHostname>${NEXUS_PROXY_HOST}</proxyHostname>\
    \n      <proxyPort>${NEXUS_PROXY_PORT}</proxyPort>\
    \n    </httpProxySettings>\
    \n  </remoteProxySettings>"
   sed -i "s+<remoteProxySettings />+${REMOTE_PROXY_SETTINGS}+" ${NEXUS_HOME}/conf/nexus.xml
fi 

# Update Central Repo configuration
if [ ! -z "${NEXUS_CENTRAL_REPO_URL}" ]
        then
        echo "$(date) - Central Repository URL: ${NEXUS_CENTRAL_REPO_URL}"
        sed -i "s#https://repo1.maven.org/maven2/#${NEXUS_CENTRAL_REPO_URL}#" ${NEXUS_HOME}/conf/nexus.xml
fi

# add tasks
if [[ -s ${TASK_FILE} ]]
       then
       # add task
       sed -i "/<!--insert-task-->/r ${TASK_FILE}" ${NEXUS_HOME}/conf/nexus.xml
       echo "$(date) - add Tasks"
fi

# Change SMTP Setting
if [ -n "${SMTP_HOST}" ]
       then
       sed -i "s/<hostname>smtp-host<\/hostname>/<hostname>${SMTP_HOST}<\/hostname>/g" ${NEXUS_HOME}/conf/nexus.xml
       sed -i "s/<port>25<\/port>/<port>${SMTP_PORT}<\/port>/g" ${NEXUS_HOME}/conf/nexus.xml
       sed -i "s/<username>smtp-username<\/username>/<username>${SMTP_USERNAME}<\/username>/g" ${NEXUS_HOME}/conf/nexus.xml
       sed -i "s/<password>{dbGYQfqecdAHZ5P+VwFXN4cuyM0oaid5+hiYFwTj8b4=}<\/password>/<password>${SMTP_PASSWORD}<\/password>/g" ${NEXUS_HOME}/conf/nexus.xml
       sed -i "s/<systemEmailAddress>system@nexus.org<\/systemEmailAddress>/<systemEmailAddress>${SYSTEM_EMAIL}<\/systemEmailAddress>/g" ${NEXUS_HOME}/conf/nexus.xml
       echo "$(date) - Change SMTP Setting: ${SMTP_HOST}:${SMTP_PORT:-25}"
fi

# Change users Email
if [ -n "${ADMIN_EMAIL}" ]
       then
       # change admin email
       sed -i "s/changeme@yourcompany.com/${ADMIN_EMAIL}/g" ${NEXUS_HOME}/conf/security.xml
       echo "$(date) - ADMIN_EMAIL: ${ADMIN_EMAIL}"
fi

if [ -n "${ANONYMOUS_EMAIL}" ]
       then
       # change Anonymous email
       sed -i "s/changeme2@yourcompany.com/${ANONYMOUS_EMAIL}/g" ${NEXUS_HOME}/conf/security.xml
       echo "$(date) - ANONYMOUS_EMAIL: ${ANONYMOUS_EMAIL}"
fi

insert_role () {
	ROLE=$1
	ROLE_TYPE=$2
	INSERT_ROLE="<role>\
         \n      <id>${ROLE}</id>\
         \n      <name>${ROLE}</name>\
         \n      <roles>\
         \n        <role>nx-${ROLE_TYPE}</role>\
         \n      </roles>\
         \n    </role>"
	if egrep "<id>${ROLE}</id>" ${NEXUS_HOME}/conf/security.xml >/dev/null ; then
		echo "$(date) - Role ${ROLE} already exists, Skipping..."
	else
		echo "$(date) - ${ROLE_TYPE} role added: ${ROLE}"
		sed -i "s+<!--insert-roles-->+<!--insert-roles-->\n    ${INSERT_ROLE}+" ${NEXUS_HOME}/conf/security.xml
	fi
}

if [ "${LDAP_ENABLED}" = true ]
  then
 
  if [[ ${NEXUS_CREATE_CUSTOM_ROLES} == true ]];
    then
    echo "$(date) - Creating custom roles and mappings..."
    [[ -n "${NEXUS_CUSTOM_ADMIN_ROLE}" ]] && insert_role ${NEXUS_CUSTOM_ADMIN_ROLE} admin
    [[ -n "${NEXUS_CUSTOM_DEPLOY_ROLE}" ]] && insert_role ${NEXUS_CUSTOM_DEPLOY_ROLE} deployment
    [[ -n "${NEXUS_CUSTOM_DEV_ROLE}" ]] && insert_role ${NEXUS_CUSTOM_DEV_ROLE} developer
  fi
  
  #echo "$(date) - Disabling default XMLauth..."
  # Delete default authentication realms (XMLauth..) from Nexus if LDAP auth is enabled
  # If you get locked out of nexus, restart nexus with LDAP_ENABLED=false.
  #   - To allow user role mapping need to allow xml authorization
  #sed -i "/XmlAuthenticatingRealm/d"  ${NEXUS_HOME}/conf/security-configuration.xml
  
  # Define the correct LDAP user and group mapping configurations
  LDAP_TYPE=${LDAP_TYPE:-openldap}
  echo "$(date) - LDAP Type: ${LDAP_TYPE}"
 
  case $LDAP_TYPE in
  'openldap')
   LDAP_USER_GROUP_CONFIG="  <userAndGroupConfig>
        <emailAddressAttribute>${LDAP_USER_EMAIL_ATTRIBUTE:-mail}</emailAddressAttribute>
        <ldapGroupsAsRoles>${LDAP_GROUPS_AS_ROLES:-true}</ldapGroupsAsRoles>
        <groupBaseDn>${LDAP_GROUP_BASE_DN}</groupBaseDn>
        <groupIdAttribute>${LDAP_GROUP_ID_ATTRIBUTE:-cn}</groupIdAttribute>
        <groupMemberAttribute>${LDAP_GROUP_MEMBER_ATTRIBUTE-uniqueMember}</groupMemberAttribute>
        <groupMemberFormat>\${${LDAP_GROUP_MEMBER_FORMAT:-dn}}</groupMemberFormat>
        <groupObjectClass>${LDAP_GROUP_OBJECT_CLASS:-groupOfUniqueNames}</groupObjectClass>
        <preferredPasswordEncoding>${LDAP_PREFERRED_PASSWORD_ENCODING:-crypt}</preferredPasswordEncoding>
        <userIdAttribute>${LDAP_USER_ID_ATTRIBUTE:-uid}</userIdAttribute>
        <userPasswordAttribute>${LDAP_USER_PASSWORD_ATTRIBUTE:-password}</userPasswordAttribute>
        <userObjectClass>${LDAP_USER_OBJECT_CLASS:-inetOrgPerson}</userObjectClass>
        <userBaseDn>${LDAP_USER_BASE_DN}</userBaseDn>
        <userRealNameAttribute>${LDAP_USER_REAL_NAME_ATTRIBUTE:-cn}</userRealNameAttribute>
        <userSubtree>${LDAP_USER_SUBTREE:-false}</userSubtree>
        <groupSubtree>${LDAP_GROUP_SUBTREE:-false}</groupSubtree>
      </userAndGroupConfig>"
  ;;

  'active_directory')
   LDAP_USER_GROUP_CONFIG="  <userAndGroupConfig>
        <emailAddressAttribute>${LDAP_USER_EMAIL_ATTRIBUTE:-mail}</emailAddressAttribute>
        <ldapGroupsAsRoles>${LDAP_GROUPS_AS_ROLES:-true}</ldapGroupsAsRoles>
	<groupBaseDn>${LDAP_GROUP_BASE_DN}</groupBaseDn>
        <groupIdAttribute>${LDAP_GROUP_ID_ATTRIBUTE:-cn}</groupIdAttribute>
        <groupMemberAttribute>${LDAP_GROUP_MEMBER_ATTRIBUTE-uniqueMember}</groupMemberAttribute>
        <groupMemberFormat>\${${LDAP_GROUP_MEMBER_FORMAT:-dn}}</groupMemberFormat>
        <groupObjectClass>${LDAP_GROUP_OBJECT_CLASS:-groups}</groupObjectClass>
        <userIdAttribute>${LDAP_USER_ID_ATTRIBUTE:-sAMAccountName}</userIdAttribute>
        <userObjectClass>${LDAP_USER_OBJECT_CLASS:-person}</userObjectClass>
        <userBaseDn>${LDAP_USER_BASE_DN}</userBaseDn>
        <userRealNameAttribute>${LDAP_USER_REAL_NAME_ATTRIBUTE:-cn}</userRealNameAttribute>
      </userAndGroupConfig>"
   ;;
  *)
   echo "Unsupported LDAP_TYPE - ${LDAP_TYPE}. Only supports openldap or active_directory."
   exit 1
   ;;
  esac
 
cat > ${NEXUS_HOME}/conf/ldap.xml <<- EOM
<?xml version="1.0" encoding="UTF-8"?>
<ldapConfiguration>
  <version>2.8.0</version>
  <connectionInfo>
    <searchBase>${LDAP_SEARCH_BASE}</searchBase>
    <systemUsername>${LDAP_BIND_DN}</systemUsername>
    <systemPassword>${LDAP_BIND_PASSWORD}</systemPassword>
    <authScheme>simple</authScheme>
    <protocol>${LDAP_AUTH_PROTOCOL:-ldap}</protocol>
    <host>${LDAP_URL}</host>
    <port>${LDAP_PORT:-389}</port>
  </connectionInfo>
${LDAP_USER_GROUP_CONFIG}
</ldapConfiguration>
EOM

else
    # Delete LDAP realm
    sed -i "/LdapAuthenticatingRealm/d" ${NEXUS_HOME}/conf/security-configuration.xml
fi
 
# chown the nexus home directory
chown nexus:nexus "${NEXUS_HOME}"
chown -R nexus:nexus $(ls ${NEXUS_HOME} | awk -v NEXUS_HOME="${NEXUS_HOME}/" '{if($1 != "storage"){ print NEXUS_HOME$1 }}')
 
exec "$@"
