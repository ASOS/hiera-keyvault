
## Installation

The module requires `rest-client` so in order to install you need to run the following to cover the requirement manually for now

    yum install gcc-g++
    /opt/puppetlabs/puppet/bin/gem install rest-client

## Configuration

The following hiera.yaml should get you started:

    version: 5
    hierarchy:
      - name: "Azure Key Vault secrets"
        lookup_key: hiera_keyvault
        options:
          vaults:
            VaultTest:
              vault: VaultName
              client: Client ID
              client_secret: Client Secret
              tenant: Tenant ID

You need to give the parameters VaultName, Client ID, Client Secret and Tenant ID with the right values
You can add more than one Vault and hiera_keyvault will go through them until it finds the secret

## Querying secrets

Any secret to query needs to use the `lookup` function and start with `keyvault::`.
Have in mind that any double colon separator `::` will be transformed to `-`, as an example `keyvault::ssh::active` would become `ssh_active` under keyvault.

Example:

    $needed_certificate = lookup('keyvault::mycertificate')
