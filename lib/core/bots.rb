require 'lib/core/player'
require 'pp'

BOT_NAMES = ['Shatner', 'DoubleDouche', 'Q', 'Big Papi', 'Hans Gruber', 'Ghandi', 'C-3P0', 'Artoo']

module HighestProbablitySetup
  def do_setup_turn(turn)
    spots = @board.get_valid_settlement_spots(false, @color)
    spots.sort!{|a,b| a.get_hex_prob <=> b.get_hex_prob}
    turn.place_settlement!(*spots.last.coords)
    sx, sy,sn = spots.last.coords
    settlementNode = @board.getTile(sx,sy).nodes[sn]
    spots = @board.get_valid_road_spots(@color, settlementNode)
    turn.place_road!(*spots[0].coords)
    turn.done
  end
end


# Part of a bot that takes cards from random players without bias.
# It also places the bandit on anyone but itself.
module TakeCardsFromAnyone

  #Tell this player to move the bandit
  #[old_hex] the hex where the bandit currently sits
  #return a new hex
  def move_bandit(old_hex)
    preferred = @board.tiles.values.find{|t| 
      has_me = t.nodes.find{|n| n.city.color == @color if n.city}
      has_other = t.nodes.find{|n| n.city.color != @color if n.city}
      !t.has_bandit and !has_me and has_other
    }
    @admin.chat_msg(self, "gimme a card!") if @chatter
    return preferred if preferred
    preferred2 = @board.tiles.values.find{|t| 
      has_me = t.nodes.find{|n| n.city.color == @color if n.city}
      !t.has_bandit and !has_me
    }
    return preferred2 if preferred2
    @board.tiles.values.select{|t| !t.has_bandit }.first
  end

  #Ask the player to choose a player among the given list
  def select_player(players)
    other = players.find{|p| p != self}
    raise Exception.new("I'm being forced to select myself") unless other
    other
  end

end


class Bot < Player
  #[chatter] is a bool that determines if the bots talk or not
  attr_accessor :delay, :chatter

  def initialize(*args)
    super(*args)
    @chatter = false
    @delay = 0
	@game_finished = false
  end

  def game_start
    messages = ["Bring it on!!", "You guys are going down", "All Your base are belong to us"]
    msg = messages[rand(messages.size)]
    @admin.chat_msg(self, msg) if @chatter
  end

end

# An AI player that just chooses moves at random
class RandomPlayer < Bot
  include TakeCardsFromAnyone, HighestProbablitySetup

  def take_turn(turn)
    super

    sleep(@delay) if @delay
    if turn.is_setup
      do_setup_turn(turn)
    else
      turn.roll_dice

      for type, val in self.cards
        if self.cards[type] < 3
          giveCards = self.cards.keys.select{|c| self.cards[c] > 3 }
          unless (giveCards.empty?)
            qs = turn.get_quotes([type], giveCards)
            if qs.length > 0
              q = qs.sort{|a,b| a.receiveNum <=> b.receiveNum}.first
              turn.accept_quote(q) 
            end
          end
        end
      end
      
      if can_afford?([City]) and @piecesLeft[City] > 0
        spots = @board.get_valid_city_spots(@color)
        if spots.length > 0
          spots.sort!{|a,b| a.get_hex_prob <=> b.get_hex_prob}
          turn.place_city!(*spots.last.coords) 
          turn.taint
          @admin.chat_msg(self, "We built this city...on wheat and ore...") if @chatter
          $log.info("<BOT: #{name}: Bought City> ")
        end
      end

      if not @game_finished and can_afford?([Settlement]) and @piecesLeft[Settlement] > 0
        spots = @board.get_valid_settlement_spots(true, @color)
        if spots.length > 0
          spots.sort!{|a,b| a.get_hex_prob <=> b.get_hex_prob}
          turn.place_settlement!(*spots.last.coords) 
          turn.taint
          $log.info("<BOT: #{name}: Bought Settlement> ")
        end
      end
      
      if not @game_finished and can_afford?([Road]) and @piecesLeft[Road] > 0
        spots = @board.get_valid_road_spots(@color)
        longest_road = @board.has_longest_road?(@color)
        if @board.get_valid_settlement_spots(true, @color).length < 4
          if spots.length > 0
            turn.place_road!(*spots[0].coords)
          end
          turn.taint
          if not longest_road and @board.has_longest_road?(@color)
            $log.info("<BOT #{name}: Got longest road> ")
          end
        end
      end

      update_board(@board) if turn.tainted?
      turn.done
    end
  end
  
  # This bot will offer trades if it has more than 4 of 1 kind of card.
  def get_user_quotes(wantList, giveList)
    result=[]
    for w in wantList
      for g in giveList
        result << Quote.new(self.info, g, 1, w, 1) if self.cards[g] < 4 and self.cards[w] > 4
      end
    end
    result
  end
    
  #Ask the player to select some cards from a list.
  #This is used when a player must discard or resource 
  #monopoly or year of plenty
  def select_resource_cards(cards, count)
    selection = []
    list_copy = cards.dup
    (1..count).each do
      selection << list_copy.delete_at(rand(list_copy.length))
    end
    selection
  end
end



# A Bot that sets a goal for a single piece to purchase
# It then tries to trade and obtain cards to buy that piece.
# It's one step smarter than RandomPlayer
class SinglePurchasePlayer < Bot
  include TakeCardsFromAnyone, HighestProbablitySetup

  #[desired_piece] the class of the desired piece
  def initialize(*a)
    super
    @desired_piece = nil
    @cards_needed = []
    @delay = 0
  end

  def take_turn(turn)
    super
    sleep(@delay) if @delay
    if turn.is_setup
      do_setup_turn(turn)
    else
      turn.roll_dice
      @desired_piece = calculate_desired_piece(turn)
      @cards_needed = calculate_cards_needed(@desired_piece).uniq
		
      while true
        cardsIDontNeed = self.cards.to_flat_list || []

        if @desired_piece
          price = @admin.get_price(@desired_piece) || @admin.get_price(@desired_piece.to_s)
          cardsIDontNeed
          cardsIDontNeed = cardsIDontNeed.difference_without_uniq(price)
        end
        cardsIDontNeed = cardsIDontNeed.difference_without_uniq(@cards_needed)

        if (@cards_needed.size > 0 and cardsIDontNeed.size > 2)
          qs = turn.get_quotes(@cards_needed, cardsIDontNeed)
          if qs.size > 0
			q = qs.sort{|a,b| a.receiveNum <=> b.receiveNum}.first
            turn.accept_quote(q) if self.cards[q.receiveType] >= q.receiveNum
          else
            break
          end
        else
          break
        end
      end
      
      if @desired_piece and can_afford?([@desired_piece])
        place_desired_piece
      end
      turn.done
    end
  end

  # Ask this bot for a trade
  # This bot will try to get cards it needs for its desired piece
  def get_user_quotes(wantList, giveList)
    result = []
    return result if wantList.nil? or giveList.nil? or @cards_needed.nil?
    iWant = giveList & @cards_needed
    if !iWant.empty?
      #They're offering something I need
      iHaveToOffer = self.cards.to_flat_list & wantList - @cards_needed
      if !iHaveToOffer.empty?
        for want in iWant
          for have in iHaveToOffer
             result << Quote.new(self.info, want, 1, have, 1)
          end
        end
      end
    end
    result
  end
    
  # Ask the player to select some cards from a list.
  # This is used when a player must discard or resource monopoly or year of plenty
  def select_resource_cards(cards, count)
    selection = []
    #First try to only get rid of cards that i don't need
    remaining_cards = cards - @cards_needed
    while remaining_cards.size > 0 and selection.size < count do
      chosen_card = remaining_cards.delete_at(rand(remaining_cards.size))
      selection << chosen_card
      initial_index = cards.index(chosen_card)
      cards.delete_at(initial_index)
    end

    #Then, if you still have to get rid of cards, pick at random
    remaining_cards = cards
    while selection.size < count
      selection <<  remaining_cards.delete_at(rand(remaining_cards.size))
    end
    selection
  end

  private

  #calculate which piece to try for based on the current turn.
  def calculate_desired_piece(turn)
    if @piecesLeft[City] > 0
      spots = @board.get_valid_city_spots(@color)
      return City if spots.length > 0
    end
    if @piecesLeft[Settlement] > 0
      spots = @board.get_valid_settlement_spots(true, @color)
      return Settlement if spots.length > 0
    end
    if @piecesLeft[Road] > 0
      spots = @board.get_valid_road_spots(@color)
      return Road if spots.length > 0
    end
    $log.warn("#{self} can't figure out where to build anything. Pieces left:#{@piecesLeft}")
  end

  # Calculate the cards that this player needs to get to purchase
  # the desired_piece
  # Class -> Array of Cards
  def calculate_cards_needed(klass)
    cards_needed = []
    price = @admin.get_price(klass)
    return cards_needed if price.nil?
    price_hash = price.to_count_hash
    for card, count in price_hash
      need = count - self.cards[card]
      cards_needed << [card] * need if need > 0
    end
    cards_needed.flatten
  end

  # Place your desired piece
  # This method assumes that the player can afford the piece
  def place_desired_piece
    if @desired_piece == Road
      spots = @board.get_valid_road_spots(@color)

      # Organize the edges by the number of adjecent roads
      # and whether or not they have cities on them
      spots = spots.sort_and_partition{|e| e.get_adjecent_edges.size}
      spots.map!{|chunk| chunk.partition{|e| e.nodes.all?{|n| !n.city} }}
      spots.flatten!

      raise 'No Valid Spots' if spots.length == 0
      # Find a spot that will increase your longest road
      firstEdge = @board.edges.find{|e| e.road and e.road.color == @color}
      longest = @board.find_longest_road(firstEdge)
      foundGoodSpot = false
      for spot in spots
        @board.place_road!(Road.new(@color), *spot.coords)
        new_longest = @board.find_longest_road(firstEdge)
        @board.remove_road!(*spot.coords)
        if new_longest > longest
          @currentTurn.place_road!(*spot.coords)
          foundGoodSpot = true
          break
        end
      end
      #Then, try to pick an edge that has no cities on it.
      unless foundGoodSpot
        @currentTurn.place_road!(*spots.first.coords)
      end
    elsif @desired_piece == Settlement
      spots = @board.get_valid_settlement_spots(true, @color)
      spots.sort!{|a,b| a.get_hex_prob <=> b.get_hex_prob}
      raise 'No Valid Spots' if spots.length == 0
      spots.sort!{|a,b| a.get_hex_prob <=> b.get_hex_prob}
      @currentTurn.place_settlement!(*spots.last.coords) 
    elsif @desired_piece == City
      spots = @board.get_valid_city_spots(@color)
      spots.sort!{|a,b| a.get_hex_prob <=> b.get_hex_prob}
      raise 'No Valid Spots' if spots.length == 0
      spots.sort!{|a,b| a.get_hex_prob <=> b.get_hex_prob}
      @admin.chat_msg(self, "We built this city...on wheat and ore...") if @chatter
      @currentTurn.place_city!(*spots.last.coords) 
    else
      raise "Invalid desired_piece: #{@desired_piece}"
    end
    update_board(@board)
  end
end
