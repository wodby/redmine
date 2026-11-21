# Settings Redmine evaluates inside its application configuration.

# Redmine queues background jobs, such as notification emails, in the web
# process's memory by default, so jobs still waiting are lost when a container
# stops. Running them inline sends each email during the request that causes
# it. REDMINE_QUEUE_ADAPTER selects another Active Job adapter, for example
# one a plugin or your own image adds.
config.active_job.queue_adapter = ENV.fetch('REDMINE_QUEUE_ADAPTER', 'inline').to_sym
