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

require 'lib/core/iobserver'
require 'drb'
require 'logger'
require 'fox16'
require 'fox16/colors'
include Fox

class CardSelectorDialog < FXDialogBox
  attr_reader :final_values
  # The total number of cards to select
  attr_reader :total

  #Gets a hash of <CardType, int> from the user
  #[list_items] a list of [id, display_string, max]
  #where id is any object that can act as a unique identifier and
  #max is an int value of the spinner
  def CardSelectorDialog.get_card_counts(app, title, list_items, total)
    csd = CardSelectorDialog.new(app, title, list_items, total)
#    csd.create
    csd.execute
    csd.get_values
  end

  def initialize(app, title, list_items, total) 
    super(app, title,:opts => DECOR_ALL, :width=>300, :height=>160)
    @total = total
    @resource_fields = [] #<item_id, field, initial_max>
    @matrix = FXMatrix.new(self, 2, :opts=>MATRIX_BY_COLUMNS)
    for id, name, max in list_items
      add_resource(id, name, max)
    end
    
    FXHorizontalSeparator.new(self)
    @accept = FXButton.new(self, "      &Ok      ", nil, self, ID_ACCEPT,
      FRAME_RAISED|FRAME_THICK|LAYOUT_RIGHT|LAYOUT_CENTER_Y, :width=>120)
      
    validate
  end
  
  def validate
    total = 0
    get_values.each{|id, val| total += val}
    if total != @total
      @accept.disable
      @resource_fields.each{|id, field, max| 
        field.range = 0..max
      }
    else
      @accept.enable
      @resource_fields.each{|id, field, max| 
        field.range = 0..field.value
      }
    end
  end
  
  
  def add_resource(id, name, max)
    FXLabel.new(@matrix, name)
    option = FXSpinner.new(@matrix, 5, nil, DECOR_ALL)
    option.setRange(0..max)
    option.value = 0
    option.connect(SEL_COMMAND) do |sender, sel, event|
      validate
    end
    @resource_fields << [id, option, max]
  end
  
  def get_values
    result = {}
    for id, field, max in @resource_fields
      result[id] = field.value
    end
    result
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
#  application.disableThreads
  # Construct the main window
  # 
  Thread.new{
    sleep(1)
    items = RESOURCE_TYPES.map{|t| [t, t.to_s, 5]}
    cards = CardSelectorDialog.get_card_counts(application, 
                                               "Select some resources to discard", 
                                               items, 4)
    puts cards
    STDOUT.flush
  }
  
  # Create the app's windows
  application.create
  # Run the application
  application.run
end
