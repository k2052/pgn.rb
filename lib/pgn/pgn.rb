class Pgn
  def initialize(io:)
    read_game(io)
  end

  def self.read_game(io:)
    game = Game.new

    found_game    = false
    found_content = false

    while line do
      if line.strip.blank? or line.strip.start_with?('%')
        line = io.readline
        next
      end

      found_game = true

      # Read header tags.
      tag_match = TAG_REGEX.match(line)
      if tag_match
        game.headers[tag_match.group(1)] = tag_match.group(2)
      else
        break
      end

      line = io.readline
    end

    # Get the next non-empty line.
    while !line.strip and line do
      line = io.readline
    end

    # Movetext parser state.
    starting_comment = ''
    variation_stack  = [game]
    board_stack      = [game.board]
    in_variation     = false

    while line do
      read_next_line = true

      if !line.strip and found_game and found_content
        return game
      end


      matches = line.scan(MOVETEXT_REGEX)
      matches.each do |match|
        token = match.group(0)

        if token.startswith("%"):
          # Ignore the rest of the line.
          line = io.readline()
          next
        end

        found_game = true

        if token.start_with?('{')
          # Consume until the end of the comment.
          line = token[1]
          comment_lines = []
          while line and !line.include? '}' do
            comment_lines << line.strip()
            line = io.readline()
          end

          end_index = line.index '}'

          comment_lines << line[:end_index]

          if line.include? '}'
            line = line[end_index:]
          else
            line = ''
          end

          if in_variation or not variation_stack[-1].parent
            # Add the comment if in the middle of a variation or
            # directly to the game.
            if variation_stack[-1].comment
              comment_lines.insert(0, variation_stack[-1].comment)
            end

            variation_stack[-1].comment = "\n".join(comment_lines).strip
          else
            # Otherwise it is a starting comment.
            if starting_comment:
              comment_lines.insert(0, starting_comment)
            end
            starting_comment = "\n".join(comment_lines).strip()
          end

          # Continue with the current or the next line.
          if line
            read_next_line = false
          end

          break
        elsif token.startswith("$")
          # Found a NAG.
          variation_stack[-1].nags << token[1:].to_a
        elsif token == "?"
          variation_stack[-1].nags << NAG_MISTAKE
        elsif token == "??"
          variation_stack[-1].nags << NAG_BLUNDER
        elsif token == "!"
          variation_stack[-1].nags << NAG_GOOD_MOVE
        elsif token == "!!"
          variation_stack[-1].nags << NAG_BRILLIANT_MOVE
        elsif token == "!?"
          variation_stack[-1].nags << NAG_SPECULATIVE_MOVE
        elsif token == "?!"
          variation_stack[-1].nags << NAG_DUBIOUS_MOVE
        elsif token == "("
          # Found a start variation token.
          if variation_stack[-1].parent
            variation_stack.append(variation_stack[-1].parent)

            board = board_stack[-1].dup
            board.pop
            board_stack << board

            in_variation = false
          end
        elsif token == ")"
          # Found a close variation token. Always leave at least the
          # root node on the stack.
          if variation_stack.length > 1
            variation_stack.pop()
            board_stack.pop()
          end
        elsif ["1-0", "0-1", "1/2-1/2", "*"].include? token and variation_stack.length == 1:
          # Found a result token.
          found_content = True

          # Set result header if not present, yet.
          unless game.headers.include? "Result"
            game.headers["Result"] = token
          end
        else
          # Found a SAN token.
          found_content = true

          # Replace zeros castling notation.
          if token == "0-0"
            token = "O-O"
          elsif token == "0-0-0"
            token = "O-O-O"
          end

          # Parse the SAN.
          begin
            move = board_stack[-1].parse_san(token)
            in_variation = true
            variation_stack[-1] = variation_stack[-1].add_variation(move)
            variation_stack[-1].starting_comment = starting_comment
            board_stack[-1].push(move)
            starting_comment = ''
          rescue
          end
        end

      line = io.readline if read_next_line
    end

    return game if found_game
    return nil
  end


  def scan_headers(io:)
    in_comment   = false
    game_headers = nil
    game_pos    = nil

    last_pos = io.tell
    line     = io.readline

    while line do
      # Skip single line comments.
      if line.start_with?("%")
        last_pos = io.tell
        line = io.readline
        next
      end

      # Reading a header tag. Parse it and add it to the current headers.
      if not in_comment and line.start_with?("[")
        tag_match = TAG_REGEX.match(line)
        if tag_match
          unless game_pos
            game_headers = {}
            game_headers["Event"]  = "?"
            game_headers["Site"]   = "?"
            game_headers["Date"]   = "????.??.??"
            game_headers["Round"]  = "?"
            game_headers["White"]  = "?"
            game_headers["Black"]  = "?"
            game_headers["Result"] = "*"

            game_pos = last_pos
          end

          game_headers[tag_match.group(1)] = tag_match.group(2)

          last_pos = io.tell
          line     = io.readline
          next
        end
      end

      # Reading movetext. Update parser state in_comment in order to skip
      # comments that look like header tags.
      if (not in_comment and line.include?("{")) or (in_comment and line.include?("}"))
        in_comment = line.index("{") > line.index("}")
      end

      # Reading movetext. If there were headers, previously, those are now
      # complete and can be yielded.
      unless game_pos
        return game_pos, game_headers
        game_pos = nil
      end

      last_pos = io.tell()
      line    = io.readline()
    end
    
    # Yield the headers of the last game.
    unless game_pos
      return game_pos, game_headers
    end
  end
end
