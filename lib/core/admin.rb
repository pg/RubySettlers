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

require 'lib/core/board'
require 'lib/core/turn'
require 'lib/core/util'
require 'lib/core/iobserver'
require 'timeout'


# This error denotes that something occured against the rules.
class RuleException < RuntimeError; end


class TrustedObject

  def initialize(remote_object, local_object)
    @remote_object = remote_object
	@local_object = local_object
  end

  #Send the given method to the remote (original) object
  def self.allow_remote_method(method_name)
    self.send(:define_method, method_name.to_sym) { |*args|
      @remote_object.send(method_name.to_sym, *args)
    }
  end
  
  def self.allow_remote_methods(*method_names)
    method_names.each{|m| allow_remote_method(m) }
  end

  # Re-route this method to both the remote and local copy.
  # Returns the result from the local copy call.
  def self.allow_remote_and_local_method(method_name)
    self.send(:define_method, method_name.to_sym) { |*args|
      @remote_object.send(method_name.to_sym, *args)
      @local_object.send(method_name.to_sym, *args)
    }
  end
  
  def self.allow_remote_and_local_methods(*method_names)
    method_names.each{|m| allow_remote_and_local_method(m) }
  end

  # Re-route this method to the local copy only.
  def self.allow_local_method(method_name)
    self.send(:define_method, method_name.to_sym) { |*args|
      @local_object.send(method_name.to_sym, *args)
    }
  end

  def self.allow_local_methods(*method_names)
    method_names.each{|m| allow_local_method(m) }
  end
end

# This class is used locally by the admin.  It surrounds a possibly remote player.  
# Essentially, the Admin uses the Player object to keep track of a player's points, cards, pieces, etc.
# And we can't send those requests to a possibly remote player.
# So, this class allows us to determine which methods should be local, remote, or both.
class TrustedPlayer < TrustedObject
	def initialize(admin, originalPlayer)
		super(originalPlayer, Player.new(originalPlayer.name, admin))
	end
	
	allow_remote_and_local_methods :color=, :update_board, :next_turn, :game_end, :played_dev_card
	allow_remote_and_local_methods :placed_city, :placed_settlement, :placed_road, :player_moved_bandit
	allow_remote_and_local_methods :player_stole_card, :game_start, :add_cards, :del_cards
	allow_remote_and_local_methods :player_joined, :get_turn, :player_rolled, :player_received_cards, :addPiecesLeft
	allow_remote_methods :preferred_color, :take_turn, :move_bandit, :select_resource_cards, :select_player, :chat_msg
	allow_remote_methods :get_user_quotes
	#The admin ONLY calls local versions of the following methods.  These methods do NOT go over the wire.
	allow_local_methods :info, :name, :piecesLeft, :color, :get_played_dev_cards, :purchased_pieces
	allow_local_methods :count_resources, :cards, :resource_cards

	def to_s
		"Trusted: "+@local_object.to_s
	end
end


# Game Admin
# This object oversees the game play and enforces the rules.
class Admin

  attr_reader :currentTurn, :board, :availableColors,
              :gameThread, :maxPoints, :maxPlayers, :is_game_done, :observers
              
              
  # A Dice histogram.  This is a record of the dice rolls that occur in the game
  attr_reader :dice_hist

  # Create a new game Admin
  # This class only lasts for one single game.  Once it's over, you have to
  # create a new Admin for another game.
  # [board] The Board object that will be used in this game
  # [maxPlayers] The number of Players required to start the game.  
  # The game will NOT start untill all players have registered.
  # [maxPoints] The number of points to play to.
  def initialize(board, maxPlayers, maxPoints=10, turn_timeout=240)
  turn_timeout =0
    @prices = {
      City=>[OreType]*3 + [WheatType]*2,
      Settlement=>[WheatType, BrickType, WoodType, SheepType],
      Road=>[WoodType, BrickType],
      DevelopmentCard=>[OreType, SheepType, WheatType]    
    }
    @dice_hist = {}
    @dice_hist.default = 0
    @players=[]
    @observers=[]
    @board = board
    @maxPlayers = maxPlayers
    @availableColors = ["blue", "red", "white", "orange", "green", "brown"]
    @currentTurn = nil
    @maxPoints = maxPoints
    @is_game_done = false
    @gameThread = nil
    @turn_timeout = turn_timeout
    @game_mutex = Mutex.new
  end
  
  def is_game_in_progress
	return (!@is_game_done and @gameThread != nil)
  end
  
  #Returns a list of the two dice rolls
  def roll_dice
    roll_set_dice([rand(5)+1, rand(5)+1])
  end

  def get_price(pieceKlass)
	@prices[pieceKlass]
  end
  
  #Register a player or players with this game.
  def register(*players)
    for p in players
	  p = TrustedPlayer.new(self, p) # Wrap the player in a trusted version of a player.  This makes sure that there is a local copy keeping track of points, pieces, etc.
      @observers << p
      #tell the new player about all the other players
      @players.each{|op| p.player_joined(op.info) }
      @players << p
      if p.preferred_color and @availableColors.include?(p.preferred_color)
         p.color = p.preferred_color
         @availableColors.delete(p.preferred_color)
      else
        p.color = @availableColors.delete_at(rand(@availableColors.length))
      end
      @observers.each{|o| o.player_joined(p.info)}
      if @players.length == @maxPlayers
        @game_mutex.synchronize {
          start_game if @gameThread == nil
        }     
        return
      end
    end
  end

  # Register an IObserver to watch this game.
  def register_observer(observer)
    raise Exception('observer does not implement IObserver') unless observer.is_a?(IObserver)
    @observers << observer
  end

  #Starts the game thread with the registered players.
  def start_game
    @gameThread = Thread.new {  
      $log.info("Starting Game")
      $log.info("Using Board: #{@board.name}")
      $log.info("#{@players.size} players")
      
      @observers.each{|o| o.game_start}
      for p in @players
        p.update_board(@board)
      end

      begin
        roundCount = 0
        #setup
        for p in @players
          give_turn(SetupTurn, p)
        end
        for p in @players.reverse
          give_turn(SetupTurn, p)
        end
        until @is_game_done
          roundCount += 1
          for p in @players
            give_turn(Turn, p)
            @players.each{|pl| pl.next_turn(p)}
            check_for_winner
          end
          $log.info("Round #{roundCount} Highest Score:#{@players.map{|p| get_score(p)}.max}")  
        end
      rescue => err
        puts "Error in server ", err
        puts err.backtrace
      end
    }
  end
  
  #Check to see if someone one.  If so, end the game
  def check_for_winner
    winner = has_winner?
    if winner
      points = get_score(winner)
      $log.info("Game finished: winner#{winner} points:#{points}")
      @observers.each{|o| o.game_end(winner.info, points)}
      @is_game_done = true
    end
  end
  
  #Get the score of the given player
  def get_score(player)
    score = 0
    score += 2 if @board.has_longest_road?(player.color)
    larget_army = who_has_largest_army?
    score += 2 if larget_army and larget_army.color == player.color
    for n in @board.all_nodes
      if n.city and n.city.color==player.color
        score += n.city.getPoints
      end
    end
    score
  end
  
  def count_resource_cards(playerInfo)
    player = @players.find{|p| p.color.to_s == playerInfo.color.to_s}
    raise ArgumentError.new("Could not find player with color:#{playerInfo.color} in #{@players}") unless player
    count = 0
    RESOURCE_TYPES.each{|r| count += player.cards[r]}
    count    
  end
  
  def count_dev_cards(playerInfo)
    player = @players.find{|p| p.color == playerInfo.color}
    count = 0
    for klass, temp_count in player.cards
      count += temp_count if klass.is_a?(DevelopmentCard)
    end
    count  
  end
  
  # Gets a List of quotes from the bank and other users
  # Optionally takes a block that iterates through each quote as they come
  def get_quotes(player, wantList, giveList)
    raise ArgumentError.new("wantList:#{wantList}") if wantList.class != Array 
    raise ArgumentError.new("giveList:#{giveList}") if giveList.class != Array 
    result=[]
    giveList = giveList.flatten
    for w in wantList.flatten
      for g in giveList
        raise ArgumentError.new("want:#{w}") if w.class != Class
        raise ArgumentError.new("give:#{g}") if g.class != Class
        result += get_quotes_from_bank(player, w, g)
      end
    end
    result.reject!{|q| player.cards[q.receiveType] < q.receiveNum}
    result.each{|r| yield r} if block_given?
    
    #Add user quotes
    other_players(player){|p| 
      userQuotes = p.get_user_quotes(wantList, giveList)
      userQuotes.each{|r| yield r} if block_given?
      result += userQuotes
    }
    result
  end

  #Returns a List of Quote objects from the bank for a specific player
  def get_quotes_from_bank(player, wantType, giveType)
    #start with the bank's 4:1 offer
    result=[Quote.new(nil, giveType, 4, wantType, 1)]

    for p in @board.get_ports(player.color)
      if (p.type and p.type == giveType) or not p.type
        q = Quote.new(nil, giveType, p.rate, wantType, 1)  
        result << q if not result.include?(q)
      end
    end

    #Remove any redundant quotes
    #i.e. if result has a 2:1 quote, we don't need a 4:1 quote
    result.reject{|q| result.find{|q2| 
        q2.receiveNum < q.receiveNum and
          q2.giveType == q.giveType and
          q2.receiveType == q.receiveType}}
  end
  
  #Does this game have a winner yet.
  #If so, return the player that one, nil otherwise.
  def has_winner?
    for p in @players
      return p if get_score(p) >= @maxPoints
    end
    nil
  end

  #Finds the player with the largest army, or nil if no one has it.
  def who_has_largest_army?
    #The largest number of soldier cards
    highest_count = @players.map{|p| count_soliders(p)}.max
    who_has_the_most = []
    @players.each{|player|  
      who_has_the_most << player if count_soliders(player) == highest_count
    }
    
    if who_has_the_most.size == 1 and highest_count >= 3
      return who_has_the_most[0]
    else
      #multple people have the most soldiers
      nil
    end
  end

  #An iterator for all other players
  #[player] the player to exclude
  def other_players(player)
    @players.each{|p| yield p if p != player }
  end

  #Send a chat message to all users
  #[player] is who wrote the message
  def chat_msg(player, msg)
    for p in @players
      p.chat_msg(player, msg)
    end
  end

  #gets a player object based on the color.
  def get_player(color)
    raise Exception.new("Attempting to look for player with nil color") if color.nil?
	player = @players.find{|p| p.color == color}
	return player if (player) 
    raise Exception.new("Could not find player with color:#{color} in players:#{@players}")
  end

  private
  
  #how many soldiers has this player played?
  def count_soliders(player)
    player.get_played_dev_cards.select{|c| c.is_a?(SoldierCard)}.size
  end

  #Gets a piece from a player to place
  #raises an error if the player does not have the piece
  def get_player_piece(player, pieceType)
    if player.piecesLeft[pieceType] == 0
      raise RuleException.new("Player: "+player.name+" has no "+pieceType.to_s+"s left") 
    end
    player.piecesLeft[pieceType] -= 1
    pieceType.new(player.color)
  end

  #A helper method to give a turn to a player
  def give_turn(turn_class, player)
    unless @is_game_done #We need to check for the winner before we give the next player a turn
      $log.debug("**Giving #{turn_class} to #{player}")
      @currentTurn = turn_class.new(self, player, @board)
      begin
        #Give the player some time to make his/her move
        if @turn_timeout
          timeout(@turn_timeout) do
            begin
              observers.each{|o| o.get_turn(player.info, turn_class)}
              player.take_turn(@currentTurn)
              until @currentTurn.isDone; sleep(0.01); end
            rescue
              $log.error("Error occured during turn for #{player}.\n ERROR:#{$!}\n#{$!.backtrace.join('\n')}")
              #an Error occured on this player's turn.  KICK 'EM OUT
              begin
                player.chat_msg(player.info, "Error Occured: Now you've been kicked out")
              rescue; 
                puts $!
              end
              @players.delete(player)
            end
          end
        else
          observers.each{|o| o.get_turn(player.info, turn_class)}
          player.take_turn(@currentTurn)
          until @currentTurn.isDone; sleep(0.01); end
        end
        #Force the turn to be done
        @currentTurn.done unless @currentTurn.isDone
      rescue => err
        puts "Exception during turn for ", player.name, ": ", err
        puts err.backtrace
      end
      $log.debug('**give_turn() finished')
    end
  end
  
  #performs the actions after a dice roll using a given roll
  def roll_set_dice(roll)
    raise RuleException.new("roll_dice called without a currentTurn") unless @currentTurn
    acting_player = @currentTurn.player
    $log.info("#{acting_player} rolled (#{roll.join(', ')})")
    sum = roll.sum
    @observers.each{|o| o.player_rolled(acting_player.info, roll) }
    @dice_hist[sum] += 1 #increase the dice histogram
    if sum == 7
      #Each player must first get rid of half their cards if they more than 7
      @players.each do |p| 
        if p.count_resources > 7
          how_many_cards_to_lose = p.count_resources / 2
          chosen_cards = p.select_resource_cards(p.resource_cards.dup, how_many_cards_to_lose)
          raise RuleException.new("select resource cards returned nil") if chosen_cards.nil?
          raise RuleException.new("You did not select the right number of cards. expected:#{how_many_cards_to_lose} found:#{chosen_cards.size}") unless chosen_cards.size == how_many_cards_to_lose
          raise RuleException.new("select resource cards contained nil entries") if chosen_cards.compact.size != chosen_cards.size
          p.del_cards(chosen_cards)
        end
      end
          
      #Then move the bandit
      $log.info("Rolled a 7, move the bandit.")
      current_bandit_hex = @board.tiles.values.find{|t| t.has_bandit}
      new_hex = acting_player.move_bandit(current_bandit_hex)
      @currentTurn.move_bandit(new_hex)
    else
      for p in @players
        cards = @board.get_cards(sum, p.color)
        if cards.size > 0
          p.add_cards(cards)
          @observers.each{|o| o.player_received_cards(p.info, cards) }
        end
      end
    end
    roll
  end
  
  
end
