import com.cloudbees.jenkins.plugins.awscredentials.AWSCredentialsImpl

def changeAwsKeys = { cred_id, access_key, secret_key ->
    def creds = com.cloudbees.plugins.credentials.CredentialsProvider.lookupCredentials(
        com.cloudbees.plugins.credentials.common.StandardCredentials.class,
        Jenkins.instance
    )

    def c = creds.findResult { it.id == cred_id ? it : null }

    if ( c ) {
        println "found credential ${c.id}"

        def credentials_store = Jenkins.instance.getExtensionList(
            'com.cloudbees.plugins.credentials.SystemCredentialsProvider'
            )[0].getStore()

        def result = credentials_store.updateCredentials(
            com.cloudbees.plugins.credentials.domains.Domain.global(),
            c,
            new com.cloudbees.jenkins.plugins.awscredentials.AWSCredentialsImpl(c.scope, c.id, access_key, secret_key, c.description)
            )

        if (result) {
            println "password changed for ${cred_id}"
        } else {
            println "failed to change password for ${cred_id}"
        }
    } else {
      println "could not find credential for ${cred_id}"
    }
}

changeAwsKeys('aws_credential_id_here', 'access_key', 'secret_key')
