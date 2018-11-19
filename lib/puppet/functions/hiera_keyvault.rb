# Hiera backend for keyvault
Puppet::Functions.create_function(:hiera_keyvault) do

  # Load modules
  begin
    require "rest-client"
  rescue LoadError => e
    raise Puppet::DataBinding::LookupError, "[hiera-keyvault] Must install rest-client gem to use hiera-keyvault backend - #{e}"
  end
  begin
    require "json"
  rescue LoadError => e
    raise Puppet::DataBinding::LookupError, "[hiera-keyvault] Must install json gem to use hiera-keyvault backend - #{e}"
  end

  dispatch :lookup_key do
    param 'Variant[String, Numeric]', :key
    param 'Hash', :options
    param 'Puppet::LookupContext', :context
  end

  def lookup_key(key, options, context)
    # Go through checks and ensure at least one valid vault before we start any operations
    # in hiera.yaml we'll have a keyvault section with a vaults subsection with all the valid vaults to connect to
    # if there is no valid vaults the boolean one_good_vault will flag and it'll result in a hard error
    if (options['vaults'])
      one_good_vault = false
      options['vaults'].each do |vault_name, vault_config|
        if (vault_config['vault'] && vault_config['tenant'] && vault_config['client'] && vault_config['client_secret'])
          one_good_vault = true
        else
          context.explain { "[hiera-keyvault]: Vault #{vault_name} has an invalid configuration" }
        end
      end
      unless one_good_vault
        raise ArgumentError, "[hiera-keyvault]: Missing minimum vault configuration as no valid vaults found, please check hiera.yaml"
      end
    else
      raise ArgumentError, "[hiera-keyvault]: Missing minimum vault location configuration, vaults key is not present, please check hiera.yaml"
    end
    # Look for the entry in keyvault, any valid entries will start with "keyvault::" followed by the secret itself
    unless key.start_with?("keyvault::")
      context.not_found
    end
    # Look through all keyvaults
    options['vaults'].each do |vault_name, vault_config|
      # Vault URL https://#{@vault_name}.vault.azure.net/secrets/%{secret_name}
      # Remove vault.azure.net if user adds that by mistake
      vault_name = vault_config['vault'].sub(/.vault.azure.net$/, "")
      real_key = key.sub(/^keyvault::/, "").sub(/::/, "-")
      # Authenticate
      bearer_token = auth(context, vault_config['tenant'], vault_config['client'], vault_config['client_secret'])
      # Recover secret
      begin
        vault_answer = http_query("https://#{vault_name}.vault.azure.net/secrets/#{real_key}?api-version=2016-10-01", context, headers: {Authorization: bearer_token})
        context.explain { "[hiera-keyvault]: Returned #{vault_answer}" }
        unless vault_answer.nil?
          if vault_answer['attributes']['enabled']
            # Type casting - Boolean
            if vault_answer['value'] == 'true'
              return true
            elsif vault_answer['value'] == 'false'
              return false
            end
            # Type casting - Integer
            if /\A[-+]?\d+\z/ === vault_answer['value']
              return vault_answer['value'].to_i
            end
            # Type casting - String
            return vault_answer['value']
          else
            return context.not_found
          end
        end
      rescue RestClient::NotFound
        return context.not_found
      rescue => e
        raise Puppet::DataBinding::LookupError, "[hiera-keyvault] Keyvault search failed with error - #{e}"
      end
    end
    # Return not found if we can't find any keys
    return context.not_found
  end

  private

  def auth(context, tenant, client, client_secret)
    if (tenant && client && client_secret)
      # Login and get bearer token
      # Auth URL "https://login.windows.net/#{@tenant_id}/oauth2/token"
      # Auth body {"grant_type" => "client_credentials", "client_id" => client_id, "client_secret" => client_secret, "resource" => 'https://vault.azure.net'}
      form_data = {"grant_type" => "client_credentials", "client_id" => client, "client_secret" => client_secret, "resource" => 'https://vault.azure.net'}
      begin
        bearer_token = http_query("https://login.windows.net/#{tenant}/oauth2/token", context, method: "post", form_data: form_data)
      rescue => e
        raise Puppet::DataBinding::LookupError, "[hiera-keyvault] Authentication failed - #{e}"
      end
      return "Bearer #{bearer_token['access_token']}"
    else
      raise Puppet::DataBinding::LookupError, "[hiera-keyvault]: Cannot connect to auth server, missing credentials"
    end
  end

  def http_query(request_url, context, method: 'get', headers: {}, form_data: {}, json: true)
    answer = nil
    # URL encoded
    url = URI.encode(request_url)
    # Get method and create request accordingly
    begin
      if method == 'get'
        request = RestClient::Request.execute(url: url, method: :get, headers: headers, verify_ssl: true, open_timeout: 10)
      elsif method == 'post'
        request = RestClient::Request.execute(url: url, method: :post, payload: form_data, headers: headers, verify_ssl: true, open_timeout: 10)
      else
        raise Puppet::DataBinding::LookupError, "[hiera-keyvault]: No valid method found (#{method}), this should never happen"
      end
      if json
        answer = JSON.parse(request.body)
      else
        answer = request.body
      end
      return answer
    rescue => e
      unless e.response.headers.nil?
        raise "Request failed with error #{e} - #{e.response.headers}"
      else
        raise "Request failed with error #{e} - #{e.response}"
      end
    end
    # Request result
  end

end
