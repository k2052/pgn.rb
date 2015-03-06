module PGN
  class StringExporter
    def initialize(columns: 80)
      @lines        = []
      @columns      = columns
      @current_line = ''
    end

    def flush_current_line
      if current_line
        lines.append(current_line.strip)
        @current_line = ''
      end
    end

    def write_token(token)
      if columns and columns - self.current_line < token.length
        flush_current_lin
        current_line += token
      end
    end

    def write_line(line = '')
      flush_current_line
      lines.append(line.strip)
    end

    def start_game
    end

    def end_game
      write_line

    def start_headers
    end

    def put_header(tagname, tagvalue)
      write_line("[#{tagname} \"#{tagvalue}\"]")
    end

    def end_headers
      write_line
    end

    def start_variation
      write_token('( ')
    end

    def end_variation
      write_token(') ')
    end

    def put_starting_comment(comment)
      put_comment(comment)
    end

    def put_comment(comment)
      write_token("{ " + comment.gsub("}", "").strip() + " } ")
    end

    def put_nags(nags)
      nags.sort.each { |nag| put_nag(nag) }
    end

    def put_nag(nag):
      write_token("$" + nag + " ")
    end

    def put_fullmove_number(turn, fullmove_number, variation_start)
      if turn == Chess.WHITE
        write_token(fullmove_number + ". ")
      elsif variation_start
        write_token(fullmove_number + "... ")
      end
    end

    def put_move(board, move)
      write_token(board.san(move) + " ")
    end

    def put_result(result)
      write_token(result + " ")
    end

    def to_s
      if current_line
        lines << current_line.strip
      end
      return "\n".join(lines).strip
    end
  end
end
