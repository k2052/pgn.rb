module PGN
  class Game
    attr_accessor :headers

    def initialize
      headers = {}
      headers['Event']  = '?'
      headers['Site']   = '?'
      headers['Date']   = '????.??.??'
      headers['Round']  = '?'
      headers['White']  = '?'
      headers['Black']  = '?'
      headers['Result'] = '*'
    end

    def board
      if headers.include? "FEN"
        return Chess.new(fen: headers["FEN"])
      else
        return Chess.new
      end
    end

    def setup(fen)
      headers['SetUp'] = '1'
      headers['FEN']   = fen
    end

    def to_s(exporter = StringExporter.new(), headers = true, comment = true, variations = true)
      exporter.start_game()

      if headers
        exporter.start_headers

        headers.items.each do |tagname, tagvalue|
          exporter.put_header(tagname, tagvalue)
        end

        exporter.end_headers()
      end

      if comments and @comment
        exporter.put_starting_comment(self.comment)
      end

      Game.new(self).to_s(exporter, comments, variations)

      exporter.put_result(self.headers["Result"])
      exporter.end_game()
    end
  end
end
