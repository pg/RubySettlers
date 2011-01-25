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

class TradeDialog < FXDialogBox
  def initialize(player, app)
    @fxplayer = player
    @quote_list = []
    super(app, "Trade dialog", :opts => DECOR_ALL, :width=>600, :height=>350)
    main = FXHorizontalFrame.new(self, :opts=>LAYOUT_FILL_X|LAYOUT_FILL_Y)

    left_panel = FXSpring.new(main, :opts=>LAYOUT_FILL_Y, :relw=>100)
    left_frame = FXVerticalFrame.new(left_panel, :opts => LAYOUT_FILL_X|LAYOUT_FILL_Y)    
    w_box = FXGroupBox.new(left_frame, "Want", :opts=>FRAME_SUNKEN)
    want = CardNumberPanel.new(@fxplayer, w_box, 1, :opts=>LAYOUT_FILL_X|LAYOUT_FILL_Y|MATRIX_BY_COLUMNS)
    g_box = FXGroupBox.new(left_frame, "Give", :opts=>FRAME_SUNKEN)
    give = CardNumberPanel.new(@fxplayer, g_box, 1, :opts=>LAYOUT_FILL_X|LAYOUT_FILL_Y|MATRIX_BY_COLUMNS)
    RESOURCE_TYPES.each{|r| 
      give.resources[r].disable if @fxplayer.cards[r] == 0
    } 
    prop_button = FXButton.new(left_frame, "Propose Trade")
    prop_button.connect(SEL_COMMAND) do |sender, selector, data|
      quotes = player.currentTurn.get_quotes(want.get_checked, give.get_checked)
      if quotes.size > 0
        @quotes.clearItems 
        @quote_list = quotes
      end
      for q in quotes
        giver = "The Bank"
        giver = q.tradee if q.tradee
        give_name = @fxplayer.get_resource_alias(q.giveType)
        want_name = @fxplayer.get_resource_alias(q.recieveType)  
        line = "#{giver} will give you #{q.giveNum} #{give_name} for #{q.recieveNum} #{want_name}"
        @quotes.appendItem(line)
      end
      validate
    end
    
    mid_spring = FXSpring.new(main, :opts=>LAYOUT_FILL_Y, :relw=>300)
    mid_frame = FXVerticalFrame.new(mid_spring, :opts => LAYOUT_FILL_Y|LAYOUT_FILL_X)
    @quotes = FXList.new(mid_frame, :opts=>LAYOUT_FILL_X|LAYOUT_FILL_Y)
    @accept_button = FXButton.new(mid_frame, "Accept Quote")
    @accept_button.connect(SEL_COMMAND) do |sender, selector, data|
      q = @quote_list[@quotes.currentItem]
      @fxplayer.currentTurn.accept_quote(q)
      validate
    end
    
    chat_frame = FXVerticalFrame.new(main, :opts => LAYOUT_FILL_Y|LAYOUT_FILL_X)
    @chat = FXList.new(chat_frame, :opts=>LAYOUT_FILL_X|LAYOUT_FILL_Y)
    c_frame = FXHorizontalFrame.new(chat_frame)
    chat_text = FXTextField.new(c_frame, 30)
    send_button = FXButton.new(c_frame, "Send")
    send_button.connect(SEL_COMMAND) do |sender, selector, data|
    end
  
    validate
    layout
  end
  
  def validate
   if @quote_list.size > 0
      @accept_button.enable 
    else
      @accept_button.disable 
    end
  end
end

# A Panel that displays all the various tradable cards
# each with a number spinner next to them
class CardNumberPanel < FXMatrix
  #A hash of <ResourceClass, FXCheckButton>
  attr_reader :resources

  def initialize(player, *args)
    super(*args)
    @resources = {}
    RESOURCE_TYPES.each{|r| 
       name = player.get_resource_alias(r).capitalize
#       FXLabel.new(self, name)
       field = FXCheckButton.new(self, name)
       @resources[r] = field
    }
    layout      
  end
  
  #gets a list of resources that are checked
  def get_checked
    @resources.keys.select{|r|
      @resources[r].checked?
    }
  end

end


#Standalone host dialog
if __FILE__ == $0
  require 'lib/core/player'
  require 'lib/core/admin'
  require 'lib/core/game_definition'
  require 'logger'
  require 'timeout'
  require 'lib/ui/board_viewer'
  require 'lib/boards/board_manager'
  require 'lib/ui/fxruby/fxutils'
  
  ## Logger init
  $log = Logger.new(STDOUT)
  $log.level = Logger::WARN

  # Construct the application
  application = FXApp.new("Test", "Test")
  application.disableThreads
  
  board = StandardBoard.new
  a = Admin.new(board, 4)
  p1 = Player.new('test', a)
  p2 = RandomPlayer.new('test', a)
  a.register(p1, p2)
  
  
  # Construct the main window
  tw = TradeDialog.new(p1, application)
  tw.create
  tw.show(PLACEMENT_SCREEN)
  
  # Create the app's windows
  application.create
  # Run the application
  application.run
end
