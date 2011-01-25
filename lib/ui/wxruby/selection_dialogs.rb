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


class CardSelectorDialog
  def init(players_cards, max_count)
    @sliders = {@wood_slider => [@wood_value_label, WoodType], @wheat_slider => [@wheat_value_label, WheatType], 
                @sheep_slider => [@sheep_value_label, SheepType], @ore_slider => [@ore_value_label, OreType], 
                @brick_slider => [@brick_value_label, BrickType]}
    @sliders.keys.each{|s|
      evt_slider(s, :validate)
    }
    set_title "Please select #{max_count} cards"
    @max_count = max_count
    @player_cards = players_cards
    @ok_button = Wx::Window.find_window_by_id(Wx::ID_OK, self)
    evt_button(Wx::ID_OK, :on_ok)
    validate
  end
  
  #how many cards to they have left to choose
  def left_to_choose
    sum = 0
    @sliders.keys.each{|s| sum += s.value}
    @max_count - sum
  end
  
  def on_ok(event)
    close
  end

  def validate(event=nil)
    left = left_to_choose
    @sliders.each{|s, array|
      label, cardType = array
      label.set_label(s.value.to_s)
      max = s.value + left
      max = [max, @player_cards[cardType]].min
      s.set_range(0, max)
      if max == 0 
        s.disable
      else
        s.enable
      end 
    }
    if left == 0
      @ok_button.enable
    else
      @ok_button.disable
    end     
  end
  
  def get_selected_cards
    result = []
    @sliders.each{|s, array|
      label, cardType = array
      result += ([cardType] * s.value)
    }
    result
  end
end


class RealSingleCardSelectorDialog < SingleCardSelectorDialog
  def initialize(parent, cards)
    super(parent)
    @selected_card = nil
    @buttons = {}
    card_images = CardPanel.get_card_images
    for c in cards
      button = Wx::BitmapButton.new(self, -1, card_images[c])
      @buttons[button] = c
      evt_button(button, :on_button_click)
      get_sizer.add(button, 0, Wx::ALL, 5)
    end
    get_sizer.set_size_hints(self)
  end
   
  def on_button_click(e)
    button = e.get_event_object
    @selected_card = @buttons[button]
    close
  end

  def get_card
    show_modal
    return @selected_card
  end  
end



class RealPlayerSelector < PlayerSelector
  def initialize(parent, players)
    super(parent)
    @selected_player = nil
    @buttons = {}
    font = Wx::Font.new(14, Wx::FONTFAMILY_DEFAULT, Wx::FONTSTYLE_NORMAL, Wx::FONTWEIGHT_BOLD)
    for p in players
      button = Wx::Button.new(self, -1, p.name, [0,0], [150,40])
      button.set_own_foreground_colour($player_color_map[p.color])
      button.set_font(font)
      @buttons[button] = p
      evt_button(button, :on_button_click)
      get_sizer.add(button, 0, Wx::ALL, 5)
    end
    get_sizer.set_size_hints(self)
  end
  
  def on_button_click(e)
    button = e.get_event_object
    @selected_player = @buttons[button]
    close
  end

  def get_player
    show_modal
    return @selected_player
  end
end
