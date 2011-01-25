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


class SinglePlayerPanel < Wx::Panel 

  def initialize(player, *a)
    super(*a)
    @player = player
    main_sizer = Wx::BoxSizer.new(Wx::VERTICAL)
    set_sizer(main_sizer)
    font = Wx::Font.new(12, Wx::FONTFAMILY_DEFAULT, Wx::FONTSTYLE_NORMAL, Wx::FONTWEIGHT_BOLD)
    name_text = player.name 
    name_text += "(You)" if player.name == RealMainFrame.instance.human_player.name
    @player_name_text = Wx::StaticText.new(self, -1, name_text) 
    @player_name_text.set_font(font)
    @player_name_text.set_foreground_colour($player_color_map[player.color])
    main_sizer.add(@player_name_text)
        
    #details panel
    @detail_panel = Wx::Panel.new(self)
    main_sizer.add(@detail_panel)
    detail_sizer = Wx::BoxSizer.new(Wx::VERTICAL)
    @detail_panel.set_sizer(detail_sizer)
    smallfont = Wx::Font.new(7, Wx::FONTFAMILY_DEFAULT, Wx::FONTSTYLE_NORMAL, Wx::FONTWEIGHT_NORMAL)
    
    #Resource Cards
    @resource_cards = Wx::StaticText.new(@detail_panel, -1, '')
    detail_sizer.add(@resource_cards)
    @resource_cards.set_font(smallfont)
    @resource_cards.set_foreground_colour($player_color_map[player.color])
    
    #Dev Cards
    @dev_cards = Wx::StaticText.new(@detail_panel, -1, '')
    detail_sizer.add(@dev_cards)
    @dev_cards.set_font(smallfont)
    @dev_cards.set_foreground_colour($player_color_map[player.color])
  end
  
  def card_count=(count)
    @resource_cards.set_label("Resource cards: #{count}")
  end
  
  def dev_card_count=(count)
    @dev_cards.set_label("Development cards: #{count}")
  end

  def update_score(newscore)
    @player_name_text.set_label("#{@player.name} Score: #{newscore}")
  end

end


module PlayerPanel
  
  def init_me
    unless @was_init
      @was_init = true
      #mapping of PlayerInfo => SinglePlayerPanel 
      @player_panels = {}
      @main_frame = RealMainFrame.instance
    end
  end  
  

  def player_received_cards(player, cards)
   init_me
    update_player_data
  end
  
  def player_stole_card(theif, victim, num_cards)
   init_me
    update_player_data
  end
  
  def player_joined(player)
     
    unless player.is_a?(PlayerInfo)
      puts ArgumentError.new("Expected PlayerInfo object but recevied #{player}")
      puts caller
    end
    init_me
    panel = SinglePlayerPanel.new(player, self)
    @player_panels[player] = panel
    self.get_sizer.add(panel)
    layout
  end

  def placed_road(player, x, y, edge)
    init_me
    update_player_data
  end

  def placed_settlement(player, x, y, node)
    init_me
    update_player_data
  end

  def placed_city(player, x, y, node)
    init_me
    update_player_data
  end

  def game_start; end
  def game_end(winner, points); end
  def get_turn(player, turn_class); end
  def player_moved_bandit(player, new_hex); end
  def player_rolled(player, roll); end
  def update_board(board); end
  
  private
  
  def update_player_key(player)
    @player_panels[player]
  end
  
  def update_player_data
    for player, panel in @player_panels
       panel.update_score(@main_frame.admin.get_score(player))
       panel.card_count = @main_frame.admin.count_resource_cards(player)
       panel.dev_card_count = @main_frame.admin.count_dev_cards(player)
    end
    layout
    refresh
  end
  
  
end