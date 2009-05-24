options = {}
options[:port] = "-dynomite port 11222"
options[:databases] = ''
options[:config] = '-dynomite config "config.json"'
options[:host] = `hostname -s`.chomp

OptionParser.new do |opts|
  opts.banner = "Usage: dynomite start [options]"

  contents =  File.read(File.dirname(__FILE__) + "/shared/common.rb")
  eval contents

  opts.separator ""
  opts.separator "Specific options:"
  
  opts.on("-c", "--config [CONFIGFILE]", "path to the config file") do |config|
    options[:config] = %Q(-dynomite config "#{config}")
  end
  
  opts.on("-l", "--log [LOGFILE]", "error log path") do |log|
    options[:log] = %Q[-kernel error_logger '{file,"#{File.join(log, 'dynomite.log')}"}' -sasl sasl_error_logger '{file,"#{File.join(log, 'sasl.log')}"}']
  end
  
  opts.on('-j', "--join [NODENAME]", 'node to join with') do |node|
    options[:jointo] = %Q(-dynomite jointo "'#{node}'")
  end
  
  opts.on('-d', "--detached", "run detached from the shell") do |detached|
    options[:detached] = '-detached'
  end
end.parse!

cookie = options[:nocookie] ? "" : "-setcookie " + Digest::MD5.hexdigest(options[:cluster] + "NomMxnLNUH8suehhFg2fkXQ4HVdL2ewXwM")

nametype = (options[:host].include? '.') ? "name" : "sname"

str = "erl \
  -boot start_sasl \
  +K true \
  +A 128 \
  +P 60000 \
  -smp enable \
  -pz #{ROOT}/ebin/ \
  -pz #{ROOT}/deps/mochiweb/ebin \
  -pz #{ROOT}/deps/rfc4627/ebin \
  -pz #{ROOT}/deps/thrift/ebin \
  -#{nametype} #{options[:name]}@#{options[:host]} \
  #{options[:log]} \
  #{options[:config]} \
  #{options[:jointo]} \
  #{cookie} \
  -run dynomite start \  
  #{options[:detached]} \
  #{options[:profile]}"
puts str
exec str

  #  -boot #{ROOT}/releases/0.5.0/dynomite_rel \
