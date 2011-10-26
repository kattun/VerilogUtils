require 'pp'

#
# Verilogのパースで使う正規表現の定数
#
module ExpConst
  #Area
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
# Verilogのモジュールを表現するクラス
#
class Module
  def initialize
    @inputs = []
    @outputs = []
    @output_regs = []
    @wires = []
    @regs = []
    @functions = []
    @contents = []
  end

# inputクラスの配列
attr_accessor :inputs
# outputクラスの配列
attr_accessor :outputs
# wireクラスの配列
attr_accessor :wires
# regクラスの配列
attr_accessor :regs
# functionクラスの配列
attr_accessor :functions
# その他の中身
attr_accessor :contents
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
# Verilogをパースするクラス
#
class Parser
  include ExpConst

  # パースエラー
  class ParseException < StandardError; end
  # 変数定義のエラー
  class ArgException < StandardError; end

  #
  #引数
  #parseFileName
  #パースするファイル名
  #
  def initialize(parseFileName)
    @fileName = parseFileName
    @module = Module.new
  end

  # パース結果を保持するmoduleクラス
  attr_reader :module

  #
  # パースを実行
  #
  def parse
    file = open(@fileName, "r")

    while(line = file.gets)
      case(line)
      when EXP_ARGAREA_BEGIN
        parse_argArea(file,line)
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
        @module.contents << line
      end
    end
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
        variables.each{|variable| @module.inputs << variable }
      when EXP_OUTPUT
        variables = VariableParse(line, :output)
        variables.each{|variable| @module.outputs << variable }
      when EXP_OUTPUTREG
        variables = VariableParse(line, :output_reg)
        variables.each{|variable| @module.output_regs << variable }
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

    pp vars
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

#
# moduleクラスを出力するクラス
#
class Printer
end

#INPUTFILE = ARGV[0]
 INPUTFILE = "sdrd_SPIctrl.v"
 parser = Parser.new(INPUTFILE)
 parser.parse

 #pp parser.module.inputs
