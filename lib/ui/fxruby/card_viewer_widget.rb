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

require 'lib/ui/fxruby/canvas_widgets'

class CardViewer < ExpandableWidget
  
    CARD_IMAGE_FILES = {OreType=>'ore_resource.jpg',
                        WheatType=>'wheat_resource.jpg',
                        WoodType=>'wood_resource.jpg',
                        BrickType=>'brick_resource.jpg',
                        DesertType=>'desert_resource.jpg',
                        SheepType=>'sheep_resource.jpg'}
  
  
  def initialize(app, canvas, fxplayer)
    super(app, canvas, fxplayer)
    @collapsed_text_label = "Cards"
    @collapsed_text_color = FXColor::DarkBlue
    @collapsed_back_color = FXColor::LightBlue
    @expanded_back_color = FXColor::DarkSlateBlue
    @expanded_height = 150
    @expanded_width = 400
    @is_expanded = true
    @cached_images = {}
    RESOURCE_TYPES.each{|r| 
      img = FXJPGIcon.new(@app, nil)
      filename = CARD_IMAGE_FILES[r]
      FXFileStream.open("lib/img/#{filename}", FXStreamLoad) { |stream| 
        img.loadPixels(stream) 
      }
      img.scale(70, 100)
      img.create
      @cached_images[r] = img
    }
  end

  def draw_expanded(dc)
    draw_toggle_button(dc, @x, @y)
    dc.foreground = @expanded_back_color
    dc.fillRectangle(@x, @y+@collapsed_height, @expanded_width, @expanded_height)
    y = @y+@collapsed_height+20
    dc.foreground = FXColor::Black
    x = @x + 10
    total_cards = @player.resource_cards.size
    if total_cards > 0
      delta_x = [(@expanded_width - 110) / total_cards, 50].min
      @player.resource_cards.each{|r|
        img = @cached_images[r]
        dc.drawIcon(img, x, y)
        x += delta_x
      }
    end
  end
  
end



class ActionWidget < ExpandableWidget
  attr_reader :dice, :done, :trade, :buy_dev_card
  attr_reader :play_soldier_card, :play_resource_monopoly_card
  attr_reader :play_road_building_card, :play_year_of_plenty_card
  attr_accessor :setup_turn, :move_bandit

  def initialize(app, canvas, fxplayer)
    super(app, canvas, fxplayer)
    @collapsed_text_label = "Actions"
    @collapsed_text_color = FXColor::DarkBlue
    @collapsed_back_color = FXColor::LightBlue
    @expanded_back_color = FXColor::DarkSlateBlue
    @expanded_height = 150
    @expanded_width = 300
    @is_expanded = true
    @cached_images = {}
    @actions = []
    create_actions
    validate
  end
  
  def create_actions
    @dice = ActionButton.new(self, 'dice.tif', 10, 50, "Roll the dice"){ on_roll }
    add_action(@dice)
    @trade = ActionButton.new(self, 'trade_icon.tif', 70, 50, "Trade resources"){ on_trade }
    add_action(@trade)
    @done = ActionButton.new(self, 'checkmark.tif', 130, 50, "Done your turn"){ on_done }
    add_action(@done)
    @buy_dev_card = ActionButton.new(self, 'buy_dev_card_button.tif', 190, 50, "Buy a Development Card"){ on_buy_dev_card  }
    add_action(@buy_dev_card)
   
    @play_soldier_card = ActionButton.new(self, 'soldier_button.tif', 10, 100, "Play Soldier Card"){ on_play_soldier  }
    add_action(@play_soldier_card)
    @play_resource_monopoly_card = ActionButton.new(self, 'monopoly_button.tif', 70, 100, "Play Monopoly Resource Card"){    on_resource_monopoly  }
    add_action(@play_resource_monopoly_card)
    @play_road_building_card = ActionButton.new(self, 'road_building_button.tif', 130, 100, "Play Road Building Card"){  on_road_building }
    add_action(@play_road_building_card)
    @play_year_of_plenty_card = ActionButton.new(self, 'yearofplenty_button.tif', 190, 100, "Play Year of Plenty Card"){ on_year_of_plenty }
    add_action(@play_year_of_plenty_card)

    @setup_turn = false #if this is true, this widget will draw a message for setup
    @move_bandit = false # if this is true, this widget will draw a message for move tha bandit
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

  def on_buy_dev_card(sender=nil, sel=nil, event=nil)
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
  

  def validate
    @player.current_state.validate_action_widget(self)
    @player.draw_board
  end


  def draw_expanded(dc)
    @actions.each{|act| 
      act.real_x = @x + act.x
      act.real_y = @y + act.y
    }

    draw_toggle_button(dc, @x, @y)
    dc.foreground = @expanded_back_color
    dc.fillRectangle(@x, @y+@collapsed_height, @expanded_width, @expanded_height)
    if @setup_turn
      paint_setup_message(dc)
    elsif @move_bandit
      paint_move_bandit_message(dc)
    else
      @actions.each{|act| act.draw(dc) }
    end
  end
  
  def paint_setup_message(dc)
    f = FXFont.new(@app, "arial", 20)
    f.create
    msg = "Setup turn"
    dc.foreground = FXColor::LightBlue
    buff = 10
    dc.fillRectangle(@x+buff, @y+@collapsed_height+buff, @expanded_width-buff-buff, 
                     @expanded_height-(buff*2)-+@collapsed_height)
    dc.foreground = FXColor::Black
    dc.setFont(f)
    dc.drawText(@x+buff+10, @y+@collapsed_height+50, msg)
    
    f = FXFont.new(@app, "arial", 12)
    f.create
    dc.setFont(f)
    msg = "Place a Settlement and a Road"
    dc.drawText(@x+buff+10, @y+@collapsed_height+70, msg)
  end

  def paint_move_bandit_message(dc)
      f = FXFont.new(@app, "arial", 20)
    f.create
    msg = "Move the Bandit!"
    dc.foreground = FXColor::LightBlue
    buff = 10
    dc.fillRectangle(@x+buff, @y+@collapsed_height+buff, @expanded_width-buff-buff, 
                     @expanded_height-(buff*2)-+@collapsed_height)
    dc.foreground = FXColor::Black
    dc.setFont(f)
    dc.drawText(@x+buff+10, @y+@collapsed_height+50, msg)
    
    f = FXFont.new(@app, "arial", 12)
    f.create
    dc.setFont(f)
    msg = "You rolled a 7, place the bandit on"
    dc.drawText(@x+buff+10, @y+@collapsed_height+70, msg)
    dc.drawText(@x+buff+10, @y+@collapsed_height+85, "an opponent's hex")
  end
  

  def on_mouse_motion(sender, sel, event)
    result = super
    unless result
      rel_x = event.win_x - @x
      rel_y = event.win_y - @y
      found = @actions.find{|act| act.is_touching(rel_x, rel_y) }
      if found and found.visible and found.enabled
        found.is_mouse_over = true
        @player.draw_board
      else
        draw = false
        @actions.each{|act| 
          draw = true if act.is_mouse_over
          act.is_mouse_over = false 
          act.should_draw_tooltip = false
        }
        @player.draw_board if draw
      end
    end
    result
  end

  def on_click(sender, sel, event)
    result = super
    unless result
      rel_x = event.win_x - @x
      rel_y = event.win_y - @y
      found = @actions.find{|act| act.is_touching(rel_x, rel_y) }
      found.run_action if found and found.visible and found.enabled
    end
    result
  end

  def add_action(action_button)
    @actions << action_button
  end
  
  #helper method for development cards
  def play_dev_card(card_class)
    Thread.new {
      @player.currentTurn.play_development_card!(card_class.new)
      validate
    }
  end
end

class ActionButton
  attr_accessor :visible, :enabled, :image
  #x, y coordinates relative to this action widget
  attr_accessor :x, :y
  attr_accessor :real_x, :real_y, :is_mouse_over, :should_draw_tooltip


  def initialize(action_widget, filename, x, y, tooltip = nil, &block)
    @parent = action_widget
    @x = x
    @y = y
    @visible = true
    @enabled = true
    @app = action_widget.app
    @image = FXTIFIcon.new(@app, nil)
    @tooltip = tooltip
    FXFileStream.open("lib/img/#{filename}", FXStreamLoad) { |stream| 
      @image.loadPixels(stream) 
    }
    @right = @x + 30 #The rightmost coordiate
    @bottom = @y + 30 #The bottommost coordinate
    @image.scale(@image.width / 2, @image.height / 2)
    @image.create
    

    @mouse_over_image = FXTIFIcon.new(@app, nil)
    FXFileStream.open("lib/img/#{filename}", FXStreamLoad) { |stream| 
      @mouse_over_image.loadPixels(stream) 
    }
    @right = @x + 30 #The rightmost coordiate
    @bottom = @y + 30 #The bottommost coordinate
    @mouse_over_image.scale(@image.width*1.5, @image.height*1.5)
    @mouse_over_image.create


    @action_block = block
  end

  def draw(dc)
    if enabled
      if @is_mouse_over
        draw_mouse_over(dc)
      else
        dc.drawIcon(@image, @real_x, @real_y)
      end
    else
      draw_disabled(dc)
    end
    draw_tooltip(dc) if @should_draw_tooltip and @tooltip
  end

  def draw_disabled(dc)
    
  end


  def draw_mouse_over(dc)
    xDiff = (@mouse_over_image.width - @image.width) / 2
    yDiff = (@mouse_over_image.height - @image.height) / 2
    dc.drawIcon(@mouse_over_image, @real_x-xDiff, @real_y-yDiff)
    if (not @should_draw_tooltip) and @tooltip
      Thread.new{
        sleep(0.5)
        if @is_mouse_over
          @should_draw_tooltip = true
          @parent.player.draw_board
        end
      }
    end
  end

  def draw_tooltip(dc)
    f = FXFont.new(@app, "arial", 12)
    f.create

    width = f.getTextWidth(@tooltip)
    dc.foreground = FXColor::LightBlue
    dc.fillRectangle(@real_x-1, @real_y - 20, width+2, 19)

    dc.foreground = FXColor::Black
    dc.setFont(f)
    dc.drawText(@real_x, @real_y-5, @tooltip)

    Thread.new{
      sleep(0.5)
      unless @is_mouse_over
        @should_draw_tooltip = false
        @parent.player.draw_board
      end
    }
  end

  #are the given relative coordinates within this icon?
  def is_touching(x, y)
    x.between?(@x, @right) and  y.between?(@y, @bottom)
  end

  def run_action
    @should_draw_tooltip = false
    @is_mouse_over = false
    @action_block.call
  end

end
