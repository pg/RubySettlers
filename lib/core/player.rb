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

require 'lib/core/iobserver'
require 'lib/core/util'

#This encapsulates all the readable info about a player
#This object is essentially a struct that lets other players refer to each other
#This way, other players will only know so much information about each other
class PlayerInfo
  attr_accessor :name, :color
  def initialize(player=nil)
    if player
      @name = player.name
      @color = player.color
    end
  end

  def to_s
    "<PlayerInfo name:#{@name} color:#{@color}>"
  end

  def ==(o)
    return false if o.nil?
    return (o.name == @name and o.color == @color)
  end
  
  def eql?(o)
    self == o
  end
  
  def hash
    (name.to_s + color.to_s).hash
  end
end

#Base class for a player.  This class should not be used directly, it should be subclassed.
class Player
  include IObserver

  attr_accessor :color
  attr_accessor :purchased_pieces
  attr_reader :name, :admin
  attr_reader :msgLog, :currentTurn, :board, :preferred_color, :game_finished

  def initialize(name, admin, cities=4, settlements=5, roads=15)
    #The number of all cards owned by this player. <CardClass, count>
    @cards={}
    @cards.default = 0
    @admin = admin
    @name = name
    @color = nil
    @purchased_pieces = 0
    @piecesLeft={City=>cities, Settlement=>settlements, Road=>roads}
    @piecesLeft.default=0
    @played_dev_cards = []
    @msgLog = []
    @preferred_color = nil
    @cards_mutex = Mutex.new
    @pieces_mutex = Mutex.new
    @listeners = [] #These listeners are used by the UI 
  end
  
  def get_played_dev_cards
    @played_dev_cards
  end
  
  #Notifys the player that they have offically played a development card
  def played_dev_card(card)
    @played_dev_cards << card
  end

  def copyPiecesLeft
    @pieces_mutex.synchronize{
      @piecesLeft.dup
    }
  end

  def piecesLeft(pieceKlass)
    @pieces_mutex.synchronize{
      @piecesLeft[pieceKlass]
    }
  end

  def addPiecesLeft(pieceKlass, amount)
    @pieces_mutex.synchronize{
      @piecesLeft[pieceKlass] += amount
    }
  end

  #Send a message to this player
  def chat_msg(player, msg)
    @msgLog << msg
    $log.debug "MESSAGE FOR:(#{name}:#{color})  #{msg}"
  end

  #TODO: make this not get re-created every time  
  def info
    PlayerInfo.new(self)
  end
 
  #Notify this player that it is someone elses turn.
  #This method should be overriden
  def next_turn(player_info)
  end

  def cards
    @cards_mutex.synchronize {
      return @cards
    }
  end

  # Tell this player that they received more cards.
  # [cards] an Array of card types
  def add_cards(cards)
    @cards_mutex.synchronize {
      raise ArgumentError.new("cards is empty") if cards.empty?
      cards.each do |c| 
        raise ArgumentError.new("cards contains a nil element") if c.nil?
        raise ArgumentError.new("value is nil for: #{c}") if @cards[c].nil?
      end
      $log.debug("#{name} Adding cards #{cards.join(',')}")
      cards.each{|c| @cards[c] += 1 }
    }
  end

  # Remove cards from this players hand
  # Return false the there aren't sufficent cards
  # [cards] an Array of card types
  def del_cards(cards)
    @cards_mutex.synchronize {
      $log.debug("#{name} Losing cards #{cards.join(',')}")
      sum = {}
      sum.default = 0
      cards.each{|c| sum[c] += 1}
      for card, count in sum
        #fail for insuffecient cards
        raise RuleException.new('Player does not have enough cards to delete') if count > @cards[card]
      end
      #otherwise...
      for card, count in sum
        @cards[card] -= count
      end
    }
  end

  def build_card_string(card_list)
      "Implement me!"
  end

  #Can this player afford the given pieces?
  #[pieces] an Array of buyable piece classes (Cities, Settlements, etc.)
  def can_afford?(pieces)
    raise ArgumentException.new("pieces cannot be nil") if pieces.nil?
    cost={}
    cost.default=0
    for piece in pieces
      cards = @admin.get_price(piece) || @admin.get_price(piece.to_s)
      for card in cards
        cost[card] += 1
      end
    end
    for card, count in cost
      return false if @cards[card] < count
    end
    return true
  end

  def ==(o)
	self.color == o.color
  end
  
  #This method should be extended
  def take_turn(turn)
    @currentTurn = turn
    @listeners.each{|l| 
      l.got_turn(turn)
      turn.register_listener(l)
    }
  end

  #This should be overidden in the implementations
  def get_user_quotes(wantList, giveList)
    []
  end
  
  #Tell this player to move the bandit
  #[old_hex] the hex where the bandit currently sits
  #return a new hex
  #This method should be overridden
  def move_bandit(old_hex)
    raise 'Not Implemented'
  end
    
  #Ask the player to select some cards from a list.
  #This is used when a player must discard or resource 
  #monopoly or year of plenty
  #This method should be overridden
  def select_resource_cards(cards, count)
    raise 'Not Implemented'
  end

  #Ask the player to choose a player among the given list
  #This method should be overridden
  def select_player(players)
    raise 'Not Implemented'
  end

  ##IObserver methods##

  #This is called by the admin anytime another player moves the bandit
  #[player] the player that moved the bandit
  #[new_hex] the hex that the bandit is now on.
  def player_moved_bandit(player_info, new_hex)
    boards_hex = @board.getTile(*new_hex.coords)
    @board.move_bandit(new_hex) unless boards_hex.has_bandit
    nil   
  end

  #This is called by the admin anytime a player receives cards.
  #[player] the player that received the cards
  #[cards] a list of Card Classes
  def player_received_cards(player_info, cards)
  end

  #This is called by the admin when anyone rolls the dice
  #[player] the acting player
  #[roll] A list (length 2) of the numbers that were rolled
  def player_rolled(player_info, roll)
  end
  
  #This is called by the admin whenever a player steals cards from another player
  #[theif] the player who took the cards
  #[victim] the player who lost cards
  def player_stole_card(theif, victim, num_cards)
  end
  
  #Notify the observer that the game has begun  
  def game_start
    @game_finished = false
  end
  
  #Inform the observer that the game has finished.
  #[player] the player who won
  #[points] the number of points they won with.
  def game_end(winner, points)
    @game_finished = true
  end
  
  #Inform this observer that a player has joined the game.
  def player_joined(player_info)
  end
  
  #Inform this observer that it is the given player's turn
  def get_turn(player_info, turn_class)
  end
  
  # Update this observer's version of the board
  # [board] the new version of the board
  def update_board(board)
    @board = board
    nil
  end

  # Notify this observer that a road was placed
  # [player] The player that placed the road
  # [x, y, edge] The edge coordinates
  def placed_road(player_info, x, y, edge)
    @board.place_road!(Road.new(player_info.color), x, y, edge)
  end

  # Notify this observer that a settlement was placed
  # [player] The player that placed the settlement
  # [x, y, node] The node coordinates
  def placed_settlement(player_info, x, y, node)
    @board.place_city!(Settlement.new(player_info.color), x, y, node)
  end

  # Notify this observer that a city was placed
  # [player] The player that placed the city
  # [x, y, node] The node coordinates
  def placed_city(player_info, x, y, node)
    @board.place_city!(City.new(player_info.color), x, y, node)
  end  
  
  #How many resource cards does this player have?
  def count_resources
    resource_cards.size
  end
  
  #Gets all the resource cards this user has
  #returns a list of ResourceTypes
  def resource_cards
    @cards.map{|t, c| [t] * c if t.superclass == Resource }.flatten.compact
  end

  def register_listener(listener)
    @listeners << listener
  end
  
  def to_s
    %Q{<Player name="#{name}" color="#{color}"/>}
  end
  
  #for some reason, this was throwing a stack level too deep
  def inspect
    to_s
  end  
end

#A simple listener class that gets notified when a player gets his turn and when he's done
class PlayerListener
  def got_turn(turn)
  end
 
  def finished_turn(turn)
  end
end
