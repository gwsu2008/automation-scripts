import jenkins.model.*
import com.cloudbees.plugins.credentials.*
import com.cloudbees.plugins.credentials.common.*
import com.cloudbees.plugins.credentials.domains.*
import com.cloudbees.plugins.credentials.impl.*
import org.jenkinsci.plugins.plaincredentials.*
import org.jenkinsci.plugins.plaincredentials.impl.*
import hudson.util.Secret
def changeAwsKeys = { cred_id, access_key, secret_key ->
    def creds = com.cloudbees.plugins.credentials.CredentialsProvider.lookupCredentials(
        com.cloudbees.plugins.credentials.common.StandardCredentials.class,
        Jenkins.instance
    )
    def c = creds.findResult { it.id == cred_id ? it : null }
    if ( c ) {
        println "Found credential ${cred_id}"
        def credentials_store = Jenkins.instance.getExtensionList(
            'com.cloudbees.plugins.credentials.SystemCredentialsProvider'
            )[0].getStore()
        def result = credentials_store.updateCredentials(
            com.cloudbees.plugins.credentials.domains.Domain.global(),
            c,
            new StringCredentialsImpl(CredentialsScope.GLOBAL, access_key, c.description, Secret.fromString(secret_key))
            )
        if (result) {
            println "AWS access and secret key changed for ${cred_id}"
        } else {
            println "Failed to change AWS access and secret key for ${cred_id}"
        }
    } else {
      println "Could not find credential for ${cred_id}"
    }
}
changeAwsKeys('gsu-secret-test', 'access1', 'secret1')
