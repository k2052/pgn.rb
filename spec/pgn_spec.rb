describe PGN::Game do
  describe '#read_game' do
    let(:pgn) { File.open(File.join(__dir__ 'data/games/kasparov-deep-blue-1997.pgn')) }

    it 'reads games from a file' do
      first_game  = PGN.read_game(pgn)
      second_game = PGN.read_game(pgn)
      third_game  = PGN.read_game(pgn)
      fourth_game = PGN.read_game(pgn)
      fifth_game  = PGN.read_game(pgn)
      sixth_game  = PGN.read_game(pgn)

      expect(PGN.read_game(pgn)).to eq(nil)
      pgn.close

      expect(first_game.headers["Event"]).to eq "IBM Man-Machine, New York USA"
      expect(first_game.headers["Site"]).to eq "01"
      expect(first_game.headers["Result"]).to eq "1-0"

      expect(second_game.headers["Event"]).to eq "IBM Man-Machine, New York USA"
      expect(second_game.headers["Site"]).to eq "02"

      expect(third_game.headers["ECO"]).to eq "A00"

      expect(fourth_game.headers["PlyCount"]).to eq "111"

      expect(fifth_game.headers["Result"]).to eq "1/2-1/2"

      expect(sixth_game.headers["White"]).to eq "Deep Blue (Computer)"
      expect(sixth_game.headers["Result"]).to eq "1-0"
    end

    it 'handles a comment eol' do
      pgn = StringIO.new(%Q(
      1. e4 e5 2. Nf3 Nc6 3. Bc4 Bc5 4. c3 Nf6 5. d3 d6 6. Nbd2 a6 $6 (6... Bb6 $5 {
      /\ Ne7, c6}) *))

      game = PGN.read_game(pgn)

      # Seek the node after 6.Nbd2 and before 6...a6.
      node = game
      while node.variations and not node.has_variation(Chess::Move.from_uci("a7a6")) do
        node = node.variation(0)
      end

      # Make sure the comment for the second variation is there.
      expect(node.variation(1).nags.include?(5)).to eq(true)
      expect("/\\ Ne7, c6").to eq node.variation(1).comment
    end

    it 'handles a variation stack' do
      # Ignore superfluous closing brackets.
      pgn  = StringIO.new("1. e4 (1. d4))) !? *")
      game = PGN.read_game(pgn)

      expect(game.variation(0).san).to eq 'e4'
      expect(game.variation(1).san).to eq 'd4'

      # Ignore superfluous opening brackets.
      pgn  = StringIO.new("((( 1. c4 *")
      game = PGN.read_game(pgn)
      expect(game.variation(0).san).to eq 'c4'
    end

    it 'handles a starting comment' do
      pgn  = StringIO.new("{ Game starting comment } 1. d3")
      game = PGN.read_game(pgn)
      expect(game.comment).to eq "Game starting comment"
      expect(game.variation(0).san).to eq "d3"

      pgn  = StringIO.new("{ Empty game, but has a comment }")
      game = PGN.read_game(pgn)
      expect(game.comment).to eq "Empty game, but has a comment"
    end

    it 'handles annotation symbols' do
      pgn  = StringIO.new("1. b4?! g6 2. Bb2 Nc6? 3. Bxh8!!")
      game = PGN.read_game(pgn)

      node = game.variation(0)
      expect(node.nags.include?(PGN.NAG_DUBIOUS_MOVE)).to eq(true)
      expect(node.nags.length).to eq 1

      node = node.variation(0)
      expect(node.nags.length).to eq 0

      node = node.variation(0)
      expect(node.nags.length).to eq 0

      node = node.variation(0)
      expect(node.nags.include?(PGN.NAG_MISTAKE)).to eq(true)
      expect(len(node.nags), 1)

      node = node.variation(0)
      expect(node.nags.include?(PGN.NAG_BRILLIANT_MOVE)).to eq true
      expect(node.nags.length).to eq 1
    end
  end

  describe '.scan_headers' do
    it 'scans the headers' do
      pgn = File.open(File.join(__dir__, 'data/games/kasparov-deep-blue-1997.pgn'))

      offsets << []
      while offset, headers = PGN.scan_headers(pgn)
        offsets << offset if headers["Result"] == "1/2-1/2"
      end

      first_drawn_game_offset = offsets[0]
      pgn.seek(first_drawn_game_offset)
      first_drawn_game = PGN.read_game(pgn)
      expect(first_drawn_game.headers["Site"]).to eq '03'
      expect(first_drawn_game.variation(0).move).to eq Chess::Move.from_uci("d2d3")
    end
  end

  describe '#add_variation' do
    it 'traverses a tree without exploding' do
      game = PGN::Game
      node = game.add_variation(Chess::Move(Chess.E2, Chess.E4))
      alternative_node = game.add_variation(Chess.D2, Chess.D4)
      end_node = node.add_variation(Chess::Move(Chess.E7, Chess.E5))

      expect(game.root).to eq game
      expect(node.root).to eq game
      expect(alternative_node.root).to eq game
      expect(end_node.root).to eq game

      expect(game.end).to eq end_node
      expect(node.end).to eq end_node
      expect(end_node.end).to eq end_node
      expect(alternative_node.end).to eq alternative_node

      expect(game.is_main_line).to be_true
      expect(node.is_main_line).to be_true
      expect(end_node.is_main_line).to be_true
      expect(alternative_node.is_main_line).to be_true

      expect(game.starts_variation).to be_true
      expect(node.starts_variation).to be_true
      expect(end_node.starts_variation).to be_true
      expect(alternative_node.starts_variation).to be_true
    end
  end

  describe '#premote and #demote' do
    it 'can promote and demote nodes' do
      game = PGN::Game.new
      a = game.add_variation(Chess::Move.new(Chess.A2, Chess.A3))
      b = game.add_variation(Chess::Move.new(Chess.B2, Chess.B3))

      expect(a.is_main_variation).to be_true
      expect(b.is_main_variation).to be_true
      expect(game.variation(0)).to eq(a)
      expect(game.variation(1)).to eq(b)

      game.promote(b)
      expect(b.is_main_variation).to be_true
      expect(a.is_main_variation).to be_true
      expect(game.variation(0)).to eq(b)
      expect(game.variation(1)).to eq(a)

      game.demote(b)
      expect(a.is_main_variation())

      c = game.add_main_variation(Chess::Move.new(Chess.C2, Chess.C3))
      expect(c.is_main_variation).to be_true
      expect(a.is_main_variation).to be_true
      expect(b.is_main_variation).to be_true
      expect(game.variation(0)).to eq c
      expect(game.variation(1)).to eq a
      expect(game.variation(2)).to eq b
    end
  end

  describe '#to_s' do
    let(:game) do
      game = PGN::Game.new
      game.comment = "Test game:"
      game.headers["Result"] = "*"

      e4 = game.add_variation(game.parse_san("e4"))
      e4.comment = "Scandinavian defense:"

      e4_d5 = e4.add_variation(e4.parse_san("d5"))

      e4_h5 = e4.add_variation(e4.parse_san("h5"))
      e4_h5.nags.add(PGN.NAG_MISTAKE)
      e4_h5.starting_comment = "This"
      e4_h5.comment = "is nonesense"

      e4_e5 = e4.add_variation(e4.board().parse_san("e5"))
      e4_e5_Qf3 = e4_e5.add_variation(e4_e5.board().parse_san("Qf3"))
      e4_e5_Qf3.nags.add(PGN.NAG_MISTAKE)

      e4_c5 = e4.add_variation(e4.board().parse_san("c5"))
      e4_c5.comment = "Sicilian"

      e4_d5_exd5 = e4_d5.add_main_variation(e4_d5.board().parse_san("exd5"))
      game
    end

    let(:pgn) do
      %Q(
      [Event "?"]
      [Site "?"]
      [Date "????.??.??"]
      [Round "?"]
      [White "?"]
      [Black "?"]
      [Result "*"]

      { Test game: } 1. e4 { Scandinavian defense: } d5 ( { This } 1... h5 $2
      { is nonesense } ) ( 1... e5 2. Qf3 $2 ) ( 1... c5 { Sicilian } ) 2. exd5 *
      )
    end

    context 'wgen headers, comments and variations are set to false' do
      it 'returns no header, comments or variations' do
        expect(game.to_s(headers: false, comments: false, variations: false)).to eq('1. e4 d5 2. exd5 *')
      end
    end

    context 'when headers and comments are set to false' do
      it 'returns moves and variations but no headers or comments' do
        expect(game.to_s(headers: false, comments: false)).to eq('1. e4 d5 ( 1... h5 ) ( 1... e5 2. Qf3 ) ( 1... c5 ) 2. exd5 *')
      end
    end

    context 'when no options are set' do
      it 'returns it all' do
        expect(game.to_s).to eq pgn
      end
    end
  end

  describe '#setup' do
    it 'setups a position when given a fen string' do
      game = PGN::Game.new
      fen = "rnbqkbnr/pp1ppp1p/6p1/8/3pP3/5N2/PPP2PPP/RNBQKB1R w KQkq - 0 4"
      game.setup(fen)
      expect(game.headers["FEN"]).to eq fen
      expect(game.headers["SetUp"]).to eq '1'
    end
  end

  describe '#promote_to_main' do
    it 'promotes a a move to the main variation' do
      e4 = Chess::Move.from_uci("e2e4")
      d4 = Chess::Move.from_uci("d2d4")

      node = PGN::Game.new()
      node.add_variation(e4)
      node.add_variation(d4)
      .each do {}
      expect(node.variations.map { |variation| variation.move }).to eq [e4, d4]

      node.promote_to_main(d4)
      expect(node.variations.map { |variation| variation.move }).to eq [d4, e4]
    end
  end
end
