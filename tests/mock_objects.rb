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
  
require 'lib/core/player'
require 'lib/core/admin'
require 'flexmock'


module CallCounter
  def initialize_counter
    @calls = {}
    @calls.default = 0
#    watch(*(methods - Object.methods - ['record_call', 'was_called', 'watch', 'initialize_counter']))
  end
  


  def record_call(method_name)
    @calls[method_name.to_s] += 1
#    puts "recorded call to #{method_name} total:#{@calls[method_name]}"
  end
  
  def was_called(method_name)
#    puts "#{method_name} #{@calls[method_name.to_s]}"
    @calls[method_name.to_s] > 0
  end

  def reset_counter(method_name)
    @calls[method_name.to_s] = 0
  end

  def times_called(method_name)
    @calls[method_name.to_s]
  end

  module ClassMethods
    def watch(*method_names)
      for method_name in method_names
        watch_single(method_name)
      end
    end

    def watch_single(method_name)
      self.send(:define_method, method_name, Proc.new {|*args|
                  record_call(method_name)  
                  super(*args)
                })
    end

  end
end

class MockPlayer < Player
  include CallCounter
  extend CallCounter::ClassMethods
  attr_accessor :move_bandit_to, :select_resources_num, :select_nil_resources, :should_offer
  watch(:game_end, :add_cards, :player_rolled, :move_bandit)
  
  def initialize(*args)
    super(*args)
    @move_bandit_to = nil

    #Tell the player to only select a set number of resources    
    @select_resources_num = nil 
    
    #Tell the player to select a specific set of resources, or nil
    @select_nil_resources = false

    #used to tell this player to offer specific quotes
    @should_offer = []
    
    #   should_receive(:prices, :inform, :update_board, :placed_road, :placed_settlement, :placed_city)
    #   should_receive(:take_turn, :get_user_quotes, :color=)
    #   should_receive(:add_cards, :del_cards, :can_afford?).and_return(true)
   
    initialize_counter
  end

  def cards=(cards)
    @cards = cards
  end

  #This should be overidden in the implementations
  def get_user_quotes(wantList, giveList)
    quotes = @should_offer
    @should_offer = []
    return quotes
  end
  
  def move_bandit(old_hex)
    if @move_bandit_to
      loc = @move_bandit_to 
      @move_bandit_to = nil
      return loc
    end      
    @board.tiles.values.select{|t| !t.has_bandit }.first
  end
  
  #Ask the player to select some cards from a list.
  #This is used when a player must discard
  def select_resource_cards(cards, count)
    count = @select_resources_num if @select_resources_num
    return nil if @select_nil_resources
    selection = []
    list_copy = cards.dup
    (1..count).each do
      selection << list_copy.delete_at(rand(list_copy.length))
    end
    selection
  end  
  
  def select_player(players)
    other = players.find{|p| p != self}
    raise Exception.new("I'm being forced to select myself") unless other
    other
  end
end


class MockAdmin < Admin
  include CallCounter
  attr_accessor :currentTurn, :should_roll, :maxPoints

  def initialize(*args)
    super(*args)
    @should_roll = nil
    initialize_counter
  end
  
  def roll_dice(*args)
    if @should_roll
      roll_set_dice(@should_roll)
    else
      super(*args)
    end
  end
  
  def get_player(color)
	super
  end
  
  #Register a player or players with this game.
  def register(*players)
    for p in players
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
  
end


class MockBoard

end
