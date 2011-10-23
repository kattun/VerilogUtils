class VeriParser
# 演算子の優先順位
  prechigh
    nonassoc UMINUS     #非結合
    left '*' '/'
    left '+' '-'
  preclow
  options no_result_var  # 左辺値をアクションブロックの最後値とするオプション
rule
  module        : MODULE NAME '(' args ')' contents ENDMODULE {return 0}

  args          | args ',' {return 0}
                | arg {return 0}

  arg           : INPUT PORT NAME {@module.inputs << Variable.new(val[0], val[1], val[2]); return 0}
                | OUTPUT PORT NAME
                | OUTPUT REG PORT NAME

  contents      :
end

---- header
# $Id: calc-ja.y 2112 2005-11-20 13:29:32Z aamine $
require '../module.rb'
---- inner
  
  def initialize
    @module = Module.new
  end

  def evaluate(str)
        require 'pp'
    @tokens = []
    pp str
    until str.empty?
      case str
      when /\A\s+/
        ;
      when /\A\s*module/
        @tokens.push [:MODULE, 0]

      when /\A\s*endmodule/
        @tokens.push [:ENDMODULE, 0]

      when /\A\s*\W/
        @tokens.push [$&, $&]

      when /\A\s*input/
        @tokens.push [:INPUT, 0]

      when /\A\s*output/
        @tokens.push [:OUTPUT, 0]

      when /\A\s*reg/
        @tokens.push [:REG, 0]

      when /\A\s*wire/
        @tokens.push [:WIRE, 0]

      when /\A\s*\[(\d+:\d+)\]/
        @tokens.push [:PORT, [$1.to_i, $2.to_i]]

      when /\A\s*\w+/
        @tokens.push [:NAME, $&]

      when /\A\d+/
        @tokens.push [:NUMBER, $&.to_i]

      when /\A.|\n/
        s = $&
        @tokens.push [s, s]
      end
      str = $'
    end
    @tokens.push [false, '$']
    do_parse
  end

  def next_token
    @tokens.shift
  end

---- footer
