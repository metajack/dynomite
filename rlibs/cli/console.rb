options = {}
options[:port] = 11222
options[:databases] = ''
options[:config] = ''
options[:host] = `hostname -s`.chomp

OptionParser.new do |opts|
  opts.banner = "Usage: dynomite console [options]"

  contents =  File.read(File.dirname(__FILE__) + "/shared/common.rb")
  eval contents

end.parse!

cookie = options[:nocookie] ? "" : "-setcookie " + Digest::MD5.hexdigest(options[:cluster] + "NomMxnLNUH8suehhFg2fkXQ4HVdL2ewXwM")

nametype = (options[:host].include? '.') ? "name" : "sname"

str = "erl -#{nametype} remsh_#{$$}@#{options[:host]} -remsh #{options[:name]}@#{options[:host]} -hidden #{cookie}"
puts str
exec str
