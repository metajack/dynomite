options = {}
options[:host] = `hostname -s`.chomp

OptionParser.new do |opts|
  opts.banner = "Usage: dynomite status [options]"

  contents =  File.read(File.dirname(__FILE__) + "/shared/common.rb")
  eval contents
end.parse!

cookie = options[:nocookie] ? "" : "-setcookie " + Digest::MD5.hexdigest(options[:cluster] + "NomMxnLNUH8suehhFg2fkXQ4HVdL2ewXwM")

nametype = (options[:host].include? '.') ? "name" : "sname"

str = %Q(erl -smp -#{nametype} console_#{$$}@#{options[:host]} -hidden #{cookie} -pa #{ROOT}/ebin/ -run commands start -run erlang halt -noshell -node #{options[:name]}@#{options[:host]} -m membership -f status)
puts str
exec str
