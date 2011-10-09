require 'pp'

module ExpConst
  #Area
  EXP_LINECOMMENT_BEGIN = /^\s*\/\//
  EXP_MULTICOMMENT_BEGIN = /^\s*\/\*/
  EXP_MULTICOMMENT_END = /\*\//
  EXP_ARGAREA_BEGIN = /^\s*module/
  EXP_ARGAREA_END = /\);/
  EXP_ARGAREA_ENDONLY = /^\s*\);/
  EXP_FUNC_BEGIN = /^\s*function/
  EXP_FUNC_END = /^\s*endfunction/

  # Args
  EXP_INPUT = /^\s*input/
  EXP_OUTPUT = /^\s*output/
  EXP_OUTPUTREG = /^\s*output\s+reg/
  EXP_WIRE = /^\s*wire/
  EXP_REG = /^\s*reg/

  # comment
  EXP_LINECOMMENT = /\/\/.*$/
  EXP_MULTILINECOMMENT = /\/\*.*\*\//m
end

class VarTypeException < StandardError; end
class ParseException < StandardError; end
class ArgException < StandardError; end

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
  attr_accessor :inputs,:outputs,:wires,:regs,:functions,:contents
end

class Function
  def initialize(func, inputs, contents)
    @func = func
    @inputs = inputs
    @contents = content
  end
  attr_accessor :inputs,:contents
  attr_reader :func
end

class Variable
  include ExpConst
  def initialize(type, bus, name, comment)
    case(type)
    when EXP_INPUT
      @type = "input"
    when EXP_OUTPUT
      @type = "output"
    when EXP_OUTPUTREG
      @type = "output reg"
    when EXP_WIRE
      @type = "wire"
    when EXP_REG
      @type = "reg"
    else 
      raise VarTypeException, "variable error, unknown type : #{@type}"
    end
    @bus = bus
    @name = name
    @comment = comment
  end
  attr_reader :type,:bus,:name,:comment
end

class Parser
  include ExpConst
  def initialize(parseFileName)
    @fileName = parseFileName
    @module = Module.new
  end
  attr_reader :module

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
        variable = VariableParse(line)
        @module.wires << variable
      when EXP_REG
        variable = VariableParse(line)
        @module.regs << variable
      else
        @module.contents << line
      end
    end
  end

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

  def parse_argarea_case(line)
      case(line)
      when EXP_INPUT
        variable = VariableParse(line)
        @module.inputs << variable
      when EXP_OUTPUT
        variable = VariableParse(line)
        @module.outputs << variable
      when EXP_OUTPUTREG
        variable = VariableParse(line)
        @module.output_regs << variable
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

  def VariableParse(line)
    finish = line =~ 
    /^\s*(input|output\s+reg|output|function)                 # type
    (\s*\[(\d+:\d+)\]|)                                   # bus
    \s*(.*)                                          # name
    \s*(,|\)|;|)                                        # end mark
    \s*(#{EXP_LINECOMMENT}|#{EXP_MULTILINECOMMENT}|)  # comment
      /x

    pp line, finish
    if finish.nil? || finish == false
      raise ParseException, "parse failed, this line : #{line}"
    end

    type = $1

    # バス配線を整数値に変更する処理
    bus_str = $2.split(":")
    bus = []
    bus_str.each{|num_str| bus << num_str.to_i }

    name = $3
    comment = $5

    var = Variable.new(type,bus,name,comment)

    return var
  end
  private :VariableParse

  def parse_func(file, line)
    func = VariableParse(line)

    inputs = []
    line = file.gets
    while(line =~ EXP_INPUT)
      inputs << VariableParse(line)
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

class Printer
end

#INPUTFILE = ARGV[0]
INPUTFILE = "sdrd_SPIctrl.v"
parser = Parser.new(INPUTFILE)
parser.parse
pp parser.module
