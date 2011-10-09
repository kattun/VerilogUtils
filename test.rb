str = "hoge"

f = open("test.txt", "r")

line = f.gets
# 不可
while(line += f.gets)
p line
end
