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

class WaitingListener < PlayerListener
  def got_turn(turn)
    main_frame = RealMainFrame.instance
    main_frame.waiting_text.hide if main_frame.waiting_text 
    main_frame.actions_panel.layout if main_frame.actions_panel
  end
 
  def finished_turn(turn)
    main_frame = RealMainFrame.instance
    main_frame.waiting_text.show if main_frame.waiting_text 
    main_frame.actions_panel.layout if main_frame.actions_panel
  end
end
  
module ActionPanel
  
  IMAGE_DIR = 'lib/img/'

  def init(main_frame)
    @main_frame = main_frame
    button_images = {:roll_button => 'dice.tif',
                    :trade_button => 'trade_icon.tif',
                    :buy_dev_card_button => 'buy_dev_card_button.tif',
                    :done_button => 'done.tif',
                    :monopoly_button => 'monopoly_button.tif',
                    :yearofplenty_button => 'yearofplenty_button.tif',
                    :roadbuilding_button => 'road_building_button.tif',
                    :soldier_button => 'soldier_button.tif'}
    for button_name, file in button_images
      big, small = create_big_and_small_bitmaps(file)
      button = @main_frame.send(button_name)
      button.set_size(40,40)
      button.set_bitmap_label(small)
      button.set_bitmap_hover(big)
      button.hide
    end
    @main_frame.waiting_text.hide
  end
  
  def human_player
    @main_frame.human_player
  end
  
  def create_big_and_small_bitmaps(filename)
    image = Wx::Image.new
    image.load_file(IMAGE_DIR + filename, Wx::BITMAP_TYPE_TIF)
    small = image.copy
    small.rescale(30,30) 
    small_bitmap = Wx::Bitmap.new(small) 
    big = image.copy
    big.rescale(35,35) 
    big_bitmap = Wx::Bitmap.new(big)     
    [big_bitmap, small_bitmap]
  end

  def on_roadbuilding_button(event=nil)
    human_player.change_state_to(PlayingRoadbuiling)    
    run_safe_action do
      human_player.currentTurn.play_development_card!(RoadBuildingCard.new)
    end
  end

  def on_monopoly_button(event=nil)
    run_safe_action do
      human_player.currentTurn.play_development_card!(ResourceMonopolyCard.new)
    end
  end
  
  def on_yearofplenty_button(event=nil)
    run_safe_action do
      human_player.currentTurn.play_development_card!(YearOfPlentyCard.new)
    end
  end
  
  def on_soldier_button(event=nil)
    run_safe_action do
      human_player.currentTurn.play_development_card!(SoldierCard.new)
    end
  end

  def on_roll_button(event=nil)
    human_player.change_state_to(RolledDiceState)
    run_safe_action do
      human_player.currentTurn.roll_dice
    end
  end

  def on_done_button(event=nil)
    human_player.change_state_to(WaitingState)
    run_safe_action do
      human_player.currentTurn.done
    end
    $log.debug('Clicked Done button')
  end

  def on_trade_button(event=nil)
    run_safe_action do
      @main_frame.trade_dialog.show
    end
  end
  
  def on_buy_dev_card_button(event=nil)
    run_safe_action do
      human_player.currentTurn.buy_development_card
    end
  end
  
  private
  
  def run_safe_action
    Thread.new {
      begin
        yield
      rescue
        puts $!
        puts $!.backtrace.join("\n")
      end
    }.priority = 2  
  end
end
    