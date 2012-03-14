# ------------------------------------------------------------------------------- #
# Title         : Auto Submodule Generator
# Project       : Verilog Utility
# File          : main.rb
# Author        : Katsuyuki SEKI <seki@islab.cs.tsukuba.ac.jp>
# ------------------------------------------------------------------------------- #
# Description   : 
#
#----------# 
# 開発環境
#----------# 
# ruby version 1.9.2p180
# 文字コード : utf-8
# 
#----------# 
# 注意事項
#----------# 
# トップモジュール・サブモジュール共にutf-8でないと動きません。
#
# 動作確認していませんが、ruby 1.8.7以降なら動くと思います。
#
# 処理前にcpコマンドでバックアップを作成しますが、エラーやバグ等で
# 失敗する可能性があります。自己責任で御利用ください。
#
# バックアップは一つ前の状態のものしか残らないので注意してください。
#
# ------------------------------------------------------------------------------- #
# usage         :
#
# #######################################################
# あらかじめparse.rb内のExpConstモジュールの定数、TAGに
# 自動生成したいサブモジュールの接頭辞を設定します。
# #######################################################
#
# 起動コマンド  :
# $ ruby main.rb トップモジュール.v
# ------------------------------------------------------------------------------- #
# Revisions        :
# 2010/11/06      Created
# 2011/12/23      コメント、動作を修正
# ------------------------------------------------------------------------------- #
#
#
require 'pp'
require 'kconv'
require './parse.rb'
require './module.rb'
require 'fileutils'

INPUTFILE = ARGV[0]

def make_submod(mod)
  readMod = Module.new
  parser = Parser.new
  contents = []

  # 既存のサブモジュールファイルを読み込み
  begin
    open(mod.name, "r")

    readMod = parser.parse(mod.name)

    # 既存のサブモジュールのinput, output, outputregを変更
    readMod.inputs = mod.inputs
    readMod.outputs = mod.outputs
    readMod.arg_max_len = mod.arg_max_len

    # バックアップ作成
    FileUtils::mkdir_p("backup")
    FileUtils::cp(readMod.name, "backup/")

    readMod.write
  rescue => ex
    pp ex
    `touch #{mod.name}`
    mod.write
  end

end

parser = Parser.new
mod = Module.new
topmod = parser.parse(INPUTFILE)
topmod.submodules.each do |sbmod|
  make_submod(sbmod)
end

# input, outputの信号csvファイルを作成
# printer = Printer.new
# mod = Module.new
# printer.make_inoutSeat("test.csv", parser.parse(INPUTFILE) )
