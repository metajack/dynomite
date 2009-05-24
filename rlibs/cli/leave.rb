options = {}
options[:host] = `hostname -s`.chomp

OptionParser.new do |opts|
  opts.banner = "Usage: dynomite stop [options]"

  contents =  File.read(File.dirname(__FILE__) + "/shared/common.rb")
  eval contents
end.parse!

cookie = options[:nocookie] ? "" : "-setcookie " + Digest::MD5.hexdigest(options[:cluster] + "NomMxnLNUH8suehhFg2fkXQ4HVdL2ewXwM")

nametype = (options[:host].include? '.') ? "name" : "sname"

str = %Q(erl -#{nametype} remsh_#{$$}@#{options[:host]} -remsh #{options[:name]}@#{options[:host]} -hidden #{cookie}" -noshell -run membership leave)
puts str
exec str
