## Ruby Environment Manager

Ruby client library for [Environment Manager](https://github.com/trainline/environment-manager)

### tl;dr

Normal use of the Client

```
require 'environment-manager'

em_session = new = EnvironmentManager::Api.new(server,user,password)
results = em_session.get_upstreams_config()
```

For the full list of methods available from the API you can check [here](https://github.com/trainline/ruby-environment_manager/blob/master/lib/environment_manager/api.rb)
