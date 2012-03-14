`mkdir utf`
Dir::foreach("."){|file|
  next unless file =~ /draw_.*\.v/
  `iconv -f cp932 -t UTF-8 #{file} > #{"utf/" + file}`
}
