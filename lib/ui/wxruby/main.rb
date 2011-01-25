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

require 'logger'
require 'lib/core/board'
require 'lib/boards/board_impl'
require 'lib/core/admin'
require 'rubygems'
require 'wx'
require 'lib/ui/wxruby/wxplayer'
require 'lib/ui/wxruby/log_panel'
require 'lib/ui/wxruby/player_panel'
require 'lib/ui/wxruby/card_panel'
require 'lib/ui/wxruby/board_panel'
require 'lib/ui/wxruby/wxplayer_states'
require 'lib/ui/wxruby/form_resource'
require 'lib/ui/wxruby/host_dialog'
require 'lib/ui/wxruby/join_dialog'
require 'lib/ui/wxruby/selection_dialogs'
require 'lib/ui/wxruby/trade_dialogs'
require 'lib/ui/wxruby/action_panel'
require 'lib/ui/wxruby/startup_dialog'

$log = Logger.new(STDOUT)
$log.level = Logger::DEBUG

$player_color_map = {"blue" => Wx::BLUE, 
                     "red"=> Wx::RED,  
                     "white"=> Wx::WHITE,  
                     "orange"=> Wx::Colour.new(255, 165, 0),  
                     "green"=> Wx::Colour.new(0, 200, 0), 
                     "brown"=>Wx::Colour.new(139,69,19)} 
                     
$player_color_brushes = {}
                  
$__wx_app_ended__ = false

class RealMainFrame < MainFrame
  attr_accessor :admin
  attr_reader :trade_dialog, :offer_trade_dialog, :human_player
  @@instance = nil
  
  DARK_BLUE = Wx::Colour.new(0,0,80)
  
  def self.instance(*a)
    @@instance = self.new(*a) unless @@instance
    @@instance
  end
  
  def human_player=(player)
    @human_player = player
    @human_player.register_listener(WaitingListener.new)
  end
  
  def destroy(*a)
    @gui_thread.kill if @gui_thread
    super
  end
  
  def on_exit(*a) 
    destroy
  end
  
  def on_quick_start_menu()
    #Test
    board = StandardBoard.new
    admin = Admin.new(board, 3, 10)
    human_player = WxPlayer.new(self, 'You', admin)
    names = RealHostGameDialog::BOT_NAMES.dup
    bot_name = lambda do
       n = names.delete_at(rand(names.size))
       puts "Using bot: #{n}"
       n
    end
    p2 = SinglePurchasePlayer.new(bot_name.call, admin)
    p3 = SinglePurchasePlayer.new(bot_name.call, admin)
    bots = [p2,p3]
    bots.each{|b| b.chatter = true; b.delay = 2 }
    @gui_thread = Thread.current
    start_game(admin, human_player, bots)
  end
  
  def enable_gui_sleep
    @use_gui_sleep = true
    @admin.gameThread.priority = 0 if @admin and @admin.gameThread
  end
  
  def disable_gui_sleep
    @use_gui_sleep = false
    @admin.gameThread.priority = 1 if @admin and @admin.gameThread
    sleep(0.2)
  end
  
  def start_game(admin, human, bots=[])
    @admin = admin
    @aui_panels.keys.each{|pane| pane.enable}
    self.human_player = human
    @chattext.clear
    admin.register(human, *bots)
    
    t = Wx::Timer.new(self, 20)
    evt_timer(20) { sleep(0.05) if @use_gui_sleep}
    t.start(20)       

#    admin.gameThread.priority = 1
#    Thread.current.priority = 1
  end
  
  def on_join_menu() RealJoinGameDialog.new(self).show; end
  def on_host_menu() RealHostGameDialog.new(self).show; end
  def on_board_builder_menu() close(true); end
  def on_user_pref_menu() close(true); end
  def on_help_contents() HelpContents.new(self).show; end
  def on_about() AboutDialog.new(self).show; end

  #button events
  def on_chat
    if @chatinput.value and @chatinput.value.size > 0
      @human_player.admin.chat_msg(@human_player, @chatinput.value) 
      @chatinput.value = ''
    end
  end

  #Get the user-friendly name for the resource
  #TODO: put this in user preferences!
  def get_resource_alias(resource_class)
    aliases = {BrickType => 'Brick', WoodType => 'Wood', SheepType => 'Sheep', WheatType => 'Wheat', OreType => 'Ore'}
    return aliases[resource_class]
  end
  
  def show(*a)
     super(*a)
     RealStartupDialog.new(self).show_modal
  end  
  
  private 
    
  def initialize(*a)
    super(*a)
    init_event_handlers
    enable_gui_sleep
    @actions_panel.init(self)
    @trade_dialog = RealTradeDialog.new(self)
    @offer_trade_dialog = RealOfferTradeDialog.new(self)
    #init the AUI info
    @mgr = Wx::AuiManager.new
    @mgr.set_managed_window(self)
    dockart = @mgr.get_art_provider
    
    dockart.set_color(Wx::AUI_DOCKART_BACKGROUND_COLOUR, Wx::BLUE)
    dockart.set_color(Wx::AUI_DOCKART_SASH_COLOUR, Wx::BLUE)
    dockart.set_color(Wx::AUI_DOCKART_ACTIVE_CAPTION_COLOUR, Wx::BLUE)
    dockart.set_color(Wx::AUI_DOCKART_ACTIVE_CAPTION_GRADIENT_COLOUR, Wx::BLUE)
    dockart.set_color(Wx::AUI_DOCKART_BORDER_COLOUR, Wx::BLUE)
    dockart.set_color(Wx::AUI_DOCKART_GRIPPER_COLOUR, Wx::BLUE)

    dockart.set_color(Wx::AUI_DOCKART_INACTIVE_CAPTION_COLOUR, Wx::BLUE)
    dockart.set_color(Wx::AUI_DOCKART_INACTIVE_CAPTION_GRADIENT_COLOUR, Wx::Colour.new(150,150,255))
    dockart.set_font(Wx::AUI_DOCKART_CAPTION_FONT, Wx::Font.new(13, Wx::FONTFAMILY_DEFAULT, Wx::FONTSTYLE_NORMAL, Wx::FONTWEIGHT_NORMAL))
    
    @aui_panels = {
      @board_panel =>  ['Board',   0, 500, 500, :centre, 0],
      @actions_panel=> ['Actions', 1, 80,  70,  :bottom, 0],
      @card_panel =>   ['Cards',   1, 150, 150, :bottom, 1],
      @player_panel => ['Players', 5, 260, 200, :right,  0],
      @chat_panel =>   ['Chat',    5, 260, 200, :right,  1],
      @log_panel =>    ['Events',  5, 260, 200, :right,  2],
    }
    
    #at work    
    hide_these_panels = [@card_panel, @log_panel]
    #hide_these_panels.each{|p| @aui_panels.delete(p); p.hide; }
    #set_size(400,200) # At Work
    
    for panel, params in @aui_panels
      caption, level, w, h, direction, pos = params
      pi = Wx::AuiPaneInfo.new
      pi.set_caption(caption).send(direction).set_best_size(w, h).set_position(pos)
      pi.set_close_button(false)
      pi.dock_layer = level
      panel.disable
      @mgr.add_pane(panel, pi)
    end
    @mgr.update
  end
  
  def init_event_handlers
    evt_menu Wx::ID_EXIT, :on_exit
    evt_menu quickstartmenuitem, :on_quick_start_menu
    evt_menu joinmenuitem, :on_join_menu
    evt_menu hostmenuitem, :on_host_menu
    evt_menu boardbuildermenu, :on_board_builder_menu
    evt_menu userprefmenu, :on_user_pref_menu
    evt_menu helpcontentsmenu, :on_help_contents
    evt_menu Wx::ID_ABOUT, :on_about
    evt_button(@chat_button, :on_chat)
    evt_text_enter(@chatinput, :on_chat)
    
    actions = {:roll => Wx::K_F1,
               :trade => Wx::K_F2,
               :buy_dev_card => Wx::K_F3,
               :done => Wx::K_F4,
               :yearofplenty => Wx::K_F5,
               :soldier => Wx::K_F6,
               :monopoly => Wx::K_F7,
               :roadbuilding => Wx::K_F8}
               
    entries = []   
    for name, key in actions
      name = name.to_s
      button = send(name + '_button')
      @actions_panel.evt_button(button, "on_#{name}_button".to_sym)
      menu_item_id = send(name + '_menu_item')   
      entries << Wx::AcceleratorEntry.new(Wx::ACCEL_NORMAL, key, menu_item_id)
      menu_bar.find_item(menu_item_id).enable(false)
    end
    evt_menu(roll_menu_item) do |e| @actions_panel.on_roll_button(e) if @roll_button.is_enabled; end
    evt_menu(trade_menu_item) do |e| @actions_panel.on_trade_button(e) if @trade_button.is_enabled; end
    evt_menu(buy_dev_card_menu_item) do |e| @actions_panel.on_buy_dev_card_button(e) if @buy_dev_card_button.is_enabled; end
    evt_menu(done_menu_item) do |e| @actions_panel.on_done_button(e) if @done_button.is_enabled; end


    table = Wx::AcceleratorTable.new(entries)                                     
    self.set_accelerator_table(table)
       
    @card_panel.evt_paint(:paint_dc)
    @board_panel.evt_paint(:paint_dc)
    @board_panel.set_auto_layout(true)
    @board_panel.evt_size(:on_size)
    @board_panel.evt_motion(:on_mouse_move)
    @board_panel.evt_left_up(:on_mouse_click)
    @board_panel.evt_leave_window(:on_mouse_leave)  
  end
end


class MainApplication < Wx::App
  def on_init
    $dark_blue_brush = Wx::Brush.new(RealMainFrame::DARK_BLUE)
    $player_color_map.each{|color_name, color|
      $player_color_brushes[color_name] = Wx::Brush.new(color)
    }       
    RealMainFrame.instance.show
    true
  end
end


def start_main_loop
  app = MainApplication.new
  app.main_loop
end

if __FILE__ == $0
  start_main_loop
end

