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


#Base class for the state of the player GUI
#Uses the State pattern
class WxPlayerState
  def initialize(player, last_state)
    @player = player
    @lastPiece = nil
    @last_state = last_state #the previous state
    @main_frame = RealMainFrame.instance
    @all_buttons = [@main_frame.roll_button, @main_frame.trade_button, 
                    @main_frame.done_button, @main_frame.buy_dev_card_button,
                    @main_frame.soldier_button, @main_frame.monopoly_button,
                    @main_frame.yearofplenty_button, @main_frame.roadbuilding_button]
    validate
    $log.info("Changing state to: #{self}")
  end

  def get_temp_piece(x, y); nil; end
  def on_board_left_click(event); end
  
  #return a list of symbols of the buttons to be enabled
  def enable_actions; []; end

  def validate
    @all_buttons.each{|b| b.disable; b.hide;}    
    menu_bar = @main_frame.get_menu_bar
    enable_actions.each{|name|  
      button = @main_frame.send(name.to_s+'_button')
      button.show
      button.enable
      menu_id = @main_frame.send(name.to_s+'_menu_item')
      menu = menu_bar.find_item(menu_id)
      menu.enable
    }
    @main_frame.actions_panel.layout
    @main_frame.actions_panel.update
  end
end

#This state indicates that it is not the user's turn, they can't do anything.
class WaitingState < WxPlayerState; end

#This state indicates that the player has just been given a new turn
class NewTurnState < WxPlayerState
  def on_board_left_click(event)
    if @main_frame.board_panel.temp_piece
      msg = Wx::MessageDialog.new(@main_frame, "You have to roll the dice first!", "Oops!", Wx::OK)
      msg.show_modal
    end
  end
  
  def enable_actions
    valid_actions = [:roll]
    valid_actions << :soldier if @player.cards[SoldierCard] > 0
    valid_actions
  end
end


# This state indicates that the player HAS rolled the dice, 
# but isn't done his turn
class RolledDiceState < WxPlayerState

  def get_temp_piece(x, y)
    piece = @main_frame.board_panel.get_temp_piece(x, y)
    if piece and @player.can_afford?([piece.pieceKlass]) 
      if piece.pieceKlass == Road
        valid_spots = @player.board.get_valid_road_spots(@player.color).map{|n| n.coords}
        return piece if valid_spots.include?(piece.coords) 
      elsif piece.pieceKlass == City
        valid_spots = @player.board.get_valid_city_spots(@player.color).map{|n| n.coords}
        return piece if valid_spots.include?(piece.coords) 
      elsif piece.pieceKlass == Settlement
        valid_spots = @player.board.get_valid_settlement_spots(true, @player.color).map{|n| n.coords}
        return piece if valid_spots.include?(piece.coords)
      end
    #account for purchased pieces (Road Building Card)
    elsif piece and @player.purchased_pieces > 0 and piece.pieceKlass == Road
      valid_spots = @player.board.get_valid_road_spots(@player.color).map{|n| n.coords}
      return piece if valid_spots.include?(piece.coords) 
    end
    return nil
  end

  def on_board_left_click(event)
    piece = @main_frame.board_panel.temp_piece
    if piece
      if piece.pieceKlass == Road
        @player.currentTurn.place_road!(*piece.coords)
      elsif piece.pieceKlass == City
        @player.currentTurn.place_city!(*piece.coords)
      elsif piece.pieceKlass == Settlement
        @player.currentTurn.place_settlement!(*piece.coords)
      end
    end
    @main_frame.board_panel.refresh
  end

  def enable_actions
    valid_actions = [:trade, :done]
    valid_actions << :buy_dev_card if @player.can_afford?([DevelopmentCard])
    valid_actions << :soldier if @player.cards[SoldierCard] > 0
    valid_actions << :monopoly if @player.cards[ResourceMonopolyCard] > 0
    valid_actions << :yearofplenty if @player.cards[YearOfPlentyCard] > 0
    valid_actions << :roadbuilding if @player.cards[RoadBuildingCard] > 0
    valid_actions
  end
end

#This state indicates that the player is in the setup phase
class SetupTurnState < RolledDiceState

  def get_temp_piece(x, y)
    turn = @player.currentTurn
    return unless turn and turn.is_setup
    piece = @main_frame.board_panel.get_temp_piece(x, y)
    if piece
      if turn.placed_settlement
        settlement_node = @player.board.getNode(*turn.placed_settlement)
        valid_spots = @player.board.get_valid_road_spots(@player.color, settlement_node).map{|n| n.coords}
        return piece if piece.pieceKlass == Road and valid_spots.include?(piece.coords) 
      else
        valid_spots = @player.board.get_valid_settlement_spots(false, nil).map{|n| n.coords}
        return piece if piece.pieceKlass == Settlement and valid_spots.include?(piece.coords) 
      end
    end
  end

  def on_board_left_click(event)
    super
    #implicit done when you place a road during setup
    if !@player.currentTurn.isDone and @player.currentTurn.placed_road
      @player.currentTurn.done
    end   
  end

  def enable_actions() []; end
end


#This state indicates that the player is in the middle of moving the bandit.
class MovingBanditState < WxPlayerState
  attr_reader :chosen_hex

  def initialize(old_hex, *a)
    super(*a)
    @old_hex = old_hex
    @chosen_hex = nil
  end

  def get_temp_piece(x, y)
    hex = @main_frame.board_panel.isTouchingHex?(x,y, @main_frame.board_panel.proximity*6)
    if hex and hex != @old_hex and hex.card_type != DesertType
      hex
    else 
      nil
    end
  end

  def on_board_left_click(event)
    @chosen_hex = @main_frame.board_panel.temp_piece
  end
end

#This state indicates that the player has just been given a new turn
class PlayingRoadbuiling < RolledDiceState
  def enable_actions
    []
  end
  
  def on_board_left_click(event)
    super
    @player.change_state_to(RolledDiceState) if @player.purchased_pieces == 0
  end
end
