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
require 'lib/core/bots' # temporary

# This is the actual player object with ties to the Wx Interface
class WxPlayer < Player
  attr_reader :main_frame
  attr_accessor :state, :preferred_color
  attr_reader :active_player #the player who's turn ot

  def initialize(main_frame, name, admin)
    @main_frame = main_frame
    change_state_to(WaitingState)
    super(name, admin)
  end
  
  def take_turn(*a)
    super
    stateClass = currentTurn.is_setup ? SetupTurnState : NewTurnState
    change_state_to(stateClass)
  end

  def game_end(winner, points)
    $log.debug('game end in wxplayer')
    change_state_to(WaitingState)
    super
  end
  
 def update_board(board)
    super
    panel = @main_frame.board_panel 
    panel.set_board(board)
    panel.update_board_dimensions
    panel.refresh
  end
  
  def get_user_quotes(wantList, giveList)
    Thread.new{
	  puts caller
	  $log.debug("received wantList: #{wantList}")
	  $log.debug("received giveList: #{giveList}")
      @main_frame.offer_trade_dialog.display(wantList, giveList)
    }
    puts @main_frame.offer_trade_dialog 
    while @main_frame.offer_trade_dialog.quotes.nil?
      sleep(0.5)
    end
    quotes = @main_frame.offer_trade_dialog.quotes
    puts 'wuote'
    puts quotes
    @main_frame.offer_trade_dialog.hide
    return quotes
  end


  def player_rolled(player, roll)
    @main_frame.board_panel.last_roll = roll.sum
    @main_frame.board_panel.paint_dc
  end

  def game_end(winner, points)
    msg = Wx::MessageDialog.new(@main_frame, "#{winner.name} won the game with #{points} points!", "Game Over", Wx::OK)
    msg.show_modal
  end
  
  def move_bandit(old_hex)
    last_state = @state
    @state = MovingBanditState.new(old_hex, self, @state)
    while state.chosen_hex.nil?; sleep(0.1 ); end
    chosen_hex = @state.chosen_hex 
    change_state_to(last_state.class)
    chosen_hex
  end
  
  def select_resource_cards(cards, count)
    RealMainFrame.instance.disable_gui_sleep
    $log.debug("WxPlayer - Select Resource Cards: count:#{count}, cards:#{cards} #{caller}")
    if count == 1
       sd = RealSingleCardSelectorDialog.new(@main_frame, cards)
       selected = [sd.get_card]
       sd.close
    else 
      puts @main_frame
      cd = CardSelectorDialog.new(@main_frame)
      $log.debug("WxPlayer - Opened card dialog #{cards[0].class}")
      puts cards.to_count_hash
      cd.init(cards.to_count_hash, count)
      $log.debug("WxPlayer - init card dialog")
      cd.show_modal 
      $log.debug("WxPlayer - Showed dialog")
      selected = cd.get_selected_cards
      cd.close
    end
    $log.info("Selected #{selected}")
    RealMainFrame.instance.enable_gui_sleep
    selected
  end
  
  def select_player(players)
    RealMainFrame.instance.disable_gui_sleep
    ps = RealPlayerSelector.new(@main_frame, players)
    player = ps.get_player
    ps.close
    RealMainFrame.instance.enable_gui_sleep
    player
  end
  
  def chat_msg(player, msg)
    bold_font = Wx::Font.new(10, Wx::FONTFAMILY_DEFAULT, Wx::FONTSTYLE_NORMAL, Wx::FONTWEIGHT_BOLD)
    bold_style= Wx::TextAttr.new($player_color_map[player.color], Wx::NULL_COLOUR, bold_font)
    write_chat_with_style("#{player.name}:", bold_style)  
  
    normal_font = Wx::Font.new(8, Wx::FONTFAMILY_DEFAULT, Wx::FONTSTYLE_NORMAL, Wx::FONTWEIGHT_NORMAL)
    normal_style = Wx::TextAttr.new($player_color_map[player.color], Wx::NULL_COLOUR, normal_font)
    write_chat_with_style(" #{msg}\n", normal_style)  
  end
  
  def write_chat_with_style(text, attr)
    write_chat_with_style_to_control(@main_frame.chattext, text, attr)
    write_chat_with_style_to_control(@main_frame.trade_dialog.chat_text_box, text, attr)
    write_chat_with_style_to_control(@main_frame.offer_trade_dialog.chat_text_box, text, attr)
  end
  
  def write_chat_with_style_to_control(control, text, attr)
    initial_pos = control.get_last_position
    control.append_text text
    new_pos = control.get_last_position
    control.set_style(initial_pos, new_pos, attr)
    control.refresh  
  end  
  
  #change this player's UI state
  def change_state_to(stateKlass)
    @state = stateKlass.new(self, @state)
  end

  #redirect all the iobserver methods to the event log controland player panel
  for method in IObserver.instance_methods
    chain_method(method) do |instance, method_name, *args|
       instance.main_frame.event_log_text.send(method_name, *args)
    end
    chain_method(method) do |instance, method_name, *args|
      instance.main_frame.player_panel.send(method_name, *args)
    end
  end
  
  methods_to_update_card_frame_on = [:add_cards, :del_cards]
  methods_to_update_board_on = [:player_moved_bandit, :placed_road, 
                                :placed_settlement, :placed_city]
  for method in methods_to_update_card_frame_on
    chain_method(method) do |instance, method_name, *a|
      instance.state.validate
      instance.main_frame.card_panel.refresh
    end  
  end
  
  for method in methods_to_update_board_on
    chain_method(method) do |instance, method_name, *a|
      p = instance.main_frame.board_panel
      p.refresh
    end    
  end  
end
