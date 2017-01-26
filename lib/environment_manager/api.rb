# Copyright (c) Trainline Limited, 2016. All rights reserved. See LICENSE.txt in the project root for license information.
# vim: tabstop=4 expandtab shiftwidth=4 softtabstop=4

require 'rest-client'
require 'json'

module EnvironmentManager
  class Api

    def initialize(server, user, password, retries=5)
      # Instantiate variables
      @server = server
      @user = user
      @password = password
      @retries = retries
      # Sanitise input
      if server.empty? or user.empty? or password.empty?
        raise(IndexError, 'API(server: SERVERNAME, user: USERNAME, password: PASSWORD, [retries: N])')
      end
    end

    private
    def api_auth()
      # Authenticate in environment manager
      base_url = "https://#{@server}"
      token_payload = {grant_type: "password",
                       username: @user,
                       password: @password}
      token = nil
      no_token = true
      retries = 0
      while no_token and retries < @retries
        em_token_url = "#{base_url}/api/token"
        begin
          em_token = RestClient::Request.execute(url: em_token_url, method: :post, payload: token_payload, verify_ssl: false, open_timeout: 10)
          if em_token.code == 200
            token = em_token.body
            no_token = false
          else
            sleep 2
          end
        rescue
          sleep 2
        end
        retries += 1
      end
      if not token.to_s.strip.empty?
        token_bearer = "Bearer #{token}"
        return token_bearer
      else
        raise("No token returned from Environment Manager")
      end
    end

    private
    def query(query_endpoint, data=nil, query_type='get', retries=5, backoff=2)
      # Query environment manager

      # Sanitise input
      if query_endpoint.to_s.strip.empty? or data.to_s.strip.empty?
        raise("No endpoint specified, cannot continue")
      end
      if query_endpoint.downcase == 'post' or query_endpoint.downcase == 'put'
        if data.nil?
          raise("We need data for this method but nothing was specified")
        end
      end
      retry_num = 0
      while retry_num < retries
        retry_num += 1
        token = api_auth()
        base_url = "https://#{@server}"
        request_url = "#{base_url}#{query_endpoint}"
        query_headers = {'Accept': 'application/json', 'Content-Type': 'application/json', 'Authorization': token}
        if query_type.downcase == 'get'
          request = RestClient::Request.execute(url: request_url, method: :get, headers: query_headers, verify_ssl: false, open_timeout: 10)
        elsif query_type.downcase == 'post'
          request = RestClient::Request.execute(url: request_url, method: :post, payload: data, headers: query_headers, verify_ssl: false, open_timeout: 10)
        elsif query_type.downcase == 'put'
          request = RestClient::Request.execute(url: request_url, method: :put, payload: data, headers: query_headers, verify_ssl: false, open_timeout: 10)
        elsif query_type.downcase == 'delete'
          request = RestClient::Request.execute(url: request_url, method: :delete, headers: query_headers, verify_ssl: false, open_timeout: 10)
        else
          raise("Cannot process query type #{query_type}")
        end
        if request.code == 200
          return JSON.parse(request.body)
        elsif request.code == 401
          next
        elsif request.code == 404
          raise("404: Object not found")
        else
          sleep backoff
        end
      end
      raise("Max number of retries (#{retry_num}) querying Environment Manager, last http code is #{request.code}, will abort for now")
    end

    ##########################
    # Public API methods
    ##########################

    ## Accounts
    public
    def get_accounts_config()
      # Get config of accounts associated with EM
      request_endpoint = "/api/v1/config/accounts"
      return query(request_endpoint, query_type: "GET")
    end

    ## AMI
    public
    def get_images_config(account=nil)
      # Get config of AMI images registered in EM
      if account.nil?
        account_qs = ""
      else
        account_qs = "?account=#{account}"
      end
      request_endpoint = "/api/v1/config/images#{account_qs}"
      return query(request_endpoint, query_type: "GET")
    end

    ## ASG
    public
    def get_asgs(account="Non-Prod")
      # Get list of ASGs from EM
      request_endpoint = "/api/v1/asgs?account=#{account}"
      return query(request_endpoint, query_type: "GET")
    end

    public
    def get_asg_info(environment=nil, asgname=nil)
      # Get details from ASG
      if environment.nil? or asgname.nil?
        raise("Either environment or asgname has not been specified")
      end
      request_endpoint = "/api/v1/asgs/#{asgname}?environment=#{environment}"
      return query(request_endpoint, query_type: "GET")
    end

    public
    def get_asg_ready(environment=nil, asgname=nil)
      # Get details from ASG
      if environment.nil? or asgname.nil?
        raise("Either environment or asgname has not been specified")
      end
      request_endpoint = "/api/v1/asgs/#{asgname}/ready?environment=#{environment}"
      return query(request_endpoint, query_type: "GET")
    end

    public
    def get_asg_ips(environment=nil, asgname=nil)
      # Get IPs associated with ASG
      if environment.nil? or asgname.nil?
        raise("Either environment or asgname has not been specified")
      end
      request_endpoint = "/api/v1/asgs/#{asgname}/ips?environment=#{environment}"
      return query(request_endpoint, query_type: "GET")
    end

    public
    def get_asg_scaling_schedule(environment=nil, asgname=nil)
      # Get scaling schedule associated with ASG
      if environment.nil? or asgname.nil?
        raise("Either environment or asgname has not been specified")
      end
      request_endpoint = "/api/v1/asgs/#{asgname}/scaling-schedule?environment=#{environment}"
      return query(request_endpoint, query_type: "GET")
    end

    public
    def get_asg_launch_config(environment=nil, asgname=nil)
      # Get scaling schedule associated with ASG
      if environment.nil? or asgname.nil?
        raise("Either environment or asgname has not been specified")
      end
      request_endpoint = "/api/v1/asgs/#{asgname}/launch-config?environment=#{environment}"
      return query(request_endpoint, query_type: "GET")
    end

    ## Audit
    public
    def get_audit_config(since_date=nil, until_date=nil)
      # Get audit config from EM
      if not since_date.nil?
        since_date_qs = "since_date=#{since_date}"
      end
      if not until_date.nil?
        until_date_qs = "until=#{until_date}"
      end
      # Construct qs
      if since_date.nil? and not until_date.nil?
        constructed_qs = "?#{until_date_qs}"
      elsif not since_date.nil? and until_date.nil?
        constructed_qs = "?#{since_date_qs}"
      elsif not since_date.nil? and not until_date.nil?
        constructed_qs = "?#{since_date_qs},#{until_date_qs}"
      else
        constructed_qs = ""
      end
      request_endpoint = "/api/v1/config/audit#{constructed_qs}"
      return query(request_endpoint, query_type: "GET")
    end

    public
    def get_audit_key_config(key=nil)
      # Get audit config for specific key
      if key.nil?
        raise("Key has not been specified")
      end
      request_endpoint = "/api/v1/config/audit/#{key}"
      return query(request_endpoint, query_type: "GET")
    end

    ## Cluster
    public
    def get_clusters_config()
      # Get config of clusters (teams) registered in EM
      request_endpoint = "/api/v1/config/clusters"
      return query(request_endpoint, query_type: "GET")
    end

    public
    def get_cluster_config(cluster=nil)
      # Get EM config for cluster (team)
      if cluster.nil?
        raise("Cluster name has not been specified")
      end
      request_endpoint = "/api/v1/config/clusters/#{cluster}"
      return query(request_endpoint, query_type: "GET")
    end

    ## Deployment
    public
    def get_deployments()
      # Get list of deployments registered in EM
      request_endpoint = "/api/v1/deployments"
      return query(request_endpoint, query_type: "GET")
    end

    public
    def get_deployment(deployment_id=nil)
      # Get deployment information for one deployment
      if deployment_id.nil?
        raise("Deployment id has not been specified")
      end
      request_endpoint = "/api/v1/deployments/#{deployment_id}"
      return query(request_endpoint, query_type: "GET")
    end

    public
    def get_deployment_log(deployment_id=nil, account="Non-Prod", instance=nil)
      # Get deployment log for one deployment
      if deployment_id.nil?
        raise("Deployment id has not been specified")
      end
      if instance.nil?
        raise("Instance id has not been specified")
      end
      request_endpoint = "/api/v1/deployments/#{deployment_id}/log?account=#{account},instance=#{instance}"
      return query(request_endpoint, query_type: "GET")
    end

    ## Deployment Map
    public
    def get_deployment_maps()
      # Get list of deployments maps in EM
      request_endpoint = "/api/v1/config/deployments-maps"
      return query(request_endpoint, query_type: "GET")
    end

    public
    def get_deployment_map(deployment_name=nil)
      # Get deployment map config for one deployment
      if deployment_name.nil?
        raise("Deployment name has not been specified")
      end
      request_endpoint = "/api/v1/deployment-maps/#{deployment_name}"
      return query(request_endpoint, query_type: "GET")
    end

    ## Environment
    public
    def get_environments()
      # Get list of environments available in EM
      request_endpoint = "/api/v1/environments"
      return query(request_endpoint, query_type: "GET")
    end

    public
    def get_environment(environment=nil)
      # Get config for environment
      if environment.nil?
        raise("Environment has not been specified")
      end
      request_endpoint = "/api/v1/environments/#{environment}"
      return query(request_endpoint, query_type: "GET")
    end

    public
    def get_environment_servers(environment=nil)
      # Get list of servers in environment
      if environment.nil?
        raise("Environment has not been specified")
      end
      request_endpoint = "/api/v1/environments/#{environment}/servers"
      return query(request_endpoint, query_type: "GET")
    end

    public
    def get_environment_asg_servers(environment=nil, asgname=nil)
      # Get list of servers belonging to an environment ASG
      if environment.nil? or asgname.nil?
        raise("Either environment or asgname has not been specified")
      end
      request_endpoint = "/api/v1/environments/#{environment}/servers/#{asgname}"
      return query(request_endpoint, query_type: "GET")
    end

    public
    def get_environment_schedule(environment=nil)
      # Get schedule for environment
      if environment.nil?
        raise("Environment has not been specified")
      end
      request_endpoint = "/api/v1/environments/#{environment}/schedule"
      return query(request_endpoint, query_type: "GET")
    end

    public
    def get_environment_account_name(environment=nil)
      # Get account name for environment
      if environment.nil?
        raise("Environment has not been specified")
      end
      request_endpoint = "/api/v1/environments/#{environment}/accountName"
      return query(request_endpoint, query_type: "GET")
    end

    public
    def get_environment_schedule_status(environment=nil, at_time=nil)
      # Get schedule status for environment
      if environment.nil?
        raise("Environment has not been specified")
      end
      if at_time.nil?
        at_qs = ""
      else
        at_qs = "?at=#{at_time}"
      end
      request_endpoint = "/api/v1/environments/#{environment}/schedule-status#{at_qs}"
      return query(request_endpoint, query_type: "GET")
    end

    public
    def get_environments_config(environmenttype=nil, cluster=nil)
      # Get config for all environments
      if not environmenttype.nil?
        environmenttype_qs = "environmentType=#{environmenttype}"
      end
      if not cluster.nil?
        cluster_qs = "cluster=#{cluster}"
      end
      # Construct qs
      if environmenttype.nil? and not cluster.nil?
        constructed_qs = "?#{cluster_qs}"
      elsif not environmenttype.nil? and cluster.nil?
        constructed_qs = "?#{environmenttype_qs}"
      elsif not environmenttype.nil? and not cluster.nil?
        constructed_qs = "?#{environmenttype_qs},#{cluster_qs}"
      else
        constructed_qs = ""
      end
      request_endpoint = "/api/v1/config/environments#{constructed_qs}"
      return query(request_endpoint, query_type: "GET")
    end

    public
    def get_environment_config(environment=nil)
      # Get environment config for specific environment
      if environment.nil?
      raise("Environment has not been specified")
      end
      request_endpoint = "/api/v1/config/environments/#{environment}"
      return query(request_endpoint, query_type: "GET")
    end

    ## Environment Type
    public
    def get_environmenttypes_config()
      # Get config for available environmentTypes in EM
      request_endpoint = "/api/v1/config/environment-types"
      return query(request_endpoint, query_type: "GET")
    end

    public
    def get_environmenttype_config(environmenttype=nil)
      # Get config for one specific environmentType
      if environmenttype.nil?
        raise("Environment type has not been specified")
      end
      request_endpoint = "/api/v1/config/environment-types/#{environmenttype}"
      return query(request_endpoint, query_type: "GET")
    end

    ## Instance
    public
    def get_instances()
      # Get available environmentTypes in EM
      request_endpoint = "/api/v1/instances"
      return query(request_endpoint, query_type: "GET")
    end

    public
    def get_instance(instance_id=nil)
      # Get config for one specific environmentType
      if instance_id.nil?
        raise("Instance id has not been specified")
      end
      request_endpoint = "/api/v1/instances/#{instance_id}"
      return query(request_endpoint, query_type: "GET")
    end

    ## Load Balancers
    public
    def get_lbsettings_config()
      # Get config of Load Balancer Services from EM
      request_endpoint = "/api/v1/config/lb-settings"
      return query(request_endpoint, query_type: "GET")
    end

    public
    def get_lbsettings_vhost_config(environment=nil, vhostname=nil)
      # Get Load Balancer vhostname config
      if environment.nil?
        raise("Environment has not been specified")
      end
      if vhostname.nil?
        raise("Virtual Host Name (vhostname) has not been specified")
      end
      request_endpoint = "/api/v1/config/lb-settings/#{environment}/#{vhostname}"
      return query(request_endpoint, query_type: "GET")
    end

    ## Permissions
    public
    def get_permissions_config()
      # Get permissions config from EM
      request_endpoint = "/api/v1/config/permissions"
      return query(request_endpoint, query_type: "GET")
    end

    public
    def get_permission_config(name=nil)
      # Get specific permission config
      if name.nil?
        raise('Permission name has not been specified')
      end
      request_endpoint = "/api/v1/config/permissions/#{name}"
      return query(request_endpoint, query_type: "GET")
    end

    ## Service
    public
    def get_services()
      # Get list of Services from EM
      request_endpoint = "/api/v1/services"
      return query(request_endpoint, query_type: "GET")
    end

    public
    def get_service(service=nil)
      # Get a currently deployed service
      if service.nil?
        raise("Service has not been specified")
      end
      request_endpoint = "/api/v1/services/#{service}"
      return query(request_endpoint, query_type: "GET")
    end

    public
    def get_service_health(service=nil, environment=nil)
      # Get a currently deployed service
      if service.nil?
        raise("Service has not been specified")
      end
      if environment.nil?
        raise("Environment has not been specified")
      end
      request_endpoint = "/api/v1/services/#{service}/health?environment=#{environment}"
      return query(request_endpoint, query_type: "GET")
    end

    public
    def get_service_slices(service=nil)
      # Get a currently deployed service slices
      if service.nil?
        raise("Service has not been specified")
      end
      request_endpoint = "/api/v1/services/#{service}/slices"
      return query(request_endpoint, query_type: "GET")
    end

    public
    def get_services_config()
      # Get services config from EM
      request_endpoint = "/api/v1/config/services"
      return query(request_endpoint, query_type: "GET")
    end

    public
    def get_service_config(service=nil, cluster=nil)
      # Get service config for one specific service
      if service.nil?
        raise("Service has not been specified")
      end
      if cluster.nil?
        raise("Cluster name (team) has not been specified")
      end
      request_endpoint = "/api/v1/config/services/#{service}/#{cluster}"
      return query(request_endpoint, query_type: "GET")
    end

    ## Status
    public
    def get_status()
      # Get internal status of EM
      request_endpoint = "/api/v1/diagnostics/healthcheck"
      return query(request_endpoint, query_type: "GET")
    end

    ## Target State
    public
    def get_target_state(environment=nil)
      # Get target state for specific environment
      if environment.nil?
        raise("Environment has not been specified")
      end
      request_endpoint = "/api/v1/target-state/#{environment}"
      return query(request_endpoint, query_type: "GET")
    end

    ## Upstream
    public
    def get_upstream_slices(upstream=nil)
      # Get slices attached to upstream
      if upstream.nil?
        raise("Upstream name has not been specified")
      end
      request_endpoint = "/api/v1/upstreams/#{upstream}/slices"
      return query(request_endpoint, query_type: "GET")
    end

    public
    def get_upstreams_config()
      # Get config for Upstreams from EM
      request_endpoint = "/api/v1/config/upstreams"
      return query(request_endpoint, query_type: "GET")
    end

    def get_upstream_config(upstream=nil, account="Non-Prod")
      # Get config for specific upstream
      if upstream.nil?
        raise("Upstream name has not been specified")
      end
      request_endpoint = "/api/v1/config/upstreams/#{upstream}?account=#{account}"
      return query(request_endpoint, query_type: "GET")
    end

  end
end
