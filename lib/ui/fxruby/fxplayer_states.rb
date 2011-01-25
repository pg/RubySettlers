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

require 'fox16'
require 'fox16/colors'
include Fox


#Base class for the state of the player GUI
#see the State pattern
class FXPlayerState
  def initialize(fxplayer)
    @player = fxplayer
    @lastPiece = nil
  end

  def on_canvas_left_click(sender, sel, event)
    @player.frame.update
  end

  def on_canvas_mouse_motion(sender, sel, event)
    piece = @player.getTouchingPiece(event.win_x,event.win_y, @player.proximity, @player.currentTurn)
    @player.draw_board(piece) if piece or (@lastPiece != nil and piece == nil)
    @lastPiece = piece
  end

  def validate_action_panel(ap)
    buttons = [ap.done_button, ap.trade_button, ap.roll_button, ap.dev_card_button]
    buttons.each{|b| b.disable}
  end

  def validate_action_widget(widget)
    widget.setup_turn = false
    widget.move_bandit = false
    actions = [widget.dice, widget.done, widget.trade, widget.buy_dev_card,
               widget.play_soldier_card, widget.play_resource_monopoly_card,
               widget.play_road_building_card, widget.play_year_of_plenty_card]
    actions.each{|act| act.enabled = false }
  end
end


#This state indicates that the player has just been given a new turn
class NormalTurnState < FXPlayerState
  def on_canvas_left_click(sender, sel, event)
    piece = @player.getTouchingPiece(event.win_x, event.win_y, @player.proximity, @player.currentTurn)
    if piece
      FXMessageBox::warning(@player.app, FXMessageBox::MBOX_OK, "Ooops", "You have to roll the dice first!") 
    end
  end

  def validate_action_panel(ap)
    super
    ap.roll_button.enable
  end

  def validate_action_widget(widget)
    super
    widget.dice.enabled = true 
    widget.play_soldier_card.enabled = true if @player.cards[SoldierCard] > 0
  end
end


# This state indicates that the player HAS rolled the dice, 
# but isn't done his turn
class RolledDiceState < FXPlayerState

  def on_canvas_left_click(sender, sel, event)
    piece = @player.getTouchingPiece(event.win_x, event.win_y, @player.proximity, @player.currentTurn)
    if piece
      if piece.class == Edge
        @player.currentTurn.place_road!(*piece.coords)
      elsif piece[0] == City
        @player.currentTurn.place_city!(*(piece[1].coords))
      elsif piece[0] == Settlement
        @player.currentTurn.place_settlement!(*(piece[1].coords))
      end
    end
    super
  end


  def validate_action_widget(widget)
    super
    widget.buy_dev_card.enabled = true if @player.can_afford?([DevelopmentCard])
    widget.trade.enabled = true
    widget.done.enabled = true
    widget.play_soldier_card.enabled = true if @player.cards[SoldierCard] > 0
    widget.play_road_building_card.enabled = true if @player.cards[RoadBuildingCard] > 0
    widget.play_year_of_plenty_card.enabled = true if @player.cards[YearOfPlentyCard] > 0
    widget.play_resource_monopoly_card.enabled = true if @player.cards[ResourceMonopolyCard] > 0
    
  end


  def validate_action_panel(ap)
    super
    ap.trade_button.enable
    ap.dev_card_button.enable if @player.can_afford?([DevelopmentCard])
    ap.done_button.enable
  end
end


#This state indicates that the player has finished his turn and is waiting
#for his next turn
class FinishedTurnState < FXPlayerState
end


#This state indicates that the player is in the setup phase
class SetupTurnState < RolledDiceState

  def on_canvas_left_click(sender, sel, event)
    super
    #implicit done when you place a road during setup
    @player.currentTurn.done if @player.currentTurn.placed_road
  end

  def validate_action_panel(ap)
    buttons = [ap.done_button, ap.trade_button, ap.roll_button, ap.dev_card_button]
    buttons.each{|b| b.disable}
  end

  def validate_action_widget(widget)
    widget.setup_turn = true
    actions = [widget.dice, widget.done, widget.trade, widget.buy_dev_card]
    actions.each{|act| act.enabled = false }
  end
end


#This state indicates that the player is in the middle of moving the bandit.
class MovingBanditState < FXPlayerState
  attr_reader :chosen_hex

  #Draw the temp bandit
  def on_canvas_mouse_motion(sender, sel, event)
    temp_bandit_hex = nil
    for tile, pair in @player.hex_centers
      x,y = pair
      if @player.is_in_proximity(x, y, 30, event.win_x, event.win_y)
        temp_bandit_hex = tile
        break
      end
    end
    @player.draw_board(nil, temp_bandit_hex)    
  end

  def on_canvas_left_click(sender, sel, event)
    for tile, pair in @player.hex_centers
      x,y = pair
      if @player.is_in_proximity(x, y, 30, event.win_x, event.win_y)
        @chosen_hex = tile
        return
      end
    end    
    super
  end


  def validate_action_widget(widget)
    super
    widget.move_bandit = true
  end

end
