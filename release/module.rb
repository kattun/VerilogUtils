# ------------------------------------------------------------------------------- #
# Title         : Auto Submodule Generator
# Project       : Verilog Utility
# File          : module.rb
# Author        : Katsuyuki SEKI <seki@islab.cs.tsukuba.ac.jp>
# ------------------------------------------------------------------------------- #
# Description   : 
# ------------------------------------------------------------------------------- #
# Revisions        :
# 2010/11/06      Created
# 2011/12/23      コメント、動作を修正
# ------------------------------------------------------------------------------- #

#
# Verilogのモジュールを表現するクラス
#
class Module
  # module宣言の信号とコメントとの間隔
  TAB = 4 

  def initialize
    @name
    @submodules = []
    @inputs = []
    @outputs = []
    @output_regs = []
    @wires = []
    @regs = []
    @functions = []
    @contents = []
    @val_all = [@inputs, @outputs, @output_regs, @wires, @regs]
    @all = []
    @arg_max_len = 0
  end

  # モジュールの名前
  attr_accessor :name
  # サブモジュールの配列
  attr_accessor :submodules
  # inputクラスの配列
  attr_accessor :inputs
  # outputクラスの配列
  attr_accessor :outputs, :output_regs
  # wireクラスの配列
  attr_accessor :wires
  # regクラスの配列
  attr_accessor :regs
  # functionクラスの配列
  attr_accessor :functions
  # その他の中身
  attr_accessor :contents
  # 変数全体へのアクセス
  attr_reader :val_all
  # ファイルの内容をそのまま保持
  attr_accessor :all
  # module宣言部の信号の最大長さ（整形に利用）
  attr_accessor :arg_max_len

  def config_bus(bus)
        if bus.empty?
          retBus = "         "
        else
          retBus = "[#{bus[0]}:#{bus[1]}]".ljust(9)
        end
        return retBus
  end

  def write
    outdata = []

    # module宣言部
    outdata << "module #{name.gsub(".v","")}"
    outdata << "("
    @inputs.each{|input|
      bus = config_bus(input.bus)

      if input.comment.to_s == ""
        comment = ""
      else
          comment = "// " + input.comment
      end

      signal = input.name + ", #{comment}".rjust(2 + TAB + @arg_max_len - input.name.length + comment.length)
      outdata << "input      #{bus} #{signal}"
    }
    outdata << "\n"
    @outputs.each{|output|
      bus = config_bus(output.bus)

      if output.comment.to_s == ""
        comment = ""
      else
        comment = "// " + output.comment
      end

      signal = output.name + ", #{comment}".rjust(2 + TAB + @arg_max_len - output.name.length + comment.length)
      outdata << "output     #{bus} #{signal}"
    }
    @output_regs.each{|output|
      bus = config_bus(output.bus)

      if output.comment.to_s == ""
        comment = ""
      else
        comment = "// " + output.comment
      end

      signal = output.name + ", #{comment}".rjust(2 + TAB + @arg_max_len - output.name.length + comment.length)
      outdata << "output reg #{bus} #{signal}"
    }
    line = outdata.pop
    outdata << line.sub(",","")
    outdata << ");"

    outdata.concat(@contents)
    open(@name, "w") { |fp|
      outdata.each{|line| fp.puts line }
    }
  end
end

#
# Verilogの関数のクラス
#
class Function
  # 引数
  # func
  # 関数名
  # inputs
  # inputクラスの配列
  # contents
  # 中身を表す配列
  def initialize(func, inputs, contents)
    @func = func
    @inputs = inputs
    @contents = contents
  end

  # inputクラスの配列
  attr_accessor :inputs
  # その他の中身を表す配列
  attr_accessor :contents
  # 関数名
  attr_reader :func
end

#
# Verilogの変数を表すクラス
# （input, output, wire, reg等）
#
class Variable
  include ExpConst

  # 変数の種類エラー
  class VarTypeException < StandardError; end

  # 引数
  # type
  # 変数の種類
  # bus
  # port宣言のバス幅
  # name
  # 変数名
  # comment
  # 変数に対するコメント
  def initialize(type, bus, name, comment)
    @type = type
    @bus = bus
    @name = name
    @comment = comment
  end
  # 変数の種類
  attr_reader :type
  # 変数のバス幅
  attr_reader :bus
  # 変数の名前
  attr_reader :name
  # 変数に対するコメント
  attr_reader :comment
end


#
# moduleクラスを出力するクラス
#
class Printer
  def initialize
  end

  def print(mod)
  end

  def generate_submodule(mod)
    mod.submodules.each do |submod|
      begin
        fr = open(submod.name, "r")
      rescue => ex
        puts ex
        fw = open(submod.name, "w")
      end
    end
  end

  def make_inoutSeat(filename, mod)
    fp = open(filename, "w")

    fp.puts "input"
    mod.inputs.each{|input|
      str = input.name

      if input.bus.empty?
        bit = "0"
      else
        bit = (input.bus[0]-input.bus[1]+1).to_s
      end
      str += "," + bit

      cmnt = input.comment.gsub(/^\s*\/\*\s*/, "").gsub(/\s*\*\/\s*$/, "")
      cmnt = input.comment.gsub(/^\s*\/\/\s*/, "")
      str += "," + cmnt
      fp.puts str.kconv(Kconv::SJIS, Kconv::UTF8)
    }

    fp.puts "\n"

    fp.puts "output"
    mod.outputs.each{|output|
      str = output.name

      if output.bus.empty?
        bit = "0"
      else
        bit = (output.bus[0]-output.bus[1]+1).to_s
      end
      str += "," + bit

      cmnt = output.comment.gsub(/^\s*\/\*\s*/, "").gsub(/\s*\*\/\s*$/, "")
      cmnt = output.comment.gsub(/^\s*\/\/\s*/, "")
      str += "," + cmnt
      fp.puts str
    }
  end
end
