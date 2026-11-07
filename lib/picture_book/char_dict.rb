# frozen_string_literal: true

require 'json'

module PictureBook
  # 组 dict.json 里一个字的那一条。字段和键顺序都照线上发布版:
  #   {"ch","readings":[{"py","defs"}],"radicals","strokes","polyphonic","keyword"}
  # 读音由白名单决定(名单外一律单读音),释义走 char_definitions 表,
  # 部首/笔画走导出的 char-meta.json —— 两边拼起来才等于当初手工攒出的那份。
  module CharDict
    DATA_DIR = File.expand_path('data', __dir__)

    class << self
      # 小学阶段真·常用多音字:char -> 常用读音(按常用度排序)。
      # pinyin-pro 的 multiple:true 会把古音生僻音全列出来(女→rǔ、她→jiě),
      # 90 多个常用字会被误标成多音字,所以只认这份名单。
      def polyphone_whitelist
        @polyphone_whitelist ||= JSON.parse(File.read(File.join(DATA_DIR, 'polyphone-whitelist.json'), encoding: 'utf-8'))
      end

      # char -> [部首, 笔画数]（新华字典导出，14809 字）
      def char_meta
        @char_meta ||= JSON.parse(File.read(File.join(DATA_DIR, 'char-meta.json'), encoding: 'utf-8'))
      end

      def readings(char)
        common = polyphone_whitelist[char]
        if common && common.length > 1
          common
        else
          [Pinyin.char_default[char] || '']
        end
      end

      def polyphonic?(char)
        readings(char).length > 1
      end

      # defs_lookup: {"nǚ" => ["…", "组词：…"]}，由调用方从库里按字取好
      def entry(char, defs_lookup, keyword: false)
        meta = char_meta[char] || ['', '']
        {
          'ch' => char,
          'readings' => readings(char).map do |py|
            {
              'py' => py,
              'defs' => defs_lookup[py] || []
            }
          end,
          'radicals' => meta[0],
          'strokes' => meta[1],
          'polyphonic' => polyphonic?(char),
          'keyword' => keyword
        }
      end

      # 一本书的 dict.json：只收出现过的字，defs 一次把表读干净
      def build(chars, keyword_chars: [])
        defs = CharDefinition.for_chars(chars).group_by(&:character)
        chars.each_with_object({}) do |char, dict|
          by_py = (defs[char] || []).index_by(&:pinyin)
          lookup = by_py.transform_values(&:defs_array)
          dict[char] = entry(char, lookup, keyword: keyword_chars.include?(char))
        end
      end
    end
  end
end
