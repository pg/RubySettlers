
# This class was automatically generated from XRC source. It is not
# recommended that this file is edited directly; instead, inherit from
# this class and extend its behaviour there.  
#
# Source file: lib/ui/wxruby/FormResource.xrc 
# Generated at: Sun Jun 01 22:07:03 -0400 2008

class AboutDialog < Wx::Dialog
	
	attr_reader :label_1, :label_2
	
	def initialize(parent = nil)
		super()
		xml = Wx::XmlResource.get
		xml.flags = 2 # Wx::XRC_NO_SUBCLASSING
		xml.init_all_handlers
		xml.load("lib/ui/wxruby/FormResource.xrc")
		xml.load_dialog_subclass(self, parent, "aboutDialog")

		finder = lambda do | x | 
			int_id = Wx::xrcid(x)
			begin
				Wx::Window.find_window_by_id(int_id, self) || int_id
			# Temporary hack to work around regression in 1.9.2; remove
			# begin/rescue clause in later versions
			rescue RuntimeError
				int_id
			end
		end
		
		@label_1 = finder.call("label_1")
		@label_2 = finder.call("label_2")
		if self.class.method_defined? "on_init"
			self.on_init()
		end
	end
end



# This class was automatically generated from XRC source. It is not
# recommended that this file is edited directly; instead, inherit from
# this class and extend its behaviour there.  
#
# Source file: lib/ui/wxruby/FormResource.xrc 
# Generated at: Sun Jun 01 22:07:03 -0400 2008

class HelpContents < Wx::Dialog
	
	def initialize(parent = nil)
		super()
		xml = Wx::XmlResource.get
		xml.flags = 2 # Wx::XRC_NO_SUBCLASSING
		xml.init_all_handlers
		xml.load("lib/ui/wxruby/FormResource.xrc")
		xml.load_dialog_subclass(self, parent, "help_dialog")

		finder = lambda do | x | 
			int_id = Wx::xrcid(x)
			begin
				Wx::Window.find_window_by_id(int_id, self) || int_id
			# Temporary hack to work around regression in 1.9.2; remove
			# begin/rescue clause in later versions
			rescue RuntimeError
				int_id
			end
		end
		
		if self.class.method_defined? "on_init"
			self.on_init()
		end
	end
end



# This class was automatically generated from XRC source. It is not
# recommended that this file is edited directly; instead, inherit from
# this class and extend its behaviour there.  
#
# Source file: lib/ui/wxruby/FormResource.xrc 
# Generated at: Sun Jun 01 22:07:03 -0400 2008

class JoinGameDialog < Wx::Dialog
	
	attr_reader :top, :server_name_label, :server_name, :port_label,
              :port_number, :player_name_label, :player_name,
              :preferred_color_label, :preferred_color, :bottom
	
	def initialize(parent = nil)
		super()
		xml = Wx::XmlResource.get
		xml.flags = 2 # Wx::XRC_NO_SUBCLASSING
		xml.init_all_handlers
		xml.load("lib/ui/wxruby/FormResource.xrc")
		xml.load_dialog_subclass(self, parent, "JoinDialog")

		finder = lambda do | x | 
			int_id = Wx::xrcid(x)
			begin
				Wx::Window.find_window_by_id(int_id, self) || int_id
			# Temporary hack to work around regression in 1.9.2; remove
			# begin/rescue clause in later versions
			rescue RuntimeError
				int_id
			end
		end
		
		@top = finder.call("top")
		@server_name_label = finder.call("server_name_label")
		@server_name = finder.call("server_name")
		@port_label = finder.call("port_label")
		@port_number = finder.call("port_number")
		@player_name_label = finder.call("player_name_label")
		@player_name = finder.call("player_name")
		@preferred_color_label = finder.call("preferred_color_label")
		@preferred_color = finder.call("preferred_color")
		@bottom = finder.call("bottom")
		if self.class.method_defined? "on_init"
			self.on_init()
		end
	end
end



# This class was automatically generated from XRC source. It is not
# recommended that this file is edited directly; instead, inherit from
# this class and extend its behaviour there.  
#
# Source file: lib/ui/wxruby/FormResource.xrc 
# Generated at: Sun Jun 01 22:07:03 -0400 2008

class HelpContents < Wx::Dialog
	
	def initialize(parent = nil)
		super()
		xml = Wx::XmlResource.get
		xml.flags = 2 # Wx::XRC_NO_SUBCLASSING
		xml.init_all_handlers
		xml.load("lib/ui/wxruby/FormResource.xrc")
		xml.load_dialog_subclass(self, parent, "help_contents")

		finder = lambda do | x | 
			int_id = Wx::xrcid(x)
			begin
				Wx::Window.find_window_by_id(int_id, self) || int_id
			# Temporary hack to work around regression in 1.9.2; remove
			# begin/rescue clause in later versions
			rescue RuntimeError
				int_id
			end
		end
		
		if self.class.method_defined? "on_init"
			self.on_init()
		end
	end
end



# This class was automatically generated from XRC source. It is not
# recommended that this file is edited directly; instead, inherit from
# this class and extend its behaviour there.  
#
# Source file: lib/ui/wxruby/FormResource.xrc 
# Generated at: Sun Jun 01 22:07:03 -0400 2008

class HostGameDialog < Wx::Dialog
	
	attr_reader :top, :gametab, :board_label, :board_choice,
              :points_label, :point_spinner, :playertab,
              :num_players_label, :num_players_spinner,
              :bot_num_label, :bot_num_spinner, :bot_brain_label,
              :bot_brain_choice, :add_yourself_checkbox,
              :your_name_label, :your_name_text,
              :preferred_color_label, :color_choice, :ruletab,
              :reroll_on_2_checkbox, :systemtab, :port_label,
              :port_text, :enable_logging_label, :log_level_choice,
              :to_std_out_check, :log_to_file, :log_filename,
              :browse_button, :bottom
	
	def initialize(parent = nil)
		super()
		xml = Wx::XmlResource.get
		xml.flags = 2 # Wx::XRC_NO_SUBCLASSING
		xml.init_all_handlers
		xml.load("lib/ui/wxruby/FormResource.xrc")
		xml.load_dialog_subclass(self, parent, "HostDialog")

		finder = lambda do | x | 
			int_id = Wx::xrcid(x)
			begin
				Wx::Window.find_window_by_id(int_id, self) || int_id
			# Temporary hack to work around regression in 1.9.2; remove
			# begin/rescue clause in later versions
			rescue RuntimeError
				int_id
			end
		end
		
		@top = finder.call("top")
		@gametab = finder.call("GameTab")
		@board_label = finder.call("board_label")
		@board_choice = finder.call("board_choice")
		@points_label = finder.call("points_label")
		@point_spinner = finder.call("point_spinner")
		@playertab = finder.call("PlayerTab")
		@num_players_label = finder.call("num_players_label")
		@num_players_spinner = finder.call("num_players_spinner")
		@bot_num_label = finder.call("bot_num_label")
		@bot_num_spinner = finder.call("bot_num_spinner")
		@bot_brain_label = finder.call("bot_brain_label")
		@bot_brain_choice = finder.call("bot_brain_choice")
		@add_yourself_checkbox = finder.call("add_yourself_checkbox")
		@your_name_label = finder.call("your_name_label")
		@your_name_text = finder.call("your_name_text")
		@preferred_color_label = finder.call("preferred_color_label")
		@color_choice = finder.call("color_choice")
		@ruletab = finder.call("RuleTab")
		@reroll_on_2_checkbox = finder.call("reroll_on_2_checkbox")
		@systemtab = finder.call("SystemTab")
		@port_label = finder.call("port_label")
		@port_text = finder.call("port_text")
		@enable_logging_label = finder.call("enable_logging_label")
		@log_level_choice = finder.call("log_level_choice")
		@to_std_out_check = finder.call("to_std_out_check")
		@log_to_file = finder.call("log_to_file")
		@log_filename = finder.call("log_filename")
		@browse_button = finder.call("browse_button")
		@bottom = finder.call("bottom")
		if self.class.method_defined? "on_init"
			self.on_init()
		end
	end
end



# This class was automatically generated from XRC source. It is not
# recommended that this file is edited directly; instead, inherit from
# this class and extend its behaviour there.  
#
# Source file: lib/ui/wxruby/FormResource.xrc 
# Generated at: Sun Jun 01 22:07:03 -0400 2008

class CardSelectorDialog < Wx::Dialog
	
	attr_reader :wood_label, :wood_value_label, :wood_slider,
              :wheat_label, :wheat_value_label, :wheat_slider,
              :sheep_label, :sheep_value_label, :sheep_slider,
              :ore_label, :ore_value_label, :ore_slider, :brick_label,
              :brick_value_label, :brick_slider
	
	def initialize(parent = nil)
		super()
		xml = Wx::XmlResource.get
		xml.flags = 2 # Wx::XRC_NO_SUBCLASSING
		xml.init_all_handlers
		xml.load("lib/ui/wxruby/FormResource.xrc")
		xml.load_dialog_subclass(self, parent, "card_dialog")

		finder = lambda do | x | 
			int_id = Wx::xrcid(x)
			begin
				Wx::Window.find_window_by_id(int_id, self) || int_id
			# Temporary hack to work around regression in 1.9.2; remove
			# begin/rescue clause in later versions
			rescue RuntimeError
				int_id
			end
		end
		
		@wood_label = finder.call("wood_label")
		@wood_value_label = finder.call("wood_value_label")
		@wood_slider = finder.call("wood_slider")
		@wheat_label = finder.call("wheat_label")
		@wheat_value_label = finder.call("wheat_value_label")
		@wheat_slider = finder.call("wheat_slider")
		@sheep_label = finder.call("sheep_label")
		@sheep_value_label = finder.call("sheep_value_label")
		@sheep_slider = finder.call("sheep_slider")
		@ore_label = finder.call("ore_label")
		@ore_value_label = finder.call("ore_value_label")
		@ore_slider = finder.call("ore_slider")
		@brick_label = finder.call("brick_label")
		@brick_value_label = finder.call("brick_value_label")
		@brick_slider = finder.call("brick_slider")
		if self.class.method_defined? "on_init"
			self.on_init()
		end
	end
end



# This class was automatically generated from XRC source. It is not
# recommended that this file is edited directly; instead, inherit from
# this class and extend its behaviour there.  
#
# Source file: lib/ui/wxruby/FormResource.xrc 
# Generated at: Sun Jun 01 22:07:03 -0400 2008

class TradeDialog < Wx::Dialog
	
	attr_reader :wood_want_check, :brick_want_check, :wheat_want_check,
              :sheep_want_check, :ore_want_check, :wood_give_check,
              :brick_give_check, :wheat_give_check, :sheep_give_check,
              :ore_give_check, :quote_request_button, :quote_list,
              :quote_accept_button, :chat_text_box, :chat_input_panel,
              :chat_input_text, :chat_send_button
	
	def initialize(parent = nil)
		super()
		xml = Wx::XmlResource.get
		xml.flags = 2 # Wx::XRC_NO_SUBCLASSING
		xml.init_all_handlers
		xml.load("lib/ui/wxruby/FormResource.xrc")
		xml.load_dialog_subclass(self, parent, "trade_dialog")

		finder = lambda do | x | 
			int_id = Wx::xrcid(x)
			begin
				Wx::Window.find_window_by_id(int_id, self) || int_id
			# Temporary hack to work around regression in 1.9.2; remove
			# begin/rescue clause in later versions
			rescue RuntimeError
				int_id
			end
		end
		
		@wood_want_check = finder.call("wood_want_check")
		@brick_want_check = finder.call("brick_want_check")
		@wheat_want_check = finder.call("wheat_want_check")
		@sheep_want_check = finder.call("sheep_want_check")
		@ore_want_check = finder.call("ore_want_check")
		@wood_give_check = finder.call("wood_give_check")
		@brick_give_check = finder.call("brick_give_check")
		@wheat_give_check = finder.call("wheat_give_check")
		@sheep_give_check = finder.call("sheep_give_check")
		@ore_give_check = finder.call("ore_give_check")
		@quote_request_button = finder.call("quote_request_button")
		@quote_list = finder.call("quote_list")
		@quote_accept_button = finder.call("quote_accept_button")
		@chat_text_box = finder.call("chat_text_box")
		@chat_input_panel = finder.call("chat_input_panel")
		@chat_input_text = finder.call("chat_input_text")
		@chat_send_button = finder.call("chat_send_button")
		if self.class.method_defined? "on_init"
			self.on_init()
		end
	end
end



# This class was automatically generated from XRC source. It is not
# recommended that this file is edited directly; instead, inherit from
# this class and extend its behaviour there.  
#
# Source file: lib/ui/wxruby/FormResource.xrc 
# Generated at: Sun Jun 01 22:07:03 -0400 2008

class MainFrame < Wx::Frame
	
	attr_reader :mainframe_menubar, :quickstartmenuitem, :joinmenuitem,
              :hostmenuitem, :roll_menu_item, :trade_menu_item,
              :buy_dev_card_menu_item, :done_menu_item,
              :soldier_menu_item, :monopoly_menu_item,
              :yearofplenty_menu_item, :roadbuilding_menu_item,
              :boardbuildermenu, :userprefmenu, :helpcontentsmenu,
              :board_panel, :player_panel, :chat_panel, :chattext,
              :chatinput, :chat_button, :log_panel, :event_log_text,
              :card_panel, :actions_panel, :roll_button,
              :trade_button, :buy_dev_card_button, :done_button,
              :waiting_text, :soldier_button, :yearofplenty_button,
              :monopoly_button, :roadbuilding_button
	
	def initialize(parent = nil)
		super()
		xml = Wx::XmlResource.get
		xml.flags = 2 # Wx::XRC_NO_SUBCLASSING
		xml.init_all_handlers
		xml.load("lib/ui/wxruby/FormResource.xrc")
		xml.load_frame_subclass(self, parent, "mainFrame")

		finder = lambda do | x | 
			int_id = Wx::xrcid(x)
			begin
				Wx::Window.find_window_by_id(int_id, self) || int_id
			# Temporary hack to work around regression in 1.9.2; remove
			# begin/rescue clause in later versions
			rescue RuntimeError
				int_id
			end
		end
		
		@mainframe_menubar = finder.call("mainFrame_menubar")
		@quickstartmenuitem = finder.call("quickStartMenuItem")
		@joinmenuitem = finder.call("joinMenuItem")
		@hostmenuitem = finder.call("hostMenuItem")
		@roll_menu_item = finder.call("roll_menu_item")
		@trade_menu_item = finder.call("trade_menu_item")
		@buy_dev_card_menu_item = finder.call("buy_dev_card_menu_item")
		@done_menu_item = finder.call("done_menu_item")
		@soldier_menu_item = finder.call("soldier_menu_item")
		@monopoly_menu_item = finder.call("monopoly_menu_item")
		@yearofplenty_menu_item = finder.call("yearofplenty_menu_item")
		@roadbuilding_menu_item = finder.call("roadbuilding_menu_item")
		@boardbuildermenu = finder.call("BoardBuilderMenu")
		@userprefmenu = finder.call("UserPrefMenu")
		@helpcontentsmenu = finder.call("HelpContentsMenu")
		@board_panel = finder.call("board_panel")
		@board_panel.extend(BoardPanel)
		@player_panel = finder.call("player_panel")
		@player_panel.extend(PlayerPanel)
		@chat_panel = finder.call("chat_panel")
		@chattext = finder.call("ChatText")
		@chatinput = finder.call("ChatInput")
		@chat_button = finder.call("chat_button")
		@log_panel = finder.call("log_panel")
		@event_log_text = finder.call("event_log_text")
		@event_log_text.extend(EventLogText)
		@card_panel = finder.call("card_panel")
		@card_panel.extend(CardPanel)
		@actions_panel = finder.call("actions_panel")
		@actions_panel.extend(ActionPanel)
		@roll_button = finder.call("roll_button")
		@trade_button = finder.call("trade_button")
		@buy_dev_card_button = finder.call("buy_dev_card_button")
		@done_button = finder.call("done_button")
		@waiting_text = finder.call("waiting_text")
		@soldier_button = finder.call("soldier_button")
		@yearofplenty_button = finder.call("yearofplenty_button")
		@monopoly_button = finder.call("monopoly_button")
		@roadbuilding_button = finder.call("roadbuilding_button")
		if self.class.method_defined? "on_init"
			self.on_init()
		end
	end
end



# This class was automatically generated from XRC source. It is not
# recommended that this file is edited directly; instead, inherit from
# this class and extend its behaviour there.  
#
# Source file: lib/ui/wxruby/FormResource.xrc 
# Generated at: Sun Jun 01 22:07:03 -0400 2008

class PlayerSelector < Wx::Dialog
	
	attr_reader :player_sizer
	
	def initialize(parent = nil)
		super()
		xml = Wx::XmlResource.get
		xml.flags = 2 # Wx::XRC_NO_SUBCLASSING
		xml.init_all_handlers
		xml.load("lib/ui/wxruby/FormResource.xrc")
		xml.load_dialog_subclass(self, parent, "player_selector")

		finder = lambda do | x | 
			int_id = Wx::xrcid(x)
			begin
				Wx::Window.find_window_by_id(int_id, self) || int_id
			# Temporary hack to work around regression in 1.9.2; remove
			# begin/rescue clause in later versions
			rescue RuntimeError
				int_id
			end
		end
		
		@player_sizer = finder.call("player_sizer")
		if self.class.method_defined? "on_init"
			self.on_init()
		end
	end
end



# This class was automatically generated from XRC source. It is not
# recommended that this file is edited directly; instead, inherit from
# this class and extend its behaviour there.  
#
# Source file: lib/ui/wxruby/FormResource.xrc 
# Generated at: Sun Jun 01 22:07:03 -0400 2008

class SingleCardSelectorDialog < Wx::Dialog
	
	def initialize(parent = nil)
		super()
		xml = Wx::XmlResource.get
		xml.flags = 2 # Wx::XRC_NO_SUBCLASSING
		xml.init_all_handlers
		xml.load("lib/ui/wxruby/FormResource.xrc")
		xml.load_dialog_subclass(self, parent, "single_card_selector")

		finder = lambda do | x | 
			int_id = Wx::xrcid(x)
			begin
				Wx::Window.find_window_by_id(int_id, self) || int_id
			# Temporary hack to work around regression in 1.9.2; remove
			# begin/rescue clause in later versions
			rescue RuntimeError
				int_id
			end
		end
		
		if self.class.method_defined? "on_init"
			self.on_init()
		end
	end
end



# This class was automatically generated from XRC source. It is not
# recommended that this file is edited directly; instead, inherit from
# this class and extend its behaviour there.  
#
# Source file: lib/ui/wxruby/FormResource.xrc 
# Generated at: Sun Jun 01 22:07:03 -0400 2008

class StartupDialog < Wx::Dialog
	
	attr_reader :startup_quick_start_button, :startup_host_button,
              :startup_join_button
	
	def initialize(parent = nil)
		super()
		xml = Wx::XmlResource.get
		xml.flags = 2 # Wx::XRC_NO_SUBCLASSING
		xml.init_all_handlers
		xml.load("lib/ui/wxruby/FormResource.xrc")
		xml.load_dialog_subclass(self, parent, "startup_dialog")

		finder = lambda do | x | 
			int_id = Wx::xrcid(x)
			begin
				Wx::Window.find_window_by_id(int_id, self) || int_id
			# Temporary hack to work around regression in 1.9.2; remove
			# begin/rescue clause in later versions
			rescue RuntimeError
				int_id
			end
		end
		
		@startup_quick_start_button = finder.call("startup_quick_start_button")
		@startup_host_button = finder.call("startup_host_button")
		@startup_join_button = finder.call("startup_join_button")
		if self.class.method_defined? "on_init"
			self.on_init()
		end
	end
end



# This class was automatically generated from XRC source. It is not
# recommended that this file is edited directly; instead, inherit from
# this class and extend its behaviour there.  
#
# Source file: lib/ui/wxruby/FormResource.xrc 
# Generated at: Sun Jun 01 22:07:03 -0400 2008

class MakeTradeOfferDialog < Wx::Dialog
	
	attr_reader :wood_give_spinner, :brick_give_spinner,
              :wheat_give_spinner, :sheep_give_spinner,
              :ore_give_spinner, :wood_want_spinner,
              :brick_want_spinner, :wheat_want_spinner,
              :sheep_want_spinner, :ore_want_spinner, :notice_text,
              :chat_text_box, :chat_input_panel, :chat_input_text,
              :chat_send_button, :make_offer_button
	
	def initialize(parent = nil)
		super()
		xml = Wx::XmlResource.get
		xml.flags = 2 # Wx::XRC_NO_SUBCLASSING
		xml.init_all_handlers
		xml.load("lib/ui/wxruby/FormResource.xrc")
		xml.load_dialog_subclass(self, parent, "make_trade_offer_dialog")

		finder = lambda do | x | 
			int_id = Wx::xrcid(x)
			begin
				Wx::Window.find_window_by_id(int_id, self) || int_id
			# Temporary hack to work around regression in 1.9.2; remove
			# begin/rescue clause in later versions
			rescue RuntimeError
				int_id
			end
		end
		
		@wood_give_spinner = finder.call("wood_give_spinner")
		@brick_give_spinner = finder.call("brick_give_spinner")
		@wheat_give_spinner = finder.call("wheat_give_spinner")
		@sheep_give_spinner = finder.call("sheep_give_spinner")
		@ore_give_spinner = finder.call("ore_give_spinner")
		@wood_want_spinner = finder.call("wood_want_spinner")
		@brick_want_spinner = finder.call("brick_want_spinner")
		@wheat_want_spinner = finder.call("wheat_want_spinner")
		@sheep_want_spinner = finder.call("sheep_want_spinner")
		@ore_want_spinner = finder.call("ore_want_spinner")
		@notice_text = finder.call("notice_text")
		@chat_text_box = finder.call("chat_text_box")
		@chat_input_panel = finder.call("chat_input_panel")
		@chat_input_text = finder.call("chat_input_text")
		@chat_send_button = finder.call("chat_send_button")
		@make_offer_button = finder.call("make_offer_button")
		if self.class.method_defined? "on_init"
			self.on_init()
		end
	end
end


