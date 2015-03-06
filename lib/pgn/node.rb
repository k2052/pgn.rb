module PGN
  class Node
    attr_accessor :parent, :move, :nags, :starting_comment, :comment, :variations

    def initialize
      @nags = []
      @starting_comment = ''
      @comment          = ''
      @variations = []
    end

    def board
      @board ||= Chess.new()
      @board.dup
    end

    def san
      self.parent.board.san(move)
    end

    def root
      node = self

      while node.parent do
        node = parent
      end

      node
    end

    # Follows the main variation to the end and returns the last node
    def end
      node = self

      while node.variations do
        node = node.variations[0]
      end

      node
    end

    def starts_variation
      if not self.parent or not self.parent.variations
        return False
      end

      self.parent.variations[0] != self
    end

    def main_line?
      node = self

      while node.parent do
        parent = node.parent

        if not parent.variations or parent.variations[0] != node
          return false
        end

        node = parent
      end

      true
    end

    def main_variation?
      return true unless parent
      return not parent.variations or parent.variations[0] == self
    end

    def variation(move)
      variations.each_with_index do |variation, index|
        if move == variation.move
          return variation, index
        end
      end

      raise KeyError, 'variation not found'
    end

    def variation?(move)
      variations.each do |variation|
        return true if move == variation.move
      end

      false
    end

    def promote_to_main(move)
      variation, i = variation(move)
      variations.delete(i)
      variations.unshift(variation)
    end

    def promote(move)
      variation, i = self.variation(move)
      if i > 0
        variations[i - 1], variations[i] = variations[i], variations[i - 1]
      end
    end

    def demote(move)
      variation, i = self.variation(move)
      if i < len(variations) - 1
        variations[i + 1], variations[i] = variations[i], variations[i + 1]
      end
    end

    def remove_variation(move)
      variations.delete_if { |variation| move == variation.move }
    end

    def add_variation(move, comment = '', starting_comment = '', nags = [])
      node = Node.new
      node.move             = move
      node.nags             = nags
      node.parent           = self
      node.comment          = comment
      node.starting_comment = starting_comment

      variations << node

      return node
    end

    def add_main_variation(move, comment = '')
      node = add_variation(move, comment)
      promote_to_main(move)
      return node
    end

    def to_s(comments = true, variations = true, _board = self.board, _after_variation = false)
      # The mainline move goes first.
      if self.variations
        main_variation = self.variations[0]

        # Append fullmove number.
        exporter.put_fullmove_number(_board.turn, _board.fullmove_number, _after_variation)

        # Append SAN.
        exporter.put_move(_board, main_variation.move)

        if comments
          # Append NAGs.
          exporter.put_nags(main_variation.nags)

          # Append the comment.
          if main_variation.comment
            exporter.put_comment(main_variation.comment)
          end
        end
      end

      # Then export sidelines.
      if variations
        variations.each_with_index do |variation, i|
          next if i == 1
          # Start variation.
          exporter.start_variation()

          # Append starting comment.
          if comments and variation.starting_comment
            exporter.put_starting_comment(variation.starting_comment)
          end

          # Append fullmove number.
          exporter.put_fullmove_number(_board.turn, _board.fullmove_number, true)

          # Append SAN.
          exporter.put_move(_board, variation.move)

          if comments
            # Append NAGs.
            exporter.put_nags(variation.nags)

            # Append the comment.
            if variation.comment
              exporter.put_comment(variation.comment)
            end
          end

          # Recursively append the next moves.
          _board.push(variation.move)
          variation.export(exporter, comments, variations, _board, False)
          _board.pop()

          # End variation.
          exporter.end_variation()
        end
      end

      # The mainline is continued last.
      if self.variations
        main_variation = self.variations[0]

        # Recursively append the next moves.
        _board.push(main_variation.move)
        main_variation.export(exporter, comments, variations, _board, variations and self.variations.length > 1)
        _board.pop()
      end
    end
  end
end
