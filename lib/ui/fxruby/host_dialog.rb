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

class HostDialog < FXWizard
  include Responder
  SETTINGS_FILENAME = 'server.settings'
  
  def initialize(app, frame=nil)
    @app = app
    @main_frame = frame
    img = FXPNGIcon.new(app, nil)
    FXFileStream.open("lib/img/host_wizard.png", FXStreamLoad) { |stream| 
      img.loadPixels(stream) 
    }
    img.create
    super(app, "Host a multiplayer game", img, :width=>600, :height=>300)
   
    default_button = FXButton.new(buttonFrame, "Set Defaults", :opts=>FRAME_SUNKEN)
    default_button.font = FXFont.new(getApp(), "arial", 8)
    default_button.connect(SEL_COMMAND) do |sender, selector, data|
      load_settings(get_defaults)
    end
   
    #1st Frame
    server_frame = FXMatrix.new(container, 2, MATRIX_BY_COLUMNS)
    @player_num = number_field(server_frame, "Number of players:", 2)
    @points_to_win = number_field(server_frame, "Points to win:", 10)
    @port = number_field(server_frame, "Port", 7643)
    games = get_game_definitions.map{|gd| gd.name}
    
    #TODO: make this combo box visible when there are multiple expansions
    @game_def = combo_box(server_frame, "Expansion:", games, 0, 15, true)
    @board = combo_box(server_frame, "Board:", [], 0, 20)
    @board_objects = BoardManager.get_boards
    @board_objects.each{|b|
      @board.append_item(b[0].name) 
    }
    #Update the boards when the expansion changes
    @game_def.connect(SEL_COMMAND) do |sender, selector, data|
      @board.clearItems
      BoardManager.get_boards.each{|b|
        @board.append_item(b[0].name)      
      }
    end
    @num_bots = number_field(server_frame, "Number of bots:", 0..10)
    #TODO: make this combo box visible when there are multiple AI types
    @bot_intelligence = combo_box(server_frame, "Bot intelligence:", ["Random"],0, 15, true)

    #Variation Frame
    variations = FXGroupBox.new(container, "Rule Variations", GROUPBOX_TITLE_CENTER|FRAME_THICK|FRAME_GROOVE)
    @reroll_2_12 = FXCheckButton.new(variations, "Re-roll on a 2 or a 12 if no one collects?")
#    @player_join = FXCheckButton.new(player, "Join the game when finished?")


 #   game_frame = FXMatrix.new(variations, 2, MATRIX_BY_COLUMNS)
    
    
    #User Frame
    
    if __FILE__ != $0
      player = FXGroupBox.new(container, "Player options", GROUPBOX_TITLE_CENTER|FRAME_THICK|FRAME_GROOVE)
      @player_join = FXCheckButton.new(player, "Join the game when finished?")
      @player_name = text_field(player, "Player name", "")
      @player_color = combo_box(player, "Preferred color", Admin.new(nil, 0).availableColors)    
    end    
    
    FXMAPFUNC(SEL_COMMAND, ID_ACCEPT, :onFinish)
    finishButton.text = 'Start!'
    FXMAPFUNC(SEL_COMMAND, ID_CANCEL, :onCancel) if __FILE__ == $0

    #Load last settings
    begin
      File.open(SETTINGS_FILENAME) do |f|
        load_settings(Marshal.load(f))
      end
    rescue
      load_settings(get_defaults)
    end
  end
  
  def onFinish(sender, selector, data)
    save_settings
    server_dialog = start_server
    
    settings = get_settings
    if settings[:player_join]
      DRb.start_service()
      admin = DRbObject.new(nil, "druby://localhost:#{settings[:port]}")
      if @main_frame
        @main_frame.clear_player_frame 
        p = FXPlayer.new(@app, @main_frame, settings[:player_name], admin)
        p.preferred_color = settings[:player_color]
      else
        raise 'TODO: create a new frame here'
      end
      admin.register(p)
    end
        
    server_dialog.add_bots(settings)
    hide
  end

  def onCancel(sender, selector, data)
    abort if __FILE__ == $0
  end

  #Set the value of a combo box based on a string
  def set_combo_from_string(combo, wanted_string)
    for i in 0..combo.numItems-1
      if combo.getItemText(i) == wanted_string
        combo.currentItem = i
      end
    end  
  end
  
  def get_defaults
    {:port => '7643',
     :player_num => '4',
     :points_to_win => '10',
     :game_def => StandardGame.new.name,
     :board => 'standard.board',
     :num_bots => '2',
     :bot_intelligence => 'Random',
     :reroll_2_12 => false,
     :player_join => true,
     :player_name => '',
     :player_color => ''
     }
  end
  
  #load saved settings from a hash
  def load_settings(settings_hash=nil)
    @port.text = settings_hash[:port].to_s
    @player_num.text = settings_hash[:player_num].to_s
    @points_to_win.text = settings_hash[:points_to_win].to_s
    set_combo_from_string(@game_def, settings_hash[:game_def])
    b = BoardManager.load_board(settings_hash[:board])
    set_combo_from_string(@board, b.name)
    @num_bots.text = settings_hash[:num_bots].to_s
    set_combo_from_string(@bot_intelligence, settings_hash[:bot_intelligence])
    
    @reroll_2_12.setCheck(settings_hash[:reroll_2_12])
    if __FILE__ != $0
      @player_join.setCheck(settings_hash[:player_join])
      @player_name.text = settings_hash[:player_name]
      set_combo_from_string(@player_color, settings_hash[:player_color])
    end
  end
  
  #Collect the settings from the UI
  def get_settings
    settings = {:port => @port.text,
                :player_num => @player_num.text,
                :points_to_win => @points_to_win.text,
                :game_def => @game_def.getItemText(@game_def.currentItem),
                :board => @board_objects[@board.currentItem][1],
                :num_bots => @num_bots.text,
                :bot_intelligence => @bot_intelligence.getItemText(@bot_intelligence.currentItem),
                :reroll_2_12 => @reroll_2_12.checked?}
                
    if __FILE__ != $0
      settings[:player_join] = @player_join.checked?
      settings[:player_name] = @player_name.text
      settings[:player_color] = @player_color.getItemText(@player_color.currentItem)
    end
    settings
  end
  
  def save_settings
    File.open(SETTINGS_FILENAME, 'w') do |f|
      Marshal.dump(get_settings, f)
    end  
  end
  
  def start_server
    sd = ServerDialog.new(@app, get_settings)
    sd.create
    sd.show(PLACEMENT_SCREEN)
    sd
  end
end



#The window that starts and displays an active server and it's output.
class ServerDialog < FXMainWindow
  include IObserver
  
  #A List of bot names
  @@botnames = BOT_NAMES.dup
  
  
  def initialize(app, settings)
    super(app, "Ruby Settlers Server", :opts=>DECOR_ALL, :width => 500, :height => 300)
    FXButton.new(self, "Stop Server").connect(SEL_COMMAND) do |sender, selector, data|
      if __FILE__ == $0
        abort 
      else
        if @drb
          @drb.stop_service 
          add_msg("Server stopped")
        end
      end
    end
    @msg_list = FXList.new(self, :opts=>LAYOUT_FILL_X|LAYOUT_FILL_Y)
    create_admin(settings)
  end
  
  def create_admin(settings)
    board = BoardManager.load_board(settings[:board])
    players = settings[:player_num].to_i
    points = settings[:points_to_win].to_i
    port = settings[:port].to_i
    
    add_msg("Starting Server")
    add_msg("Board: #{board.name}")
    add_msg("Players: #{players}")
    add_msg("Points: #{points}")
    add_msg("Port: #{port}")

    @admin = Admin.new(board, players, points)
    @admin.register_observer(self)
    @drb = DRb.start_service("druby://localhost:#{port}", @admin)
  end
  
  def add_bots(settings)
    num_bots = settings[:num_bots].to_i

    #Add Bots
    botname_size = @@botnames.size
    for i in 1..num_bots
      if num_bots > botname_size
        name = @@botnames[rand(@@botnames.length)]
      else
        name = @@botnames.delete_at(rand(@@botnames.size))
      end
      #TODO: when I have other bot types, account for intelligence here
      p = RandomPlayer.new(name, @admin)
      @admin.register(p)
    end
  end
  
  #This is called by the admin anytime a player recieves cards.
  #[player] the player that recieved the cards
  #[cards] a list of Card Classes
  def player_recieved_cards(player, cards)
    add_msg("#{player.name} recieved cards")
  end
  
  def add_msg(msg)
    @msg_list.appendItem(Time.now.strftime("%H:%M:%S - #{msg}"))
  end
  
  #This is called by the admin when anyone rolls the dice
  #[player] the acting player
  #[roll] A list (length 2) of the numbers that were rolled
  def player_rolled(player, roll)
    add_msg("#{player.name} rolled a #{roll.sum}")
  end

  #Notify the observer that the game has begun  
  def game_start
    add_msg("Game is starting")
  end
  
  #Inform the observer that the game has finished.
  #[player] the player who won
  #[points] the number of points they won with.
  def game_end(winner, points)
    add_msg("#{winner.name} won the game with #{points} points")
  end
  
  #Inform this observer that a player has joined the game.
  def player_joined(player)
    add_msg("#{player.name} has joined the game")
  end
  
  #Inform this observer that it is the given player's turn
  def get_turn(player, turn_class)
    add_msg("New turn for #{player.name}")
  end  
  
  # Update this observer's version of the board
  # [board] the new version of the board
  def update_board(board)

  end

  # Notify this observer that a road was placed
  # [player] The player that placed the road
  # [x, y, edge] The edge coordinates
  def placed_road(player, x, y, edge)
    add_msg("#{player.name} placed a road at (#{x}, #{y}, #{edge})")
  end

  # Notify this observer that a settlement was placed
  # [player] The player that placed the settlement
  # [x, y, node] The node coordinates
  def placed_settlement(player, x, y, node)
    add_msg("#{player.name} placed a settlement at (#{x}, #{y}, #{node})")
  end

  # Notify this observer that a city was placed
  # [player] The player that placed the city
  # [x, y, node] The node coordinates
  def placed_city(player, x, y, node)
    add_msg("#{player.name} placed a city at (#{x}, #{y}, #{node})")
  end 
  
  
  #This is called by the admin whenever a player steals cards from another player
  #[theif] the player who took the cards
  #[victim] the player who lost cards
  def player_stole_card(theif, victim, num_cards)
    if num_cards == 1
      add_msg("#{theif.name} stole a card from #{victim.name}")    
    else
      add_msg("#{theif.name} stole #{num_cards} cards from #{victim.name}")    
    end
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
  tw = HostDialog.new(application)
  tw.show(PLACEMENT_SCREEN)
  
  # Create the app's windows
  application.create
  # Run the application
  application.run
end
