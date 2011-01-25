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


require 'lib/core/board'
require 'lib/boards/board_impl'
require 'lib/boards/board_manager'
require 'lib/core/admin'
require 'lib/ui/wxruby/wxplayer'
require 'lib/ui/wxruby/log_panel'
require 'lib/core/bots'
require 'wx'
require 'lib/ui/wxruby/form_resource'
require 'lib/core/proxies/settlers_json'
require 'logger'


class RealHostGameDialog < HostGameDialog
  @@bot_intelligence = {'Random' => RandomPlayer, 'Half-a-brain' => SinglePurchasePlayer}
  @@availableColors = ["blue", "red", "white", "orange", "green"]
  
  @@log_levels = [['Errors only', Logger::ERROR], ['Errors and wanrings', Logger::WARN], 
                  ['Errors, warnings, and basic Info', Logger::INFO], ['All', Logger::DEBUG]]
  SETTINGS_FILENAME = 'server.settings'
  
  def initialize(*a)
    super(*a)
    evt_close() {|e| 
      if __FILE__ == $0 
        abort
      else 
        destroy
      end}
      
    evt_button(Wx::ID_CANCEL) {|e| 
      if __FILE__ == $0 
        abort
      else 
        close(true) 
      end}
    evt_button(Wx::ID_OK, :start_server)
    evt_checkbox(@add_yourself_checkbox) do |e| validate; end
    evt_checkbox(@enable_logging_label) do |e| validate; end
    evt_spinctrl(@bot_num_spinner)  do |e| validate; end
    evt_spinctrl(@num_players_spinner)  do |e| validate; end
    evt_radiobutton(@log_to_file) do |e| validate; end
    evt_radiobutton(@to_std_out_check) do |e| validate; end
    evt_button(@browse_button) do |e|
      file_dialog = Wx::FileDialog.new(self, 'Select a log file', '', @log_filename.value, '*.log', Wx::FD_SAVE)
      result = file_dialog.show_modal
      if result == Wx::ID_OK
        @log_filename.value = file_dialog.get_path
      end  
    end
    populate_controls
    #Load last settings
    begin
      File.open(SETTINGS_FILENAME) do |f|
        set_values(Marshal.load(f))
      end
    rescue
      set_values(defaults)
    end
    update
  end

  def populate_controls
    for board, file in BoardManager.get_boards
      @board_choice.append(board.name, board)
    end
    @@bot_intelligence.each{|name, klass| @bot_brain_choice.append(name, klass)}
    @@availableColors.each{|c| @color_choice.append(c,c) }
    @@log_levels.each{|name, value| @log_level_choice.append(name, value) }
  end
  
  def set_values(value_hash)
    @point_spinner.value = value_hash[:max_points].to_i
    @board_choice.set_string_selection(value_hash[:board])
    @num_players_spinner.value = value_hash[:num_players].to_i
    @bot_num_spinner.value = value_hash[:num_bots].to_i
    @bot_brain_choice.set_string_selection(value_hash[:bot_intelligence])
    @add_yourself_checkbox.value = value_hash[:add_yourself]
    @color_choice.set_string_selection(value_hash[:your_color])
    @your_name_text.value = value_hash[:your_name]
    @port_text.value = value_hash[:server_port]
    @enable_logging_label.value = value_hash[:enable_logging]
    @log_level_choice.set_string_selection(value_hash[:log_level])
    @to_std_out_check.value = value_hash[:to_std_out]
    @log_to_file.value = value_hash[:log_to_file_check]
    @log_filename.value = value_hash[:log_filename]
    validate
  end

  #Gets a value Hash  
  def get_values
   {:max_points => @point_spinner.value, 
     :board => @board_choice.get_string_selection,
     :num_players => @num_players_spinner.value, 
     :num_bots => @bot_num_spinner.value, 
     :bot_intelligence => @bot_brain_choice.get_string_selection, 
     :add_yourself => @add_yourself_checkbox.value, 
     :your_name => @your_name_text.value,
     :your_color => @color_choice.get_string_selection,
     :server_port => @port_text.value,
     :enable_logging => @enable_logging_label.value,
     :log_level => @log_level_choice.get_string_selection,
     :to_std_out => @to_std_out_check.value,
     :log_to_file_check => @log_to_file.value,
     :log_filename => @log_filename.value
     }
  end
  
  def validate
    if __FILE__ == $0
      @add_yourself_checkbox.disable
      @add_yourself_checkbox.value = false
    end 
    if @add_yourself_checkbox.value
      @color_choice.enable
      @your_name_text.enable
    else
      @color_choice.disable
      @your_name_text.disable
    end
    if @enable_logging_label.value
      @log_level_choice.enable
      @to_std_out_check.enable
      @log_to_file.enable
      if @log_to_file.value
        @browse_button.enable
        @log_filename.enable
      else
        @browse_button.disable
        @log_filename.disable
      end
    else
      @log_level_choice.disable
      @to_std_out_check.disable
      @log_to_file.disable
      @browse_button.disable
      @log_filename.disable
    end
    @bot_num_spinner.set_range(0, [@num_players_spinner.value, BOT_NAMES.size].min)
  end
  
  def defaults
    {:max_points => 10, 
     :board => 'Standard Board',
     :num_players => 4, 
     :num_bots => 3, 
     :bot_intelligence => 'Half-a-brain', 
     :add_yourself => true, 
     :your_name => 'Player1',
     :your_color => 'red',
     :server_port => '7643',
     :enable_logging => true,
     :log_level => 'Errors and wanrings',
     :to_std_out => false,
     :log_to_file_check => true,
     :log_filename => 'server.log'}
  end  
   
  def save_settings
    File.open(SETTINGS_FILENAME, 'w') do |f|
      Marshal.dump(get_values, f)
    end  
  end
  
  def start_server
    save_settings
    hide
    if @enable_logging_label.value
      level = @log_level_choice.get_item_data(@log_level_choice.get_selection)
      if @to_std_out_check.value     
        $log = Logger.new(STDOUT)
      else
        $log = Logger.new(@log_filename.value)
      end
      $log.level = level
    else
     $log = Logger.new(STDOUT)
     $log.level = Logger::FATAL
    end
    board = @board_choice.get_item_data(@board_choice.get_selection)
    board.randomize_board!
    admin = Admin.new(board, @num_players_spinner.value, @point_spinner.value)
    
    
    if @add_yourself_checkbox.value
      main_frame = RealMainFrame.instance
      human_player = WxPlayer.new(main_frame, @your_name_text.value, admin)
      human_player.preferred_color = @color_choice.get_string_selection
      Thread.new{ main_frame.start_game(admin, human_player) }
      while admin.players.size == 0; sleep(0.02); end      
    end
    
    bots = []
    @bot_num_spinner.value.times do |i|
      klass = @bot_brain_choice.get_item_data(@bot_brain_choice.get_selection)
      bots << klass.new("Player#{i+1}", admin)
    end
    admin.register(*bots)
    
    server = SettlersJSONServer.new(admin, @port_text.value.to_i, $log)
    Thread.new { 
      server.serve
    }

    waiting_message = Wx::MessageDialog.new(RealMainFrame.instance, "Waiting for players to connect...")
    waiting_message.show
    Thread.new{
      while admin.gameThread.nil?; sleep(0.1); end

      if  __FILE__ == $0
        admin.gameThread.join
        server.close
      else
        admin.gameThread.priority = 1
        t = Wx::Timer.new(self, 55)
        evt_timer(55) { Thread.pass }
        t.start(100)
      end
      waiting_message.close
      close
    }
  end
end

if __FILE__ == $0
  Wx::App.run do
    RealHostGameDialog.new.show
  end
end