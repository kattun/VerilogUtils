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
# Verilogのパースで使う正規表現の定数
#
module ExpConst
  ###################################################
  # サブモジュールを作成したいモジュールの接頭辞
  #（drw_hogeという名前のモジュールが対象となる）
  TAG = "draw_"     # これを変更
  ###################################################

  #Area
  EXP_SUBMODULE_BEGIN = /(#{TAG}.*)\s+.+/
  EXP_LINECOMMENT_BEGIN = /\A\s*\/\//
  EXP_MULTICOMMENT_BEGIN = /\A\s*\/\*/
  EXP_MULTICOMMENT_END = /\*\//
  EXP_ARGAREA_BEGIN = /\A\s*module/
  EXP_ARGAREA_END = /\);/
  EXP_ARGAREA_ENDONLY = /\A\s*\);/
  EXP_FUNC_BEGIN = /\A\s*function/
  EXP_FUNC_END = /\A\s*endfunction/

  # Args
  EXP_INPUT = /\A\s*input\s+/
  EXP_OUTPUT = /\A\s*output\s+/
  EXP_OUTPUTREG = /\A\s*output\s+reg\s+/
  EXP_WIRE = /\A\s*wire\s+/
  EXP_REG = /\A\s*reg\s+/
  EXP_FUNCTION = /\A\s*function\s+/

  # comment
  EXP_LINECOMMENT = /\/\/.*$/
  EXP_MULTILINECOMMENT = /\/\*.*\*\//m
end

#
# Verilogをパースするクラス
#
class Parser
  include ExpConst

  # パースエラー
  class ParseException < StandardError; end
  # 変数定義のエラー
  class ArgException < StandardError; end

  # パース結果を保持するmoduleクラス
  attr_reader :module

  #
  # パースを実行
  #
  def parse(filename)
    @module = Module.new
    @module.name = filename
    file = open(filename, "r")

    while(line = file.gets)
      case(line)
      when EXP_ARGAREA_BEGIN
        parse_argArea(file,line)
        pos = file.pos
      when EXP_SUBMODULE_BEGIN
        parse_submodule(file, line)
      when EXP_FUNC_BEGIN
        function = parse_func(file,line)
        @module.functions << function
      when EXP_WIRE
        variables = VariableParse(line, :wire)
        variables.each{|variable| @module.wires << variable }
      when EXP_REG
        variables = VariableParse(line, :reg)
        variables.each{|variable| @module.regs << variable }
      else
      end
    end

    file.pos = pos

    file.each{|line| @module.contents << line}

    return @module
  end

  #
  # サブモジュール呼び出しをパースするメソッド
  #
  def parse_submodule(file, line)
    line =~ EXP_SUBMODULE_BEGIN
    filename = $1 + ".v"
    inout = "input"
    submod = Module.new()
    submod.name = filename

    # 引数の括弧'('を読みとばす
    line = file.gets

    while line = file.gets
      break if line =~ /\);/

      # 空行でinput信号, output信号の切り替え
        if line =~ /^\s*$/
          inout = "output"
          line = file.gets
        end

      # .hoge1(hoge2)の探索
      line,comment = line.split("//")
      #items = line.gsub(" ", "").gsub(/(\.|\(|\)|,)/, " ").split(" ")
      items = line.gsub(" ", "").gsub(/\W/, " ").split(" ")

      portname_s = items[0]
      wirename = items[1]

      val_all = @module.val_all.flatten
      bus = "-1"
      val = val_all.select{|x| x.name == wirename}

      # 変数宣言のエラー処理
      if val.length > 1
        raise "#{wirename}が複数宣言されています。"
        exit
      elsif val.length < 1
        raise "#{filename}モジュールの #{wirename} が宣言されていません"
      end

      val = val[0]

      bus = val.bus unless val.nil?
      bus = [] if bus == "-1"

      arg = Variable.new(inout, bus, portname_s, comment)

      case(inout)
      when "input"
        submod.inputs << arg
      when "output"
        submod.outputs << arg
      else
        raise "submodule parse error"
      end

      if submod.arg_max_len < arg.name.length
        submod.arg_max_len = arg.name.length
      end
    end 

    @module.submodules << submod
  end

  #
  # moduleの引数部分をパースするメソッド
  #
  def parse_argArea(file, line)
    # 現在の行にモジュール開始の"("が含まれていない場合、見つかるまで飛ばす
    until line =~ /\(/
      line = file.gets
    end

    #"("の後すぐに改行している場合
    if line =~ /^\s*\(\s*$/
      line = file.gets
    else 
      line = line.sub("(", "")
    end

    # モジュール宣言終了の");"までparse
    while(true)
      if line =~ EXP_LINECOMMENT_BEGIN
        line = parse_lineComment(file, line)
      elsif line =~ EXP_MULTICOMMENT_BEGIN
        line = parse_multiComment(file, line)
      end

      # ARG AREAの終わり
      if line =~ EXP_ARGAREA_ENDONLY
        break
      elsif line =~ EXP_ARGAREA_END
        line = line.sub(");", "")
        parse_argarea_case(line)
        break
      end

    # メインarg parse
      parse_argarea_case(line)

      line = file.gets
    end
  end
  private :parse_argArea

  #
  # 引数部分の場合分け
  #
  def parse_argarea_case(line)
      case(line)
      when EXP_INPUT
        variables = VariableParse(line, :input)
        variables.each{|variable| 
          @module.inputs << variable 

          if @module.arg_max_len < variable.name.length
            @module.arg_max_len = variable.name.length
          end
        }
      when EXP_OUTPUT
        variables = VariableParse(line, :output)
        variables.each{|variable| 
          @module.outputs << variable

          if @module.arg_max_len < variable.name.length
            @module.arg_max_len = variable.name.length
          end
        }
      when EXP_OUTPUTREG
        variables = VariableParse(line, :output_reg)
        variables.each{|variable|
          @module.output_regs << variable 

          if @module.arg_max_len < variable.name.length
            @module.arg_max_len = variable.name.length
          end
        }
      when /^\s*/
      else
        raise ArgException, "parse of argument area failed. this line : #{line}"
      end
  end
  private :parse_argarea_case

  def parse_multiComment(file, line)
    until(line =~ EXP_MULTICOMMENT_END)
      line = file.gets
    end

    # */ の次の行から有効
    line = file.gets
    return line
  end
  private :parse_multiComment

  def parse_lineComment(file, line)
    line = file.gets
    return line
  end
  private :parse_lineComment

  #
  # 変数のパース
  #
  def VariableParse(line, type)

    # コメント処理
    if(line =~ /(\/\/.*)/ or line =~ /(\/\*.*\*\/)/)
      comment = $1
      line = line.split(/(\/\/)|(\/\*)/)[0]
    else
      comment = ""
    end

    # １行をトークンに切り分け 
    line = line.split(/\s|,|;/)
    line.delete("")

    # input等のタイプを除去
    line.shift

    names = []
    bus = []
    line.each do |item|
      case(item)
      when /\[(\d+):(\d+)\]/ # port
        bus << $1.to_i
        bus << $2.to_i
      when /\w+/  # name
        names << item
      end
    end

    vars = []
    names.each{|name| vars << Variable.new(type, bus, name, comment) }

    return vars
  end
  private :VariableParse

  #
  # 関数のパース
  #
  def parse_func(file, line)
    func = VariableParse(line, :function)[0]

    inputs = []
    line = file.gets
    while(line =~ EXP_INPUT)
      inputs << VariableParse(line, :input)
      line = file.gets
    end

    contents = []
    until(line =~ EXP_FUNC_END)
      contents << line
      line = file.gets
    end

    function = Function.new(func, inputs, contents)
    return function
  end
end

