# Copyright (c) Trainline Limited, 2017. All rights reserved. See LICENSE.txt in the project root for license information.
# vim: tabstop=4 expandtab shiftwidth=4 softtabstop=4

require "rest-client"
require "json"

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
        raise(IndexError, "API(server: SERVERNAME, user: USERNAME, password: PASSWORD, [retries: N])")
      end
    end

    private
    def api_auth()
      # Authenticate in environment manager
      base_url = "https://#{@server}"
      token_payload = {username: @user,
                       password: @password}
      token = nil
      no_token = true
      retries = 0
      while no_token and retries < @retries
        em_token_url = "#{base_url}/api/v1/token"
        headers = {"Accept" => "application/json", "Content-Type" => "application/json"}
        begin
          em_token = RestClient::Request.execute(url: em_token_url, method: :post, payload: JSON.generate(token_payload), headers: headers, verify_ssl: false, open_timeout: 10)
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
    def query(query_endpoint, data=nil, query_type="get", headers={}, retries=5, backoff=2)
      # Sanitise input
      if query_endpoint.to_s.strip.empty? or data.to_s.strip.empty?
        raise("No endpoint specified, cannot continue")
      end
      if query_endpoint.downcase == "post"
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
        query_headers = {"Accept" => "application/json", "Content-Type" => "application/json", "Authorization" => token}
        headers.each do |header|
          query_headers.merge!(header)
        end
        # Add any extra headers
        if query_type.downcase == "get"
          request = RestClient::Request.execute(url: request_url, method: :get, headers: query_headers, verify_ssl: false, open_timeout: 10)
        elsif query_type.downcase == "post"
          request = RestClient::Request.execute(url: request_url, method: :post, payload: data, headers: query_headers, verify_ssl: false, open_timeout: 10)
        elsif query_type.downcase == "put"
          request = RestClient::Request.execute(url: request_url, method: :put, payload: data, headers: query_headers, verify_ssl: false, open_timeout: 10)
        elsif query_type.downcase == "patch"
          request = RestClient::Request.execute(url: request_url, method: :patch, payload: data, headers: query_headers, verify_ssl: false, open_timeout: 10)
        elsif query_type.downcase == "delete"
          request = RestClient::Request.execute(url: request_url, method: :delete, headers: query_headers, verify_ssl: false, open_timeout: 10)
        else
          raise("Cannot process query type #{query_type}")
        end
        if request.code.to_s[0].to_i == 2
          return JSON.parse(request.body)
        elsif request.code.to_s[0].to_i == 2 or request.code.to_s[0].to_i == 5
          raise(request)
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
      # List the AWS Accounts that associated with Environment Manager
      request_endpoint = "/api/v1/config/accounts"
      return query(request_endpoint, query_type: "GET")
    end

    public
    def post_accounts_config(data=Hash.new)
      # Add an association to an AWS Account
      request_endpoint = "/api/v1/config/accounts"
      return query(request_endpoint, query_type: "POST", data: data)
    end

    public
    def put_account_config(accountnumber=nil, data=Hash.new)
      # Update an associated AWS Account
      if accountnumber.nil?
        raise("acountnumber has not been specified")
      end
      request_endpoint = "/api/v1/config/accounts/#{accountnumber}"
      return query(request_endpoint, query_type: "PUT", data: data)
    end

    public
    def delete_account_config(accountnumber=nil)
      # Remove an AWS Account association
      if accountnumber.nil?
        raise("Required value has not been specified")
      end
      request_endpoint = "/api/v1/config/accounts/#{accountnumber}"
      return query(request_endpoint, query_type: "DELETE")
    end

    ## AMI
    public
    def get_images(account=nil)
      # Get the list of available AMI images. Only those that are privately published under associated accounts are included
      if account.nil?
        account_qs = ""
      else
        account_qs = "?account=#{account}"
      end
      request_endpoint = "/api/v1/images#{account_qs}"
      return query(request_endpoint, query_type: "GET")
    end

    ## ASG
    public
    def get_asgs(account="Non-Prod")
      # List ASGS matching the given criteria. By default returns all ASGs across all accounts
      request_endpoint = "/api/v1/asgs?account=#{account}"
      return query(request_endpoint, query_type: "GET")
    end

    public
    def get_asg(environment=nil, asgname=nil)
      # Get a single ASG for the given environment
      if environment.nil? or asgname.nil?
        raise("Either environment or asgname has not been specified")
      end
      request_endpoint = "/api/v1/asgs/#{asgname}?environment=#{environment}"
      return query(request_endpoint, query_type: "GET")
    end

    public
    def put_asg(environment=nil, asgname=nil, data=Hash.new)
      # Update properties of an ASG
      if environment.nil? or asgname.nil?
        raise("Either environment or asgname has not been specified")
      end
      request_endpoint = "/api/v1/asgs/#{asgname}?environment=#{environment}"
      return query(request_endpoint, query_type: "PUT", data: data)
    end

    public
    def delete_asg(environment=nil, asgname=nil)
      # Delete ASG and it"s target state
      if environment.nil? or asgname.nil?
        raise("Either environment or asgname has not been specified")
      end
      request_endpoint = "/api/v1/asgs/#{asgname}?environment=#{environment}"
      return query(request_endpoint, query_type: "DELETE")
    end

    public
    def get_asg_ready(environment=nil, asgname=nil)
      # Determine if an ASG is ready to deploy to, eg. at least one instance is present and all are "InService"
      if environment.nil? or asgname.nil?
        raise("Either environment or asgname has not been specified")
      end
      request_endpoint = "/api/v1/asgs/#{asgname}/ready?environment=#{environment}"
      return query(request_endpoint, query_type: "GET")
    end

    public
    def get_asg_ips(environment=nil, asgname=nil)
      # Get IPs associated with an ASG in the given environment
      if environment.nil? or asgname.nil?
        raise("Either environment or asgname has not been specified")
      end
      request_endpoint = "/api/v1/asgs/#{asgname}/ips?environment=#{environment}"
      return query(request_endpoint, query_type: "GET")
    end

    public
    def get_asg_scaling_schedule(environment=nil, asgname=nil)
      # Get scaling schedule actions for given ASG
      if environment.nil? or asgname.nil?
        raise("Either environment or asgname has not been specified")
      end
      request_endpoint = "/api/v1/asgs/#{asgname}/scaling-schedule?environment=#{environment}"
      return query(request_endpoint, query_type: "GET")
    end

    public
    def put_asg_scaling_schedule(environment=nil, asgname=nil, data=Hash.new)
      # Update scaling schedule actions for given ASG
      if environment.nil? or asgname.nil?
        raise("Either environment or asgname has not been specified")
      end
      request_endpoint = "/api/v1/asgs/#{asgname}/scaling-schedule?environment=#{environment}"
      return query(request_endpoint, query_type: "PUT", data: data)
    end

    public
    def put_asg_size(environment=nil, asgname=nil, data=Hash.new)
      # Resize an ASG in the given environment
      if environment.nil? or asgname.nil?
        raise("Either environment or asgname has not been specified")
      end
      request_endpoint = "/api/v1/asgs/#{asgname}/size?environment=#{environment}"
      return query(request_endpoint, query_type: "PUT", data: data)
    end

    public
    def get_asg_launch_config(environment=nil, asgname=nil)
      # Get the launch config associated with an ASG in the given environment
      if environment.nil? or asgname.nil?
        raise("Either environment or asgname has not been specified")
      end
      request_endpoint = "/api/v1/asgs/#{asgname}/launch-config?environment=#{environment}"
      return query(request_endpoint, query_type: "GET")
    end

    public
    def put_asg_launch_config(environment=nil, asgname=nil, data=Hash.new)
      # Update the launch config associated with an ASG in the given environment
      if environment.nil? or asgname.nil?
        raise("Either environment or asgname has not been specified")
      end
      request_endpoint = "/api/v1/asgs/#{asgname}/launch-config?environment=#{environment}"
      return query(request_endpoint, query_type: "PUT", data: data)
    end

    ## Audit
    public
    def get_audit_config(since_time=nil, until_time=nil)
      # Get Audit Logs for a given time period. Default values are "since yesterday" and "until now"
      if since_time.nil?
        since_time_qs = ""
      else
        since_time_qs = "since=#{since_time}"
      end
      if until_time.nil?
        until_time_qs = ""
      else
        until_time_qs = "until=#{until_time}"
      end
      # Construct qs
      if since_time.nil? and not until_time.nil?
        constructed_qs = "?#{until_time_qs}"
      elsif not since_time.nil? and until_time.nil?
        constructed_qs = "?#{since_time_qs}"
      elsif not since_time.nil? and not until_time.nil?
        constructed_qs = "?#{since_time_qs}&#{until_qs}"
      else
        constructed_qs = ""
      end
      request_endpoint = "/api/v1/config/audit#{constructed_qs}"
      return query(request_endpoint, query_type: "GET")
    end

    public
    def get_audit_key_config(key=nil)
      # Get a specific audit log
      if key.nil?
        raise("Key has not been specified")
      end
      request_endpoint = "/api/v1/config/audit/#{key}"
      return query(request_endpoint, query_type: "GET")
    end

    ## Cluster
    public
    def get_clusters_config()
      # Get all Cluster configurations
      request_endpoint = "/api/v1/config/clusters"
      return query(request_endpoint, query_type: "GET")
    end

    public
    def post_clusters_config(data=Hash.new)
      # Create a Cluster configuration
      request_endpoint = "/api/v1/config/clusters"
      return query(request_endpoint, query_type: "POST", data: data)
    end

    public
    def get_cluster_config(cluster=nil)
      # Get a specific Cluster configuration
      if cluster.nil?
        raise("Cluster name has not been specified")
      end
      request_endpoint = "/api/v1/config/clusters/#{cluster}"
      return query(request_endpoint, query_type: "GET")
    end

    public
    def put_cluster_config(cluster=nil, data=Hash.new)
      # Update a Cluster configuration
      if cluster.nil?
        raise("Cluster name has not been specified")
      end
      request_endpoint = "/api/v1/config/clusters/#{cluster}"
      return query(request_endpoint, query_type: "PUT", data: data)
    end

    public
    def delete_cluster_config(cluster=nil)
      # Delete a Cluster configuration
      if cluster.nil?
        raise("Cluster name has not been specified")
      end
      request_endpoint = "/api/v1/config/clusters/#{cluster}"
      return query(request_endpoint, query_type: "DELETE")
    end

    ## Deployment
    public
    def get_deployments()
      # List all deployments matching the given criteria. If no parameters are provided, the default is "since yesterday"
      request_endpoint = "/api/v1/deployments"
      return query(request_endpoint, query_type: "GET")
    end

    public
    def post_deployments(dry_run=False, data=Hash.new)
      # Create a new deployment. This will provision any required infrastructure and update the required target-state
      request_endpoint = "/api/v1/deployments?dry_run=#{dry_run}"
      return query(request_endpoint, query_type: "POST", data: data)
    end

    public
    def get_deployment(deployment_id=nil)
      # Get information for a deployment
      if deployment_id.nil?
        raise("Deployment id has not been specified")
      end
      request_endpoint = "/api/v1/deployments/#{deployment_id}"
      return query(request_endpoint, query_type: "GET")
    end

    public
    def patch_deployment(deployment_id=nil, data=Hash.new)
      # Modify deployment - cancel in-progress, or modify Action
      if deployment_id.nil?
        raise("Deployment id has not been specified")
      end
      request_endpoint = "/api/v1/deployments/#{deployment_id}"
      return query(request_endpoint, query_type: "PATCH", data: data)
    end

    public
    def get_deployment_log(deployment_id=nil, account="Non-Prod", instance=nil)
      # Retrieve logs for a particular deployment
      if deployment_id.nil?
        raise("Deployment id has not been specified")
      end
      if instance.nil?
        raise("Instance id has not been specified")
      end
      request_endpoint = "/api/v1/deployments/#{deployment_id}/log?account=#{account}&instance=#{instance}"
      return query(request_endpoint, query_type: "GET")
    end

    ## Deployment Map
    public
    def get_deployment_maps()
      # Get all deployment map configurations
      request_endpoint = "/api/v1/config/deployments-maps"
      return query(request_endpoint, query_type: "GET")
    end

    public
    def post_deployment_maps(data=Hash.new)
      # Create a deployment map configuration
      request_endpoint = "/api/v1/config/deployments-maps"
      return query(request_endpoint, query_type: "POST", data: data)
    end

    public
    def get_deployment_map(deployment_name=nil)
      # Get a specific deployment map configuration
      if deployment_name.nil?
        raise("Deployment name has not been specified")
      end
      request_endpoint = "/api/v1/deployment-maps/#{deployment_name}"
      return query(request_endpoint, query_type: "GET")
    end

    public
    def put_deployment_map(deployment_name=nil, expected_version=nil, data=Hash.new)
      # Update a deployment map configuration
      if deployment_name.nil?
        raise("Deployment name has not been specified")
      end
      if expected_version.nil?
        headers = ""
      else
        headers = {"expected-version" => expected_version}
      end
      request_endpoint = "/api/v1/deployment-maps/#{deployment_name}"
      return query(request_endpoint, query_type: "PUT", headers: headers, data: data)
    end

    public
    def delete_deployment_map(deployment_name=nil)
      # Delete a deployment map configuration
      if deployment_name.nil?
        raise("Deployment name has not been specified")
      end
      request_endpoint = "/api/v1/deployment-maps/#{deployment_name}"
      return query(request_endpoint, query_type: "DELETE")
    end

    ## Environment
    public
    def get_environments()
      # Get all environments
      request_endpoint = "/api/v1/environments"
      return query(request_endpoint, query_type: "GET")
    end

    public
    def get_environment(environment=nil)
      # Get an environment
      if environment.nil?
        raise("Environment has not been specified")
      end
      request_endpoint = "/api/v1/environments/#{environment}"
      return query(request_endpoint, query_type: "GET")
    end

    public
    def get_environment_protected(environment=nil, action=nil)
      # Find if environment is protected from action
      if environment.nil? or action.nil?
        raise("Environment or Action has not been specified")
      end
      request_endpoint = "/api/v1/environments/#{environment}/protected?action=#{action}"
      return query(request_endpoint, query_type: "GET")
    end

    public
    def get_environment_servers(environment=nil)
      # Get the list of servers in an environment
      if environment.nil?
        raise("Environment has not been specified")
      end
      request_endpoint = "/api/v1/environments/#{environment}/servers"
      return query(request_endpoint, query_type: "GET")
    end

    public
    def get_environment_asg_servers(environment=nil, asgname=nil)
      # Get a specific server in a given environment
      if environment.nil? or asgname.nil?
        raise("Either environment or asgname has not been specified")
      end
      request_endpoint = "/api/v1/environments/#{environment}/servers/#{asgname}"
      return query(request_endpoint, query_type: "GET")
    end

    public
    def get_environment_schedule(environment=nil)
      # Get schedule for an environment
      if environment.nil?
        raise("Environment has not been specified")
      end
      request_endpoint = "/api/v1/environments/#{environment}/schedule"
      return query(request_endpoint, query_type: "GET")
    end

    public
    def put_environment_schedule(environment=nil, expected_version=nil, data=Hash.new)
      # Set the schedule for an environment
      if environment.nil?
        raise("Environment has not been specified")
      end
      if expected_version.nil?
        headers = nil
      else
        headers = {"expected-version" => expected_version}
      end
      request_endpoint = "/api/v1/environments/#{environment}/schedule"
      return query(request_endpoint, query_type: "PUT", headers: headers, data: data)
    end

    public
    def get_environment_account_name(environment=nil)
      # Get account name for given environment
      if environment.nil?
        raise("Environment has not been specified")
      end
      request_endpoint = "/api/v1/environments/#{environment}/accountName"
      return query(request_endpoint, query_type: "GET")
    end

    public
    def get_environment_schedule_status(environment=nil, at_time=nil)
      # Get the schedule status for a given environment at a given time. If no "at" parameter is provided, the current status is returned
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
      # Get all environment configurations
      if environmenttype.nil?
        environmenttype_qs = ""
      else
        environmenttype_qs = "environmentType=#{environmenttype}"
      end
      if cluster.nil?
        cluster_qs = ""
      else
        cluster_qs = "cluster=#{cluster}"
      end
      # Construct qs
      if environmenttype.nil? and not cluster.nil?
        constructed_qs = "?#{cluster_qs}"
      elsif not environmenttype.nil? and cluster.nil?
        constructed_qs = "?#{environmenttype_qs}"
      elsif not environmenttype.nil? and not cluster.nil?
        constructed_qs = "?#{environmenttype_qs}&#{cluster_qs}"
      else
        constructed_qs = ""
      end
      request_endpoint = "/api/v1/config/environments#{constructed_qs}"
      return query(request_endpoint, query_type: "GET")
    end

    public
    def post_environments_config(data=Hash.new)
      # Create a new environment configuration
      request_endpoint = "/api/v1/config/environments"
      return query(request_endpoint, query_type: "POST", data: data)
    end

    public
    def get_environment_config(environment=nil)
      # Get a specific environment configuration
      if environment.nil?
        raise("Environment has not been specified")
      end
      request_endpoint = "/api/v1/config/environments/#{environment}"
      return query(request_endpoint, query_type: "GET")
    end

    public
    def put_environment_config(environment=nil, expected_version=nil, data=Hash.new)
      # Update an environment configuration
      if environment.nil?
        raise("Environment has not been specified")
      end
      if expected_version.nil?
        headers = ""
      else
        headers = {"expected-version" => expected_version}
      end
      request_endpoint = "/api/v1/config/environments/#{environment}"
      return query(request_endpoint, query_type: "PUT", headers: headers, data: data)
    end

    public
    def delete_environment_config(environment=nil)
      # Delete an environment configuration
      if environment.nil?
        raise("Environment has not been specified")
      end
      request_endpoint = "/api/v1/config/environments/#{environment}"
      return query(request_endpoint, query_type: "DELETE")
    end

    ## Environment Type
    public
    def get_environmenttypes_config()
      # Get all environment type configurations
      request_endpoint = "/api/v1/config/environment-types"
      return query(request_endpoint, query_type: "GET")
    end

    public
    def post_environmenttypes_config(data=Hash.new)
      # Create an Environment Type configuration
      request_endpoint = "/api/v1/config/environment-types"
      return query(request_endpoint, query_type: "POST", data: data)
    end

    public
    def get_environmenttype_config(environmenttype=nil)
      # Get an specific environment type configuration
      if environmenttype.nil?
        raise("Environment type has not been specified")
      end
      request_endpoint = "/api/v1/config/environment-types/#{environmenttype}"
      return query(request_endpoint, query_type: "GET")
    end

    public
    def put_environmenttype_config(environmenttype=nil, expected_version=nil, data=Hash.new)
      # Update an environment type configuration
      if environmenttype.nil?
        raise("Environment type has not been specified")
      end
      if expected_version.nil?
        headers = ""
      else
        headers = {"expected-version" => expected_version}
      end
      request_endpoint = "/api/v1/config/environment-types/#{environmenttype}"
      return query(request_endpoint, query_type: "PUT", headers: headers, data: data)
    end

    public
    def delete_environmenttype_config(environmenttype=nil)
      # Delete an environment type
      if environmenttype.nil?
        raise("Environment type has not been specified")
      end
      request_endpoint = "/api/v1/config/environment-types/#{environmenttype}"
      return query(request_endpoint, query_type: "DELETE")
    end

    ## Export
    public
    def export_resource(resource=nil, account=nil)
      # Export a configuration resources dynamo table
      if resource.nil? or account.nil?
        raise("Resource or account has not been specified")
      end
      request_endpoint = "/api/v1/config/export/#{resource}?account=#{account}"
      return query(request_endpoint, query_type: "GET")
    end

    ## Import
    public
    def import_resource(resource=nil, account=nil, mode=nil, data=Hash.new)
      # Import a configuration resources dynamo table
      if resource.nil? or account.nil? or mode.nil?
        raise("Resource or account has not been specified")
      end
      request_endpoint = "/api/v1/config/import/#{resource}?account=#{account}&mode=#{mode}"
      return query(request_endpoint, query_type: "PUT", data: data)
    end

    ## Instance
    public
    def get_instances()
      # Get all instances matching the given criteria
      request_endpoint = "/api/v1/instances"
      return query(request_endpoint, query_type: "GET")
    end

    public
    def get_instance(instance_id=nil)
      # Get a specific instance
      if instance_id.nil?
        raise("Instance id has not been specified")
      end
      request_endpoint = "/api/v1/instances/#{instance_id}"
      return query(request_endpoint, query_type: "GET")
    end

    public
    def get_instance_connect(instance_id=nil)
      # Connect to the instance via remote desktop
      if instance_id.nil?
        raise("Instance id has not been specified")
      end
      request_endpoint = "/api/v1/instances/#{instance_id}/connect"
      return query(request_endpoint, query_type: "GET")
    end

    public
    def put_instance_maintenance(instance_id=nil, data=Hash.new)
      # Update the ASG standby-state of a given instance
      if instance_id.nil?
        raise("Instance id has not been specified")
      end
      request_endpoint = "/api/v1/instances/#{instance_id}/maintenance"
      return query(request_endpoint, query_type: "PUT")
    end

    ## Load Balancers
    public
    def get_loadbalancer(id=nil)
      # Get load balancer data
      if id.nil?
        raise("Load Balancer ID has not been specified")
      end
      request_endpoint = "/api/v1/config/load-balancer/#{id}"
      return query(request_endpoint, query_type: "GET")
    end

    public
    def get_lbsettings_config()
      # List all load balancer settings
      request_endpoint = "/api/v1/config/lb-settings"
      return query(request_endpoint, query_type: "GET")
    end

    public
    def post_lbsettings_config(data=Hash.new)
      # Create a load balancer setting
      request_endpoint = "/api/v1/config/lb-settings"
      return query(request_endpoint, query_type: "POST", data: data)
    end

    public
    def get_lbsettings_vhost_config(environment=nil, vhostname=nil)
      # Get a specific load balancer setting
      if environment.nil?
        raise("Environment has not been specified")
      end
      if vhostname.nil?
        raise("Virtual Host Name (vhostname) has not been specified")
      end
      request_endpoint = "/api/v1/config/lb-settings/#{environment}/#{vhostname}"
      return query(request_endpoint, query_type: "GET")
    end

    public
    def put_lbsettings_vhost_config(environment=nil, vhostname=nil, expected_version=nil, data=Hash.new)
      # Update a load balancer setting
      if environment.nil?
        raise("Environment has not been specified")
      end
      if vhostname.nil?
        raise("Virtual Host Name (vhostname) has not been specified")
      end
      if expected_version.nil?
        headers = ""
      else
        headers = {"expected-version" => expected_version}
      end
      request_endpoint = "/api/v1/config/lb-settings/#{environment}/#{vhostname}"
      return query(request_endpoint, query_type: "PUT", headers: headers, data: data)
    end

    public
    def delete_lbsettings_vhost_config(environment=nil, vhostname=nil)
      # Delete an load balancer setting
      if environment.nil?
        raise("Environment has not been specified")
      end
      if vhostname.nil?
        raise("Virtual Host Name (vhostname) has not been specified")
      end
      request_endpoint = "/api/v1/config/lb-settings/#{environment}/#{vhostname}"
      return query(request_endpoint, query_type: "DELETE")
    end

    ## Notifications
    public
    def get_notificationsettings_config()
      # List Notification settings
      request_endpoint = "/api/v1/config/notification-settings"
      return query(request_endpoint, query_type: "GET")
    end

    public
    def post_notificationsettings_config(data=Hash.new)
      # Post new Notification settings
      request_endpoint = "/api/v1/config/notification-settings"
      return query(request_endpoint, query_type: "POST", data: data)
    end

    public
    def get_notificationsetting_config(notification_id=nil)
      # Get Notification settings
      if notification_id.nil?
        raise("Notification id has not been specified")
      end
      request_endpoint = "/api/v1/notification-settings/#{notification_id}"
      return query(request_endpoint, query_type: "GET")
    end

    public
    def put_notificationsetting_config(notification_id=nil, expected_version=nil, data=Hash.new)
      # Update an associated AWS Account
      if notification_id.nil?
        raise("Notification id has not been specified")
      end
      if expected_version.nil?
        headers = ""
      else
        headers = {"expected-version" => expected_version}
      end
      request_endpoint = "/api/v1/notification-settings/#{notification_id}"
      return query(request_endpoint, query_type: "PUT", headers: headers, data: data)
    end

    public
    def delete_notificationsetting_config(notification_id=nil)
      # Remove Notification settings
      if notification_id.nil?
        raise("Notification id has not been specified")
      end
      request_endpoint = "/api/v1/notification-settings/#{notification_id}"
      return query(request_endpoint, query_type: "DELETE")
    end

    ## Upload Package
    # TODO Slice
    public
    def get_package_upload_url_environment(service=nil, version=nil, environment=nil)
      # Upload an environment-specific package
      if service.nil? or version.nil? or environment.nil?
        raise("Parameter has not been specified")
      end
      request_endpoint = "/api/v1/package-upload-url/#{service}/#{version}/#{environment}"
      return query(request_endpoint, query_type: "GET")
    end

    public
    def get_package_upload_url(service=nil, version=nil)
      # Upload an environment-independent package
      if service.nil? or version.nil?
        raise("Parameter has not been specified")
      end
      request_endpoint = "/api/v1/package-upload-url/#{service}/#{version}"
      return query(request_endpoint, query_type: "GET")
    end

    ## Permissions
    public
    def get_permissions_config()
      # Get all permission configurations
      request_endpoint = "/api/v1/config/permissions"
      return query(request_endpoint, query_type: "GET")
    end

    public
    def post_permissions_config(data=Hash.new)
      # Create a new permission configuration"""
      request_endpoint = "/api/v1/config/permissions"
      return query(request_endpoint, query_type: "POST", data: data)
    end

    public
    def get_permission_config(name=nil)
      # Get a specific permission configuration
      if name.nil?
        raise("Permission name has not been specified")
      end
      request_endpoint = "/api/v1/config/permissions/#{name}"
      return query(request_endpoint, query_type: "GET")
    end

    public
    def put_permission_config(name=nil, expected_version=nil, data=Hash.new)
      # Update a permission configuration
      if name.nil?
        raise("Permission name has not been specified")
      end
      if expected_version.nil?
        headers = ""
      else
        headers = {"expected-version" => expected_version}
      end
      request_endpoint = "/api/v1/config/permissions/#{name}"
      return query(request_endpoint, query_type: "PUT", headers: headers, data: data)
    end

    public
    def delete_permission_config(name=nil)
      # Delete a permissions configuration
      if name.nil?
        raise("Permission name has not been specified")
      end
      request_endpoint = "/api/v1/config/permissions/#{name}"
      return query(request_endpoint, query_type: "DELETE")
    end

    ## Service
    public
    def get_services()
      # Get the list of currently deployed services
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
    def get_service_asgs(service=nil, environment=nil, slice=nil)
      # Get the ASGs to which a service is deployed
      if service.nil?
        raise("Service has not been specified")
      end
      if environment.nil?
        raise("Environment has not been specified")
      end
      if slice.nil?
        slice_qs = ""
      else
        slice_qs = "&slice=#{slice}"
      end
      request_endpoint = "/api/v1/services/#{service}/asgs?environment=#{environment}#{slice_qs}"
      return query(request_endpoint, query_type: "GET")
    end

    public
    def get_service_overall_health(service=nil, environment=nil)
      # Get a overall health for a deployed service
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
    def get_service_health(service=nil, environment=nil, slice=nil, server_role=nil)
      # Get health for a specific service
      if service.nil?
        raise("Service has not been specified")
      end
      if environment.nil?
        raise("Environment has not been specified")
      end
      if slice.nil?
        raise("Slice has not been specified")
      end
      request_endpoint = "/api/v1/services/#{service}/health/#{slice}?environment=#{environment}"
      if not server_role.nil?
        request_endpoint = "#{request_endpoint}&serverRole=#{server_role}"
      end
      return query(request_endpoint, query_type: "GET")
    end

    public
    def get_service_slices(service=nil, environment=nil, active=nil)
      # Get slices for a deployed service
      if service.nil?
        raise SyntaxError("Service has not been specified")
      end
      if environment.nil?
        raise SyntaxError("Environment has not been specified")
      end
      request_endpoint = "/api/v1/services/#{service}/slices?environment=#{environment}"
      if not active.nil?
        request_endpoint = "#{request_endpoint}&active=#{active}"
      end
      return query(request_endpoint, query_type: "GET")
    end

    public
    def put_service_slices_toggle(service=nil, environment=nil)
      # Toggle the slices for a deployed service
      if service.nil?
        raise("Service has not been specified")
      end
      if environment.nil?
        raise("Environment has not been specified")
      end
      request_endpoint = "/api/v1/services/#{service}/slices/toggle?environment=#{environment}"
      return query(request_endpoint, query_type: "PUT")
    end

    public
    def get_services_config()
      # Get all service configurations
      request_endpoint = "/api/v1/config/services"
      return query(request_endpoint, query_type: "GET")
    end

    public
    def post_services_config(data=Hash.new)
      # Create a service configuration
      request_endpoint = "/api/v1/config/services"
      return query(request_endpoint, query_type: "POST", data: data)
    end

    public
    def get_service_config(service=nil, cluster=nil)
      # Get a specific service configuration
      if service.nil?
        raise("Service has not been specified")
      end
      if cluster.nil?
        raise("Cluster name (team) has not been specified")
      end
      request_endpoint = "/api/v1/config/services/#{service}/#{cluster}"
      return query(request_endpoint, query_type: "GET")
    end

    public
    def put_service_config(service=nil, cluster=nil, expected_version=nil, data=Hash.new)
      # Update a service configuration
      if service.nil?
        raise("Service has not been specified")
      end
      if cluster.nil?
        raise("Cluster name (team) has not been specified")
      end
      if expected_version.nil?
        headers = ""
      else
        headers = {"expected-version" => expected_version}
      end
      request_endpoint = "/api/v1/config/services/#{service}/#{cluster}"
      return query(request_endpoint, query_type: "POST", data: data, headers: headers)
    end

    public
    def delete_service_config(service=nil, cluster=nil)
      # Delete a service configuration
      if service.nil?
        raise("Service has not been specified")
      end
      if cluster.nil?
        raise("Cluster name (team) has not been specified")
      end
      request_endpoint = "/api/v1/config/services/#{service}/#{cluster}"
      return query(request_endpoint, query_type: "DELETE")
    end

    ## Status
    public
    def get_status()
      # Get version and status information
      request_endpoint = "/api/v1/diagnostics/healthcheck"
      return query(request_endpoint, query_type: "GET")
    end

    ## Target State
    public
    def get_target_state(environment=nil)
      # Get the target state for a given environment
      if environment.nil?
        raise("Environment has not been specified")
      end
      request_endpoint = "/api/v1/target-state/#{environment}"
      return query(request_endpoint, query_type: "GET")
    end

    public
    def delete_target_state(environment=nil)
      # Remove the target state for all services in a given environment
      if environment.nil?
        raise("Environment has not been specified")
      end
      request_endpoint = "/api/v1/target-state/#{environment}"
      return query(request_endpoint, query_type: "DELETE")
    end

    public
    def delete_target_state_service(environment=nil, service=nil)
      # Remove the target state for all versions of a service
      if environment.nil? or service.nil?
        raise("Environment or Service has not been specified")
      end
      request_endpoint = "/api/v1/target-state/#{environment}/#{service}"
      return query(request_endpoint, query_type: "DELETE")
    end

    public
    def delete_target_state_service_version(environment=nil, service=nil, version=nil)
      # Remove the target state for a specific version of a service
      if environment.nil? or service.nil? or version.nil?
        raise("Environment or Service has not been specified")
      end
      request_endpoint = "/api/v1/target-state/#{environment}/#{service}/#{version}"
      return query(request_endpoint, query_type: "DELETE")
    end

    ## Upstream
    public
    def get_upstream_slices(upstream=nil)
      # Get slices for a given upstream
      if upstream.nil?
        raise("Upstream name has not been specified")
      end
      request_endpoint = "/api/v1/upstreams/#{upstream}/slices"
      return query(request_endpoint, query_type: "GET")
    end

    public
    def put_upstream_slices_toggle(upstream=nil, environment=nil)
      # Toggle the slices for a given upstream
      if upstream.nil? or environment.nil?
        raise("Upstream name or Service name has not been specified")
      end
      request_endpoint = "/api/v1/upstreams/#{upstream}/slices/toggle?environment=#{environment}"
      return query(request_endpoint, query_type: "GET")
    end

    public
    def get_upstreams_config()
      # Get all upstream configurations
      request_endpoint = "/api/v1/config/upstreams"
      return query(request_endpoint, query_type: "GET")
    end

    public
    def post_upstreams_config(data=Hash.new)
      # Create an upstream configuration
      request_endpoint = "/api/v1/config/upstreams"
      return query(request_endpoint, query_type: "POST", data: data)
    end

    public
    def get_upstream_config(upstream=nil, account="Non-Prod")
      # Get an a specific upstream configuration
      if upstream.nil?
        raise("Upstream name has not been specified")
      end
      request_endpoint = "/api/v1/config/upstreams/#{upstream}?account=#{account}"
      return query(request_endpoint, query_type: "GET")
    end

    public
    def put_upstream_config(upstream=nil, expected_version=nil, data=Hash.new)
      # Update an upstream configuration
      if upstream.nil?
        raise("Upstream name has not been specified")
      end
      if expected_version.nil?
        headers = ""
      else
        headers = {"expected-version" => expected_version}
      end
      request_endpoint = "/api/v1/config/upstreams/#{upstream}"
      return query(request_endpoint, query_type: "PUT", headers: headers, data: data)
    end

    public
    def delete_upstream_config(upstream=nil, account="Non-Prod")
      # Delete an upstream configuration
      if upstream.nil?
        raise("Upstream name has not been specified")
      end
      request_endpoint = "/api/v1/config/upstreams/#{upstream}?account=#{account}"
      return query(request_endpoint, query_type: "DELETE")
    end

  end
end
