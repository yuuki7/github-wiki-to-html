# frozen_string_literal: true
# rbs_inline: enabled

require 'whatlanguage'

module Wikinder
  module GitHub
    class Wiki
      # Detects and normalizes the language code of a page.
      #
      # Chinese is normalized to one of two codes, 'zh' for
      # Simplified and 'zh-hant' for Traditional, because the site
      # treats the two scripts as separate languages and plain 'zh'
      # names the default script, Simplified. The script is decided
      # by counting characters that exist in only one of the two
      # scripts; text without any such character defaults to
      # Simplified, the larger of the two readerships.
      module Language
        # High-frequency characters written differently in the two
        # scripts. Only characters whose simplified and traditional
        # forms differ are listed, so shared characters never vote.
        SIMPLIFIED_ONLY = '国这为们个汉语学习发现现实现问题时间过还进远运近' \
                          '选择题写读听说书让识记讲许论证评访请课谁谢' \
                          '钱钟长门问间关开闭阳阴队际陆陈随难电响轻' \
                          '车马龙爱宝专东丝两严丧丰临丽举么乐乔习乡' \
                          '买乱争于亏云亚产亩亲亿仅从仑仓仪们价众优' \
                          '伙会伟传伤伦伪体余佣侠侣侥侦侧侨俭债倾偿' \
                          '储儿兑党兰共关兴兹养兽内冈册写军农冯冲决' \
                          '况冻净凉减凑凛几凤凫凭凯击凿刍划刘刚创删' \
                          '别刭剐剑剧劝办务动励劲劳势勋'
        TRADITIONAL_ONLY = '國這為們個漢語學習發現實現問題時間過還進遠運近' \
                           '選擇題寫讀聽說書讓識記講許論證評訪請課誰謝' \
                           '錢鐘長門問間關開閉陽陰隊際陸陳隨難電響輕' \
                           '車馬龍愛寶專東絲兩嚴喪豐臨麗舉麼樂喬習鄉' \
                           '買亂爭於虧雲亞產畝親億僅從侖倉儀們價眾優' \
                           '夥會偉傳傷倫偽體餘傭俠侶僥偵側僑儉債傾償' \
                           '儲兒兌黨蘭共關興茲養獸內岡冊寫軍農馮沖決' \
                           '況凍淨涼減湊凜幾鳳鳧憑凱擊鑿芻劃劉剛創刪' \
                           '別剄剮劍劇勸辦務動勵勁勞勢勳'

        #: (String?) -> String
        def self.call(text)
          return 'en' if text.nil? || text.strip.empty?

          code = WhatLanguage.language_iso(text)
          normalize(code&.to_s, text) || 'en'
        end

        # Normalizes a language code to the form the site uses as a
        # directory name. Chinese codes resolve to 'zh' or 'zh-hant'
        # (the script detected from +text+ when available); region
        # variants of the supported languages collapse to the plain
        # code. Unknown codes pass through unchanged.
        #: (String?, ?String?) -> String?
        def self.normalize(code, text = nil)
          return nil if code.nil? || code.empty?

          downcased = code.downcase
          return chinese_variant(downcased, text) if downcased == 'zh' || downcased.start_with?('zh-')

          base = downcased.split('-').first.to_s
          %w[en ja de ar].include?(base) ? base : code
        end

        #: (String, String?) -> String
        def self.chinese_variant(code, text)
          return 'zh-hant' if %w[zh-tw zh-hk zh-mo zh-hant].include?(code)
          return 'zh' if %w[zh-cn zh-sg zh-my zh-hans].include?(code)
          return 'zh' if text.nil? || text.empty?

          simplified = text.each_char.count { |char| SIMPLIFIED_ONLY.include?(char) }
          traditional = text.each_char.count { |char| TRADITIONAL_ONLY.include?(char) }
          traditional > simplified ? 'zh-hant' : 'zh'
        end
      end
    end
  end
end
