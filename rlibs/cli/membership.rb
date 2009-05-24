options = {}
options[:port] = 11222
options[:databases] = ''
options[:config] = ''
options[:host] = `hostname -s`.chomp

OptionParser.new do |opts|
  opts.banner = "Usage: dynomite start [options]"

  contents =  File.read(File.dirname(__FILE__) + "/shared/common.rb")
  eval contents
  
  opts.on('-m', "--module MODULE") do |mod|
    options[:module] = mod
  end
  
  opts.on('-f', "--function FUNCTION") do |func|
    options[:function] = func
  end
  
  opts.on('-a', "--arg ARG") do |arg|
    options[:args] ||= []
    options[:args] << arg
  end
  
end.parse!

cookie = options[:nocookie] ? "" : "-setcookie " + Digest::MD5.hexdigest(options[:cluster] + "NomMxnLNUH8suehhFg2fkXQ4HVdL2ewXwM")

nametype = (options[:host].include? '.') ? "name" : "sname"

str = "erl \
  +K true \
  +A 128 \
  -hidden \
  -smp enable \
  -pz #{ROOT}/ebin/ \
  -#{nametype} command@#{options[:host]} \
  -noshell \
  #{cookie} \
  -run commands start \
  -extra #{options[:name]} #{options[:module]} #{options[:function]} #{(options[:args] || []).join(' ')}"
puts str
exec str
