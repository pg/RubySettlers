#  Copyright (C)  2007 John J Kennedy III
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

module EventLogText
  def player_received_cards(player, cards)
    text = "#{player.name} received #{cards.size} card#{'s' if cards.size > 1}"
    player_notice player, text
  end
  
  def player_rolled(player, roll)
    player_notice player, "rolled a #{roll.sum}"
  end

  def player_stole_card(theif, victim, num_cards)
    player_notice theif, "stole #{num_cards} card#{'s' if num_cards > 1} from #{victim.name}" 
  end

  def game_start
    font = Wx::Font.new(12, Wx::FONTFAMILY_DEFAULT, Wx::FONTSTYLE_NORMAL, Wx::FONTWEIGHT_BOLD)
    attr = Wx::TextAttr.new(Wx::WHITE, Wx::NULL_COLOUR, font)
    write_with_style("Game is starting\n", attr) 
  end
  
  def game_end(winner, points)
    font = Wx::Font.new(13, Wx::FONTFAMILY_DEFAULT, Wx::FONTSTYLE_NORMAL, Wx::FONTWEIGHT_BOLD)
    attr = Wx::TextAttr.new($player_color_map[winner.color], Wx::NULL_COLOUR, font)
    write_with_style("#{winner.name} won with #{points} points!\n", attr) 
  end
  
  def player_joined(player)
    player_notice player, "#{player.name} joined the game" 
  end
  
  def get_turn(player, turn_class)
    #write a small line break
    small_font = Wx::Font.new(6, Wx::FONTFAMILY_DEFAULT, Wx::FONTSTYLE_NORMAL, Wx::FONTWEIGHT_BOLD)
    small_attr = Wx::TextAttr.new($player_color_map[player.color], Wx::NULL_COLOUR, small_font)
    write_with_style "\n", small_attr

    font = Wx::Font.new(12, Wx::FONTFAMILY_DEFAULT, Wx::FONTSTYLE_NORMAL, Wx::FONTWEIGHT_BOLD)
    attr = Wx::TextAttr.new($player_color_map[player.color], Wx::NULL_COLOUR, font)
    name = player.name.to_s + "'s"
    name = "Your" if player.name == 'You'
    
    turn_text = if turn_class == Turn then "Turn" else "Setup Placement" end 
    write_with_style "#{name} #{turn_text}\n", attr  
  end
  
  def player_moved_bandit(player, new_hex)
    player_notice player, "moved the bandit"    
  end

  def placed_road(player, x, y, edge)
    player_notice player, "placed a road"
  end

  def placed_settlement(player, x, y, node)
    player_notice player, "placed a settlement"
  end

  def placed_city(player, x, y, node)
    player_notice player, "placed a city"
  end
  
  def update_board(board)
  end

  private
  
  def main_frame
    RealMainFrame.instance
  end
  
  #Write text to the main chat and also to the trade chat dialog, 
  #this way, they'll always be in sync
  def write_with_style(text, attr)
    write_with_style_to_control(self, text, attr)
  end
  
  #write to a specific control
  #[tc] is the text control to write to
  def write_with_style_to_control(tc, text, attr)
    initial_pos = tc.get_last_position
    tc.append_text(text)
    new_pos = tc.get_last_position
    tc.set_style(initial_pos, new_pos, attr)
    
    #always display at least the last 4 lines
    num_lines = tc.get_number_of_lines
    position_back = (num_lines-4..num_lines).map{|i| tc.get_line_length(i)}.sum
    tc.show_position(tc.get_last_position-position_back)
    tc.parent.layout
    tc.parent.refresh
    tc.parent.update
  end
  
  def player_notice(player, text)
    # we can assume that if this call comes from wxplayer, it's referring to 'You'
    style = Wx::TextAttr.new($player_color_map[player.color])
    if player == RealMainFrame.instance.human_player
      write_with_style  text + "\n", style
    else
      write_with_style  text + "\n", style
    end
  end
  
end