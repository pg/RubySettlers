


class RealJoinGameDialog < JoinGameDialog
  
  @@availableColors = ["blue", "red", "white", "orange", "green"]
  SETTINGS_FILENAME = 'client.settings'
  
  def initialize(*a)
    super
    @@availableColors.each{|c| @preferred_color.append(c,c) }
    #Load last settings
    begin
      File.open(SETTINGS_FILENAME) do |f|
        set_values(Marshal.load(f))
      end
    rescue
      set_values(defaults)
    end
    evt_button(Wx::ID_OK, :join_game)
  end

  def set_values(value_hash)
    @player_name.value = value_hash[:player_name]
    @server_name.value = value_hash[:server_name]
    @port_number.value = value_hash[:port_number]
    @preferred_color.set_string_selection(value_hash[:preferred_color])
  end
  
  def get_values
   {:player_name => @player_name.value, 
     :server_name => @server_name.value,
     :port_number => @port_number.value,
     :preferred_color => @preferred_color.get_string_selection}
  end
  
  def defaults
    {:player_name => 'NewPlayer',
     :server_name => 'localhost',
     :port_number =>  '7643',
     :preferred_color => 'red'}
  end
  
  def save_settings
    File.open(SETTINGS_FILENAME, 'w') do |f|
      Marshal.dump(get_values, f)
    end  
  end

  def join_game
    client = SettlersJSONClient.new(@server_name.value, @port_number.value, $log)
    admin = client.initial_object
    main_frame = RealMainFrame.instance
    t = Wx::Timer.new(self, 20)
    evt_timer(20) { sleep(0.1)}
    t.start(20)       
    human_player = WxPlayer.new(main_frame, @player_name.value, admin)
    human_player.preferred_color = @preferred_color.get_string_selection
    main_frame.start_game(admin, human_player)
    save_settings
    close
  end  
end