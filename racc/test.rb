require './test.tab.rb'
puts '超豪華電卓 2 号機'
puts 'Q で終了します'
calc = VeriParser.new
f = open("test.v", "r")
str = f.read
begin
  p calc.evaluate(str)
rescue ParseError => ex
  puts 'parse error'
  puts ex
end

