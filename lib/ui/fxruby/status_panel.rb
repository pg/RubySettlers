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


# This file contains the GUI for the status panel to the right 
# of the fxplayer panel.

#The panel displaying the status for a single user.
class SinglePlayerStatus < FXVerticalFrame
  def initialize(player, *args)
    super(*args)
    @player = player
    @initial_color = nil
    top_h = FXHorizontalFrame.new(self, :opts => LAYOUT_FILL_X|LAYOUT_FILL_Y, :padding=>0, :hSpacing => 0)
    bigFont = FXFont.new(getApp(), "arial", 11, :weight=>FONTWEIGHT_BOLD)
    @spring = FXSpring.new(top_h, :opts => LAYOUT_FILL_Y|LAYOUT_LEFT, :relw=>20)
    @color_canvas = FXCanvas.new(@spring, :opts => LAYOUT_FILL_X|LAYOUT_FILL_Y|LAYOUT_LEFT)
    @name_label = FXLabel.new(top_h, '', nil, JUSTIFY_LEFT|LAYOUT_LEFT|LAYOUT_FILL_X, :padding=>0)
    @name_label.font = bigFont
    @points_label = FXLabel.new(top_h, '', nil, JUSTIFY_RIGHT|LAYOUT_LEFT|LAYOUT_FILL_X, :padding=>0)
    @points_label.font = bigFont
    smallFont = FXFont.new(getApp(), "arial", 7)
    @resource_cards_label = FXLabel.new(self, '', nil, JUSTIFY_LEFT|LAYOUT_LEFT, :padding=>0)
    @resource_cards_label.font = smallFont
    @resource_cards_label.visible = false
    @dev_cards_label = FXLabel.new(self, '', nil, JUSTIFY_LEFT|LAYOUT_LEFT, :padding=>0)
    @dev_cards_label.font = smallFont
    @dev_cards_label.visible = false
    @settlements_left_label = FXLabel.new(self, '', nil, JUSTIFY_LEFT|LAYOUT_LEFT, :padding=>0)
    @settlements_left_label.font = smallFont
    @settlements_left_label.visible = false
    @city_left_label = FXLabel.new(self, '', nil, JUSTIFY_LEFT|LAYOUT_LEFT, :padding=>0)
    @city_left_label.font = smallFont
    @city_left_label.visible = false
    @roads_left_label = FXLabel.new(self, '', nil, JUSTIFY_LEFT|LAYOUT_LEFT, :padding=>0)
    @roads_left_label.font = smallFont
    @roads_left_label.visible = false
    @name_label.connect(SEL_ENTER, method(:on_mouse_enter))
    @name_label.connect(SEL_LEAVE, method(:on_mouse_leave))
    @color_canvas.connect(SEL_ENTER, method(:on_mouse_enter))
    @color_canvas.connect(SEL_LEAVE, method(:on_mouse_leave))
    @spring.connect(SEL_ENTER, method(:on_mouse_enter))
    @spring.connect(SEL_LEAVE, method(:on_mouse_leave))
    top_h.connect(SEL_ENTER, method(:on_mouse_enter))
    top_h.connect(SEL_LEAVE, method(:on_mouse_leave))
  end
  
  def update(player, points, resource_cards, dev_cards, has_turn)
    @initial_color = getBackColor unless @initial_color
    back_color = has_turn ? FXColor::LightBlue : @initial_color
    self.setBackColor(back_color)
    @spring.setBackColor(back_color)
    @color_canvas.connect(SEL_PAINT) do |sender, sel, event|
      FXDCWindow.new(@color_canvas, event) do |dc|
        dc.foreground = COLOR_HASH[player.color]
        dc.fillRectangle(event.rect.x, event.rect.y, event.rect.w, event.rect.h)
      end
    end
    @name_label.text = player.name
    @name_label.text += " (you)" if player == @player
    @name_label.setBackColor(back_color)
    @points_label.text = points.to_s
    @points_label.setBackColor(back_color)
    
    @resource_cards_label.text = resource_cards.to_s + ' Resource card'
    @resource_cards_label.text += 's' if resource_cards != 1
    @resource_cards_label.setBackColor(back_color) 
    
    @city_left_label.text = "#{player.piecesLeft(City)} cities left"
    @city_left_label.setBackColor(back_color) 
    
    @settlements_left_label.text = "#{player.piecesLeft(Settlement)} settlements left"
    @settlements_left_label.setBackColor(back_color) 

    @roads_left_label.text = "#{player.piecesLeft(Road)} roads left"
    @roads_left_label.setBackColor(back_color) 

    @dev_cards_label.text = dev_cards.to_s + ' Development card'
    @dev_cards_label.text += 's' if dev_cards != 1
    @dev_cards_label.setBackColor(back_color)
  end

  def on_mouse_enter(sender, sel, event)
    show_details(true)
  end
  
  def on_mouse_leave(sender, sel, event)
    show_details(false)
  end

  def show_details(vis)
    unless @resource_cards_label.visible? == vis
      @resource_cards_label.visible = vis
      @dev_cards_label.visible = vis
      @city_left_label.visible = vis
      @roads_left_label.visible = vis
      @settlements_left_label.visible = vis
      @resource_cards_label.layout
      @dev_cards_label.layout
      recalc
    end
  end
  
end

# The panel on the right hand side that displays all the players and their stats
# i.e. Score, Who's turn it is, The number of cards they have etc.
class PlayerStatusPanel < FXVerticalFrame
  def initialize(player, admin, *args)
    super(*args)
    #A hash of players to gui fields
    @player_fields = {}
    @admin = admin
    @player = player
    title = FXLabel.new(self, "Players", nil, JUSTIFY_CENTER_X|LAYOUT_FILL_X)
    title.font = FXFont.new(getApp(), "arial", 11, :weight=>FONTWEIGHT_BOLD)
    title.backColor = FXColor::Blue
    title.textColor = FXColor::White
  end
  
  #update this panel with a given game admin
  def update
    for player in @admin.players
      player_field = @player_fields[player]
      unless player_field
        player_field = SinglePlayerStatus.new(@player, self, LAYOUT_FILL_X)
        player_field.create
        @player_fields[player] = player_field
      end      
      #update the player's info
      res_cards = 0
      dev_cards = 0
      player.cards.each{ |type, amount| 
        res_cards += amount if RESOURCE_TYPES.include?(type)
        dev_cards += amount if type.is_a?(DevelopmentCard)
      }
      has_turn = @admin.currentTurn.player == player if @admin.currentTurn
      player_field.update(player, @admin.get_score(player), res_cards, dev_cards, has_turn)
    end  
   layout
  end
end


class ActionPanel < FXVerticalFrame
  attr_reader :roll_button, :trade_button, :dev_card_button, :done_button

  def initialize(player, admin, *args)
    super(*args)
    @admin = admin
    @player = player
    title = FXLabel.new(self, "Turn Actions", nil, JUSTIFY_CENTER_X|LAYOUT_FILL_X)
    title.font = FXFont.new(getApp(), "arial", 11, :weight=>FONTWEIGHT_BOLD)
    title.backColor = FXColor::Blue
    title.textColor = FXColor::White
    
    @roll_button = create_button("Roll Dice [F5]", :on_roll)
 #   @roll_button.buttonStyle = BUTTON_TOOLBAR
    @trade_button =  create_button("Trade [F6]", :on_trade)
#    @trade_button.buttonStyle = BUTTON_TOOLBAR
    @dev_card_button = create_button("Buy Development Card [F7]", :on_dev_card)
    @done_button = create_button("Done turn [F8]", :on_done)
   
    #Play Development cards
    @play_soldier_button = create_button("Play Soldier", :on_play_soldier)
    @play_resource_monopoly = create_button("Play Resource Monopoly", :on_resource_monopoly)
    @play_road_building_button = create_button("Play Road Building Card", :on_road_building)
    @play_year_of_plenty_button = create_button("Play Year of Plenty Card", :on_year_of_plenty)
  end
  
  def create_button(label, action_method)
    button = FXButton.new(self, label, :opts=>LAYOUT_CENTER_X|FRAME_RAISED|FRAME_THICK|LAYOUT_FILL_X)
    button.font = FXFont.new(getApp(), "arial", 10)
    button.connect(SEL_COMMAND, method(action_method))
    button
  end
  
  def on_roll(sender=nil, sel=nil, event=nil)
    Thread.new {
      @player.currentTurn.roll_dice    
    }
    @player.current_state = RolledDiceState.new(@player)
    validate
  end

  def on_trade(sender=nil, sel=nil, event=nil)
    td = TradeDialog.new(@player, app)
    td.create
    td.show(PLACEMENT_SCREEN)
    validate
  end

  def on_dev_card(sender=nil, sel=nil, event=nil)
    @player.currentTurn.buy_development_card
    validate
  end

  def on_done(sender=nil, sel=nil, event=nil)
    @player.currentTurn.done
    @player.current_state = FinishedTurnState.new(@player)
    validate
  end

  def on_play_soldier(sender=nil, sel=nil, event=nil)
    play_dev_card(SoldierCard)
  end
  
  def on_resource_monopoly(sender=nil, sel=nil, event=nil)
    play_dev_card(ResourceMonopolyCard)
  end

  def on_road_building(sender=nil, sel=nil, event=nil)
    play_dev_card(RoadBuildingCard)
  end

  def on_year_of_plenty(sender=nil, sel=nil, event=nil)
    play_dev_card(YearOfPlentyCard)
  end
  
  def play_dev_card(card_class)
    Thread.new {
      @player.currentTurn.play_development_card!(card_class.new)
      validate
    }
  end

  def validate
    @player.current_state.validate_action_panel(self)
    @play_soldier_button.visible = @player.cards[SoldierCard] > 0
    @play_resource_monopoly.visible = @player.cards[ResourceMonopolyCard] > 0
    @play_road_building_button.visible = @player.cards[RoadBuildingCard] > 0
    @play_year_of_plenty_button.visible = @player.cards[YearOfPlentyCard] > 0
  end
end


class MessagePanel < FXVerticalFrame
  def initialize(*args)
    super(*args)
    title = FXLabel.new(self, "Messages", nil, JUSTIFY_CENTER_X|LAYOUT_FILL_X)
    title.font = FXFont.new(getApp(), "arial", 11, :weight=>FONTWEIGHT_BOLD)
    title.backColor = FXColor::Blue
    title.textColor = FXColor::White
    @scroll = FXScrollWindow.new(self, :opts=>LAYOUT_FILL_X|LAYOUT_FILL_Y)
    @v_frame = FXVerticalFrame.new(@scroll, :opts=>LAYOUT_FILL_X|LAYOUT_FILL_Y)
  end
  
  #create and add a new TurnMessageFrame
  def add_turn(player)
    tm = TurnMessage.new(player, @v_frame, :opts=>LAYOUT_FILL_X|LAYOUT_FILL_X, :vSpacing=>0)
    tm.create
    layout
    tm
  end

  def layout
    super
    @scroll.setPosition(0, -@scroll.contentWindow.height)
  end
end


class TurnMessage < FXVerticalFrame
  @@turn_count = {}
  @@turn_count.default = 0
  
  def initialize(player, *args)
    super(*args)
    @@turn_count[player] += 1
    @header = FXLabel.new(self, "#{player.name} (Turn #{@@turn_count[player]})", :padding=>0)
    @header.font = FXFont.new(getApp(), "arial", 10, :weight=>FONTWEIGHT_BOLD)
    @header.textColor = COLOR_HASH[player.color]
#    @header.backColor = FXColor::DarkSlateGrey
    
  end
  
  def add_msg(msg)
    l = FXLabel.new(self, "   "+msg, :padding=>0)
    l.font = FXFont.new(getApp(), "arial", 8)
    l.create
    layout
  end
end
