# submodule gen
#
#仕様
#上位階層のmodule定義を渡し、module宣言部(input, output)を定義したファイルを生成する。
#既にファイルが存在する場合は、ファイルを読み込み、module部だけ書き換える。
#もしもの時のために.bakファイルを作っておく

require 'pp'
require 'fileutils'
include FileUtils

def commentHandle(line, file)
  # p line
  if /\/\*/ =~ line
    while !(/\*\// =~ line)
      line = file.gets
    end
    return line, file
  end
  if /\/\// =~ line
    tmp = line.split(/\/\//)
    return tmp[0], file
  else
    return line, file
  end
end

#-------------------------------------------------
#main
#-------------------------------------------------
decname = []
mods = 0	#何個目のモジュールかを数える

if ARGV.length != 2
  puts "usage: $ruby subModuleGen.rb <filename> <接頭語>"
  exit
end

begin
  upfile = open(ARGV[0])
rescue => ex
  puts ex
  exit
end

inout = nil
# 1文読み込みの繰り返し
while rline = upfile.gets do
  rline, upfile = commentHandle(rline,upfile)
  # 上位層リード部
  # input, output, wire宣言の読み込み
  if(/(input|output\s*reg|output|wire)\s*(\[[0-9]+:[0-9]+\]|\s)\s*(.+)/ =~ rline)
    deckind = $1
    plange = $2
    # ポートの範囲が1bitのとき
    if plange == "\s"
      plange = nil
    end
    # 信号名は単語だけ抜き取る
    tmp = $3
    # 区切り文字で分ける
    tmp_sp = tmp.split(/(,|;|\s)/)
    # 空白、区切り文字だけの配列要素を削除
    tmp_delspc = tmp_sp.delete_if{|item| item =~ /(,|;|^\s+$|^$)/}
    decname.push([deckind, plange, tmp_delspc])
  end

  portname = []
  data_befmod = []
  data_afmod = []

  endflag = 0
  # ARGV[1]_hoge のモジュール探索
  if /(sdrd_.*)\s.+/ =~ rline
    filename = $1
    inout = "input"
    while endflag == 0 do
      if "\n" == rline
        inout = "output"
      end
      # .hoge1(hoge2)の探索
      if /\.(.*)\((.*)\)/ =~ rline
        portname_s = $1
        wirename = $2

        # 区切り文字で分ける
        tmp = portname_s
        tmp_sp = tmp.split(/(\t|\s)/)
        # 空白、区切り文字だけの配列要素を削除
        tmp_delspc = tmp_sp.delete_if{|item| item =~ /(,|;|^\s+$|^$)/}
        portname_s = tmp_delspc[0]

        tmp = wirename
        tmp_sp = tmp.split(/(\t|\s)/)
        # 空白、区切り文字だけの配列要素を削除
        tmp_delspc = tmp_sp.delete_if{|item| item =~ /(,|;|^\s+$|^$)/}
        wirename = tmp_delspc[0]

        lange = "-1"
        decname.each{|deckind, plange, name|
          name.each{|index|
            if index == wirename
              lange = plange
            end
          }
        }
        if lange == "-1"
          puts "-------------------------error-------------------------------"
          puts "#{ARGV[1]}_top isnt declare #{wirename} in module #{filename}"
          puts "-------------------------------------------------------------"
          lange = nil
        end
        portname.push([inout, lange, portname_s])
      end
      rline = upfile.gets
      rline, upfile = commentHandle(rline,upfile)
      if /\);/ =~ rline
        endflag = 1
      end
    end 	#module宣言えんど
    endflag = 0

    #--------------------------------------------------------------
    # 新しいmodule, ファイルデータ作成部
    #--------------------------------------------------------------
    lwfileData = nil
    begin
      open(filename+".v", "r"){|lwfile|
        # wfileの中身を全て読み込んで配列に入れる
        lwfileData = lwfile.readlines
        #backup作成
        begin
          open("backup/"+filename+".v.bak", "w"){|f|
            unless lwfileData.nil?
              p lwfileData
              lwfileData.each{|line| f.puts(line)}
            end
          }
        rescue => ex
          puts ex
          puts "new directory backup/ maked"
          mkdir_p("backup")
          retry
        end
        # module宣言部だけ削除
        decend = nil
        comflag = 0
        modflag = 0
        afflag = 0
        lwfileData.each{|item|
          if modflag == 0 && afflag == 0
            data_befmod.push(item)
          elsif modflag == 0 && afflag == 1
            data_afmod.push(item)
          end
          if /\/\// =~ item
            next
          end
          if /\/\*/ =~ item
            comflag = 1
            next
          end
          if /\*\// =~ item
            comflag = 0
            next
          end
          if comflag == 1
            next
          end
          if /(^|\s)module/ =~ item
            modflag = 1
            data_befmod.pop
            next
          end
          if /\);/ =~ item && modflag == 1
            modflag = 0
            afflag = 1
            next
          end
          if modflag == 1
            next
          end
        }
      }
    rescue => nofile	# 下位モジュールのファイルが無かった時
      puts nofile
      puts "file:#{filename}.v cant open, creating newfile"
      lwfileData = nil
      data_befmod = nil
      data_afmod = nil
    end

    #-------------------------------------------------
    #下位モジュールファイル作成
    #-------------------------------------------------
    begin
      open(filename+".v", "w"){|lwfile|

        data_befmod.each{|line| lwfile.puts(line)} unless data_befmod.nil?
        lwfile.puts("module "+filename)
        lwfile.puts("(")
        i = 0
        portname.each{|inout, lange, name|
          if lange == nil
            lange = "\s\s\s\s\s\s"
          end
          if(portname[i+1] == nil)
            lwfile.puts("\s\s#{inout}\s\s\s#{lange}\s\s\s\s#{name}")	#最後の宣言ならカンマいらない
          else
            lwfile.puts("\s\s#{inout}\s\s\s#{lange}\s\s\s\s#{name},")
          end
          i += 1
        }
        lwfile.puts(");")
        data_afmod.each{|line| lwfile.puts(line)} unless data_befmod.nil?
      }
    rescue => ex
      puts ex
      exit
    end

    #-------------------------------------------------
    #入出力信号表作成
    #-------------------------------------------------

    if mods == 0
      inoutfig = open(ARGV[0].split(".")[0] + "_inout.txt", "w")
    else
      inoutfig = open(ARGV[0].split(".")[0] + "_inout.txt", "a")
    end
    inoutfig.puts("------------------------------------------------------------------")
    inoutfig.puts("#{mods+1}. #{filename} in-out sign figure")
    inoutfig.puts("------------------------------------------------------------------")
    inoutfig.print(
      sprintf("  in/out: width :         signal name: sentence \n")
    )
    inoutfig.puts("------------------------------------------------------------------")

    portname.each{|inout, lange, name|
      if lange == nil
        lange_val = 1
      else
        lange_sp = lange.split(/(\[|:|\])/)
        lange_val = lange_sp[2].to_i - lange_sp[4].to_i + 1
      end
      inoutfig.print(sprintf("%8s:  %3d  :%20s:\n", inout, lange_val, name))
    }
    inoutfig.puts("------------------------------------------------------------------")
    inoutfig.close
    mods += 1
  end		# ARGV[1]_発見のif end
end
upfile.close
