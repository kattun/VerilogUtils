require 'pp'

a = []
b = [1,2,3,4,5]
a = b
pp a.object_id
pp b.object_id
b = [1,2,3]

pp a.object_id
pp b.object_id
