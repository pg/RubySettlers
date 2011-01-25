#  Copyright (C) 2007 John J Kennedy III
#
#  This program is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation; either version 3 of the License, or
#  (at your option) any later version.
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with this program.  If not, see <http://www.gnu.org/licenses/>.
  
#TODO: Document this
class Turn
  attr_reader :hasRolled, :isDone, :admin, :player, :is_setup

  def initialize(admin, player, board)
    @admin = admin
    @player = player
    @hasRolled = false
    @isDone = false
    @board = board
    @roadConstraint = true
    @allQuotes=[] #all the quotes received in this turn
    @is_setup = false
    @listeners = []
  end

  def register_listener(listener)
    @listeners << listener
  end

  def roll_dice
    @hasRolled = true
    check_state("Dice roll")
    admin.roll_dice
  end
  
  def buy_development_card
    check_state("Development card bought")
    success = pay_for(DevelopmentCard)
    if success
      card = @admin.board.card_pile.get_card
      @player.add_cards([card.class])
      return card
    else
      throw RuleException("You don't have enough resources to buy this card.")
    end
  end

  # Gets a list of quotes from the bank and other users
  # Optionally takes a block that iterates through each quote as they come
  #(List(CardType), List(CardType)) -> List(Quote)
  # This is from the current player's point of view.  He wants the want list and will give the giveList
  def get_quotes(wantList, giveList)
    raise TypeError.new("WantList contains non-resources: #{wantList.map{|o| o.class}}") unless wantList.all?{|w| w <= Resource}
    raise TypeError.new("GiveList contains non-resources: #{giveList.map{|o| o.class}}") unless giveList.all?{|w| w <= Resource}
	wantList.uniq!
	giveList.uniq!
	
    #Make sure that the player has enough cards to make the offer
    for giveType in giveList
      if @player.cards[giveType] == 0
        puts @player
        raise RuleException.new("You can't offer cards that you don't have: Offering #{giveType} but has #{@player.cards}")
      end
    end
	
    check_state("get_quotes")
    quotes = @admin.get_quotes(@player, wantList, giveList)

    quotes.each{|q| yield q} if block_given?
    @allQuotes += quotes
    quotes
  end

  #returns a list of Quote objects from the bank
  #(CardType, CardType) -> List(Quote)
  def get_quotes_from_bank(wantType, giveType)
    check_state("get_quotes_from_bank")
    @admin.get_quotes_from_bank(@player, wantType, giveType)
  end

  #trade cards
  # Quote -> void
  def accept_quote(quote)
    raise RuleException.new("Not sending a Quote object. object:'#{quote}'") unless quote.is_a?(Quote)
    check_state("accept quote")
    if not @allQuotes.include?(quote)
      raise RuleException.new("Attempting to accept a quote that hasn't been received:#{quote} Other quotes: #{@allQuotes}")
    end

   #Check to make sure that everybody has enough cards
    if @player.cards[quote.receiveType] < quote.receiveNum
      pp "Receive #{quote.receiveType} num:#{quote.receiveNum}"
      pp @player.cards
      raise RuleException.new("You don't have enough cards for this quote: #{quote}")
    end
    bidder_player = nil
    if quote.bidder
      bidder_player = get_player(quote.bidder.color)
      if bidder_player.cards[quote.giveType] < quote.giveNum
        pp bidder_player.cards
        raise RuleException.new("Bidder #{bidder_player} doesn't have enough cards for this quote: #{quote}")
      end
    end
    
    #Make the actual trade
    $log.debug("#{@player} is accepting a trade from #{bidder_player || 'The Bank'} #{quote.giveNum} #{quote.giveType} for #{quote.receiveNum} #{quote.receiveType}")
    @player.add_cards([quote.giveType]*quote.giveNum)
    @player.del_cards([quote.receiveType]*quote.receiveNum)
    if bidder_player
      bidder_player.add_cards([quote.receiveType]*quote.receiveNum)
      bidder_player.del_cards([quote.giveType]*quote.giveNum)
    end
  end

  def place_road!(x, y, edgeNum )
    $log.debug("#{@player} is trying to buy a road")
    raise RuleException.new("Game is Over") if @admin.is_game_done
    check_state("Road placed")
    tile = @board.getTile(x,y)
    if not tile or edgeNum < 0 or edgeNum > 5
      raise RuleException.new("Invalid edge: #{x} #{y} #{edgeNum}")
    end
    edge = tile.edges[edgeNum]
    
    if not @board.get_valid_road_spots(@player.color).include?(edge)
      raise RuleException.new("Invalid Road Placement #{x} #{y} #{edgeNum}")
    end

    #if a player uses a roadBuilding card, then his purchasedRoads > 0
    #they shouldn't pay for the road in this case.
    should_pay = true
    if @player.purchased_pieces > 0
      should_pay = false
      @player.purchased_pieces -= 1
    end
    road = purchase(Road, should_pay)
    @board.place_road!(road, x, y, edgeNum)
    @admin.observers.each{|o| o.placed_road(@player.info, x, y, edgeNum) }
    @admin.check_for_winner
  end
  alias :place_road :place_road!


  def place_settlement!(x, y, nodeNum )
    $log.debug("#{@player} is trying to buy a settlement")
    raise RuleException.new("Game is Over") if @admin.is_game_done
    check_state("Settlement placed")
    node = validate_node(x, y, nodeNum)
    sett = purchase(Settlement)
    if not @board.get_valid_settlement_spots(@roadConstraint, @player.color).include?(node)
      raise RuleException.new("Invalid Settlement Placement #{x} #{y} #{nodeNum}")
    end
    @board.place_city!(sett, x, y, nodeNum)
    @admin.observers.each{|o| 
      o.placed_settlement(@player.info, x, y, nodeNum) 
    }
    @admin.check_for_winner
  end
  alias :place_settlement :place_settlement!
  
  def get_valid_settlement_spots
	return @board.get_valid_settlement_spots(@roadConstraint, @player.color)
  end

  def place_city!(x, y, nodeNum )
    $log.debug("#{@player} is trying to buy a city")
    raise RuleException.new("Game is Over") if @admin.is_game_done
    check_state("City placed")
    node = validate_node(x, y, nodeNum)
    city = purchase(City)
    player.addPiecesLeft(Settlement, 1) #Put the settlement back
    
    if node.city and node.city.color == player.color
      @board.place_city!(city, x, y, nodeNum) 
      @admin.observers.each{|o| 
        o.placed_city(@player.info, x, y, nodeNum) 
      }
      @admin.check_for_winner
      return
    end
    raise RuleException.new("Invalid City Placement #{x} #{y} #{nodeNum}")
  end
  alias :place_city :place_city!

  def done
    check_state("Turn ended")
    unless @player.purchased_pieces == 0
      raise RuleException.new("You cannot end a turn while there are purchased pieces to place")
    end
    
    #Are there still active cards that should have been played?
    if active_cards.find{|c| c.single_turn_card }
      raise RuleException.new("There are still active cards: #{active_cards}")
    end
    @isDone = true
    begin
      @listeners.each{|l| l.finished_turn(self)}
    rescue
      puts $!
    end
    $log.debug("Turn done")
  end

  def play_development_card!(card)
    raise RuleException.new("Game is Over") if @admin.is_game_done
    unless card.is_a?(DevelopmentCard)
      raise RuleException.new("expected an object of type DevelopmentCard got #{card.class} instead") 
    end
    #Preconditions
    unless @player.cards[card.class] > 0
      raise RuleException.new("Player does not own the card being played.")
    end
    raise RuleException.new("Turn is done") if @isDone
    if card.class != SoldierCard and not @hasRolled
      raise RuleException.new("#{card.class} played before dice were rolled") 
    end
    card.use(self)
    @player.del_cards([card.class])
    @player.played_dev_card(card)
    @admin.check_for_winner
  end
  

  #Move the bandit to a new tile.
  #This is called by the admin and the soldier card
  def move_bandit(new_tile)
    raise 'new_tile cannot be nil' if new_tile.nil?
    #TODO: implement rule checking here so people can't move the 
    #bandit whenever they want.
    @board.move_bandit(new_tile)

    @admin.observers.each{|o| 
       o.player_moved_bandit(@player.info, new_tile) 
    }
    
    #Take a card from a player
    
    #the colors of the cities touching the new tile
    touching_colors = new_tile.nodes.map{|n| n.city.color if n.city}.compact.uniq
    touching_players = touching_colors.map{|c| get_player(c).info} - [@player.info]
    
    unless touching_players.empty?
      if touching_players.size == 1
        player_to_take_from = touching_players.first      
      else
        player_to_take_from = @player.select_player(touching_players)
        raise RuleException.new("You must select a player") if player_to_take_from.nil?
      end
  
      take_random_card(player_to_take_from)
      @admin.observers.each{|o| o.player_stole_card(@player, player_to_take_from, 1)}
    end
    
  end

  #The list of action cards currently in play. i.e. SoldierCards etc.
  def active_cards
    @player.get_played_dev_cards.select{|card| not card.is_done }
  end

  private

  #Take a random card from another player and add it to your own cards
  #If player has no cards, do nothing
  def take_random_card(victim)
    raise 'player cannot be nil' if victim.nil?
    victim = get_player(victim.color)
    available_resources = victim.resource_cards
    puts "Could not take a random card from #{victim}" if available_resources.empty?
    $log.debug("Could not take a random card from #{victim}") if available_resources.empty?
    return if available_resources.empty?
    
    res = available_resources[rand(available_resources.length)]
    raise Exception.new('Resource cannot be nil') if res.nil?
    victim.del_cards([res])
    @player.add_cards([res])
  end

  #A helper method to get a player based on a color
  def get_player(color)
	@admin.get_player(color)
  end

  # Make this player pay for and account for 1 less piece.
  # This method will raise an exception if they can't actually buy the piece
  # [pieceKlass] the Class object of the piece
  # [should_pay] should the player pay for the given piece?
  #              This is safe because this method is private
  def purchase(pieceKlass, should_pay=true)
    #Check that the player has any pieces left
    if @player.piecesLeft(pieceKlass) == 0
      raise RuleException.new("player: #{@player.name} has no #{pieceKlass}s left")
    end
    @player.addPiecesLeft(pieceKlass, -1)
    piece = pieceKlass.new(@player.color)

    #Now, try to pay for the piece
    
    begin
      pay_for(pieceKlass) if should_pay
    rescue(RuleException)
      @player.addPiecesLeft(pieceKlass, 1) # Put the piece back
      raise
    end
    piece
  end

  #makes a player pay for a piece
  def pay_for(piece)
    success = @player.del_cards(@admin.get_price(piece))
    raise RuleException.new("#{@player.name}: Insufficient cards for a #{piece}") if !success
    success
  end

  def check_state(s)
    raise RuleException.new(s+" before dice were rolled") if not @hasRolled 
    raise RuleException.new("Turn is done") if @isDone
    raise RuleException.new("All card actions must be finished.") if active_cards.size > 0
  end

  #validate that the given node DOES exist
  def validate_node(x, y, nodeNum)
    tile = @board.getTile(x,y)
    if tile and nodeNum >= 0 and nodeNum <= 5
      return tile.nodes[nodeNum] 
    end
    raise RuleException.new("Invalid node: #{x} #{y} : #{nodeNum}")
  end
end


class SetupTurn < Turn
  attr_reader :placed_settlement, :placed_road

  def initialize(admin, player, board)
    super
    @placed_road, @placed_settlement = nil, nil
    @roadConstraint = false
    @is_setup = true
  end

  def can_place_road?() true end
    
  def place_road!(x, y, edgeNum)
    raise RuleException.new("Too many roads placed in setup") if @placed_road
    raise RuleException.new("Must place settlement before road") if not @placed_settlement

    @placed_road = [x,y,edgeNum]
    e = @board.getTile(x,y).edges[edgeNum]

    sx, sy,sn = @placed_settlement
    settlementNode = @board.getTile(sx,sy).nodes[sn]
    validSpots = @board.get_valid_road_spots(@player.color, settlementNode)
    raise RuleException.new("Road must touch the settlement just placed") if not validSpots.include?(e)
    super
  end

  def place_settlement!(x, y, nodeNum )
    raise RuleException.new("Too many settlements placed in setup") if @placed_settlement
    @placed_settlement = [x,y,nodeNum]
    super

    #A Player gets cards for the 2nd settlement he places
    settlement_count = @board.all_nodes.select{|n| n.city if n.city and n.city.color == @player.color}.size
    raise RuleException.new('Bad Game state.  Wrong # of settlements placed') unless [1,2].include?(settlement_count)
    if settlement_count == 2
      node = @board.getNode(x,y,nodeNum)
      touching_hexes = node.hexes.reject{|h| h.card_type == DesertType}
      resources = touching_hexes.map{|h| h.get_card}
      @player.add_cards(resources) unless resources.empty?
    end    
    
    @placed_settlement
  end  

  def done
    if not @placed_settlement or not @placed_road
      raise RuleException.new("Setup ended before completion")
    end
    super
  end

  def roll_dice() raise RuleException.new("Cannot roll dice during setup") end
  def place_city!() raise RuleException.new("Cannot place city during setup") end
  def buy_development_card() raise RuleException.new("Cannot buy development card during setup") end
  def check_state(s) raise RuleException.new("Turn is done") if @isDone; end

  def pay_for(piece) end
end


#Represents a quote for trading cards
# This is basically the Bidder saying "I'll give you giveType for receiveType"
# The Trador then accepts the quote afterwards
class Quote
  attr_reader :bidder, :receiveType, :receiveNum, :giveType, :giveNum

  #bidder is a PlayerInfo Object
  def initialize(bidder, receiveType, receiveNum, giveType, giveNum)
    @bidder = bidder #nil bidder denotes the bank(the admin)
    @receiveType = receiveType
    @receiveNum = receiveNum
    @giveType = giveType
    @giveNum = giveNum
    raise ArgumentError.new("Bad receiveType:#{receiveType.class}") if receiveType.class != Class
    raise ArgumentError.new("Bad giveType:#{giveType}") if giveType.class != Class

  end
  
  def to_s
    "<Quote #{receiveNum} #{receiveType} for #{giveNum} #{giveType} from #{bidder}>"
  end
  
  def ==(q2)
    q2.bidder == @bidder and 
      q2.receiveType.to_s == @receiveType.to_s and q2.receiveNum == @receiveNum and
      q2.giveType.to_s == @giveType.to_s and q2.giveNum == @giveNum
  end
end
