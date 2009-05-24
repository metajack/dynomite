#defaults
options[:name] = 'dynomite'
options[:host] = `hostname -s`.chomp
options[:cluster] = 'development'
options[:nocookie] = false

opts.separator ""
opts.separator "common options:"

opts.on("-o", "--node [NODE]", "The erlang nodename") do |name|
  options[:name] = name
end

opts.on("-H", "--host [HOST]", "The hostname of the node") do |name|
  options[:host] = name
end

opts.on("-n", "--cluster [CLUSTER]", "The cluster name (cookie token)") do |name|
  options[:cluster] = name
end

opts.on("-N", "--no-cookie", "Don't set a cookie; use the system one") do |name|
  options[:nocookie] = !name
end
