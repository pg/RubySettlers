require 'drb'
require 'fox16'
require 'fox16/colors'
include Fox

#Join a multiplayer game
class JoinDialog < FXWizard
  include Responder

  DEFAULT_SERVERS = ['localhost:7643', '71.93.107.101:7643']

  def initialize(app, frame)
    @app = app
    @frame = frame
    img = FXPNGIcon.new(app, nil)
    FXFileStream.open("lib/img/join_wizard.png", FXStreamLoad) { |stream| 
      img.loadPixels(stream) 
    }
    img.create    
    super(app, "Join a multiplayer game", img, :width=>600, :height=>276)
    
    selection_frame = FXHorizontalFrame.new(container, :opts=>LAYOUT_FILL_X|LAYOUT_FILL_Y)
    server_frame = FXVerticalFrame.new(selection_frame, :opts=>LAYOUT_FILL_Y, :width=>200)
    FXLabel.new(server_frame, "Select a server")
    server_list = FXList.new(server_frame, :opts=>LAYOUT_FILL_X|LAYOUT_FILL_Y)
    DEFAULT_SERVERS.each{|s| server_list.appendItem(s)}
    @server_name = FXTextField.new(server_frame, 20, nil, FRAME_SUNKEN|FRAME_THICK)
    
    #The right info panel
    rvf = FXVerticalFrame.new(selection_frame, :opts=>LAYOUT_FILL_X|LAYOUT_FILL_Y)
    info_frame = FXGroupBox.new(rvf, "Game info", :opts=>GROUPBOX_TITLE_CENTER|LAYOUT_FILL_Y|LAYOUT_FILL_X|FRAME_THICK|FRAME_GROOVE)
    @get_info_button = FXButton.new(rvf, 'Get Info')
    mat = FXMatrix.new(info_frame, 2)
    FXLabel.new(mat, "Board")
    @board_label = FXLabel.new(mat, "")

    FXLabel.new(mat, "Players")
    @players_label = FXLabel.new(mat, "")

    FXLabel.new(mat, "Max Points")
    @max_points_label = FXLabel.new(mat, "")

    server_list.connect(SEL_CHANGED) do |sender, selector, data|
      
    end
    
    @get_info_button.connect(SEL_COMMAND) do |sender, selector, data|
      server = server_list.getItemText(server_list.currentItem)
      @server_name.text = 
      server_parts = @server_name
      maxPlayers, players, board, points = get_info(@server_name.text)
      @players_label.text = (players.size.to_s + '/' + maxPlayers.to_s) if players and maxPlayers
      @board_label.text = board.name if board
      @max_points_label.text = points.to_s
    end
    
    player_info = FXHorizontalFrame.new(container, :opts=>LAYOUT_FILL_X|LAYOUT_FILL_Y)
    FXLabel.new(player_info, "Player name:")
    @player_name_text = FXTextField.new(player_info, 15, nil, FRAME_SUNKEN|FRAME_THICK)
    
    
    
    FXMAPFUNC(SEL_COMMAND, ID_ACCEPT, :onFinish)
    finishButton.text = 'Join Game'
    #FXMAPFUNC(SEL_COMMAND, ID_CANCEL, :onCancel) if __FILE__ == $0    
  end
  
  #Retrieve game info for a given server.
  def get_info(host, port=7643)
    begin
      admin = DRbObject.new(nil, "druby://#{host}:#{port}")
      return [admin.maxPlayers, admin.players, admin.board, admin.maxPoints]
    rescue DRb::DRbConnError
      return [0, [], nil, 0]
    end
  end

  #Join a game
  def join(host, port, player_name)
    puts "Connecting to #{host}:#{port}"
    DRb.start_service()
    admin = DRbObject.new(nil, "druby://#{host}:#{port}")
    @frame.clear_player_frame
    p = FXPlayer.new(@app, @frame, player_name, admin)
    admin.register(p)
#x    until admin.is_game_done; sleep(0.1); end
  end
 
  def onFinish(sender, selector, data)
    save_settings
    join(@server_name.text, 7643, @player_name_text.text)
    hide
  end
  
  def save_settings
  
  end

end
