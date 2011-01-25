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
require 'timeout'
require 'fox16'
require 'fox16/colors'
include Fox

require 'lib/core/player'
require 'lib/core/admin'
require 'lib/core/game_definition'
require 'lib/ui/board_viewer'
require 'lib/ui/fxruby/fxplayer_states'
require 'lib/ui/fxruby/status_panel'
require 'lib/ui/fxruby/trade_dialog'
require 'lib/ui/fxruby/card_selector_dialog'
require 'lib/ui/fxruby/card_viewer_widget'



class FXPlayer < Player
  include BoardViewer
  attr_accessor :current_state
  attr_reader :admin, :proximity, :frame, :scale, :leftMostCoord, :app
  
  IMAGE_FILES = {OreType=>'ore.tif',
                   WheatType=>'wheat.tif',
                   WoodType=>'wood.tif',
                   BrickType=>'brick.tif',
                   DesertType=>'desert.tif',
                   SheepType=>'sheep.tif'}
                   
  @@cached_images = {}                   
               
  
  
  # Create a new Interactive FXplayer.  This is a Player object that inserts a
  # FXFrame onto the given frame object.  It waits for human interaction for 
  # making moves.
  # [app] The FXApplication object
  # [frame] The parent FXWindow for this 
  # [name] The player's name
  # [admin] A reference to the game Admin
  def initialize(app, frame, name, admin, cities=4, settlements=5, roads=15)
    super(name, admin, cities, settlements, roads)
    initialize_viewer
  
    @board_image = nil
    @frame = frame
    @app = app
    @admin = admin
    @player = self
    @proximity = 10
    @app = app
    @canvas_widgets = []
  #  set_board_dimensions(0, 0, 100, 100)
        
    @current_state = FinishedTurnState.new(self)
    
    main_frame = FXHorizontalFrame.new(frame, LAYOUT_FILL_X|LAYOUT_FILL_Y, :padding => 0, :vSpacing => 0)
    left_panel = FXVerticalFrame.new(main_frame, :opts => LAYOUT_FILL_Y|LAYOUT_FILL_X,  :padding => 0)
    @right_info_panel = FXVerticalFrame.new(main_frame, FRAME_SUNKEN|FRAME_THICK|LAYOUT_FILL_Y, :width=>380)
    @right_info_panel.connect(SEL_KEYPRESS, method(:on_keypress))
#    @right_info_panel.hide #at work

#    @bottom_panel = FXHorizontalFrame.new(left_panel, :opts =>LAYOUT_FILL_X,  :padding => 0)


    #The Panel with each player's status
    @status_panel = PlayerStatusPanel.new(self, admin, @right_info_panel, :opts => LAYOUT_FILL_X)
    @message_panel = MessagePanel.new(@right_info_panel, :opts => LAYOUT_FILL_X|LAYOUT_FILL_Y)
    @status_panel.connect(SEL_KEYPRESS, method(:on_keypress))
    @message_panel.connect(SEL_KEYPRESS, method(:on_keypress))


    #The Cost card on the right hand side
    @key_image = FXJPGIcon.new(@app, nil)
    filename = 'key.jpg'
    FXFileStream.open("lib/img/#{filename}", FXStreamLoad) { |stream| 
      @key_image.loadPixels(stream) 
    }
    scale = 0.8
    @key_image.scale((@key_image.width*scale).to_i, (@key_image.height*scale).to_i)
    @key_image.create
    
#    @bottom_canvas = FXCanvas.new(bottom_spring, :opts => LAYOUT_FILL_X|LAYOUT_FILL_Y|LAYOUT_BOTTOM|LAYOUT_LEFT)
#    @bottom_canvas.connect(SEL_PAINT) do |sender, sel, event|
#       update_card_frame
#    end
#    @bottom_canvas.connect(SEL_KEYPRESS, method(:on_keypress))
    
    # Drawing canvas
    @canvas = FXCanvas.new(left_panel, :opts => LAYOUT_FILL_X|LAYOUT_FILL_Y|LAYOUT_TOP|LAYOUT_LEFT)
    @canvas.connect(SEL_PAINT) do |sender, sel, event|
      draw_board if calculated_coordinate_data?
    end   
    @canvas.connect(SEL_KEYPRESS, method(:on_keypress))
    @canvas.connect(SEL_MOTION, method(:on_canvas_mouse_motion))
    @canvas.connect(SEL_LEFTBUTTONPRESS, method(:on_canvas_left_click))
    @canvas.connect(SEL_UPDATE, method(:on_frame_update))
    @widget_manager = WidgetManager.new(@app, @canvas, self)

    @action_widget = ActionWidget.new(@app, @canvas, self)
    @action_widget.anchor = ExpandableWidget::ANCHOR_BOTTOM | ExpandableWidget::ANCHOR_LEFT
    @action_widget.x = 0
    @widget_manager.add(@action_widget)


    @card_viewer = CardViewer.new(@app, @canvas, self)
    @card_viewer.anchor = ExpandableWidget::ANCHOR_BOTTOM | ExpandableWidget::ANCHOR_LEFT
    @widget_manager.add(@card_viewer)
    
    
    @canvas_widgets << @card_viewer
    
    
    @scale_changed = false
    
    @frame.create
    @frame.layout
    @frame.show
  end

  def on_frame_update(sender, sel, event)
    @widget_manager.invalidate
    height = @canvas.height - [@card_viewer.height, @action_widget.height].max
    set_canvas_size(@canvas.width, height)
  end
  
  #this method will update the canvas size
  #and re-calcuate the board dimensions
  def set_canvas_size(width, height)
    dimensions = [width, height]
    if dimensions != @last_canvas_dimensions and @gui_board
      puts 'Changing Dimensions'
      STDOUT.flush
      set_board_dimensions(0, 0, width, height)
      @scale_changed = true
      update_board(@board)
      @last_canvas_dimensions = dimensions
    end
  end
  
  def on_keypress(sender, sel, event)
    if event.code == 65474 #F5
      @action_widget.on_roll if @action_widget.dice.enabled
    elsif event.code == 65475 #F6
      @action_widget.on_trade if @action_widget.trade.enabled
    elsif event.code == 65476 #F7
      @action_widget.on_buy_dev_card if @action_widget.buy_dev_card.enabled
    elsif event.code == 65477 #F8
      @action_widget.on_done if @action_widget.done.enabled
    elsif event.code == 65475 #F9
      nil
    end
  end
  
  #This method is called whenever there is mouse motion over the main canvas
  def on_canvas_mouse_motion(sender, sel, event)
    @current_state.on_canvas_mouse_motion(sender, sel, event)
  end
  
  #This method is called whenever there is left click on the main canvas
  def on_canvas_left_click(sender, sel, event)
    @current_state.on_canvas_left_click(sender, sel, event)
  end
  
  #Add a message to the message panel
  def add_message(player_info, text)
    text = "#{player_info.name} #{text}" if player_info.color != @color
    if @current_turn_msg
      @current_turn_msg.add_msg(text)
    else
      puts text
    end
#    @message_panel.appendItem(msg)
    @message_panel.layout
  end
  
  
  def take_turn(turn)
    super(turn)
    if turn.is_a?(SetupTurn)
      $log.debug("#{self} Changing state to SetupTurnState")  
      @current_state = SetupTurnState.new(self)
      @current_state.validate_action_widget(@action_widget)
    else
      $log.debug("#{self} Changing state to NormalTurnState")
      @current_state = NormalTurnState.new(self)
      @current_state.validate_action_widget(@action_widget)
      
    end
    update_board(@board)
  end
  
  #Inform this observer that it is the given player's turn
  def get_turn(player, turn_class)
    @current_turn_msg = @message_panel.add_turn(player)
  end
  
  def get_resource_alias(res)
    @@resource_aliases[res]
  end
  
  @@resource_aliases = {OreType=>"ore", 
                       WheatType=>"wheat",
                       SheepType=>"sheep",
                       WoodType=>"wood",
                       BrickType=>"brick"}
  
  def inform(player_info, msg)
    super
    add_message(player_info, msg)
  end

  # Remove cards from this players hand
  # Return false the there aren't sufficent cards
  # [cards] an Array of card types
  def del_cards(cards) 
    success = super
    update_card_frame
    @status_panel.update
    return success
  end

  # Tell this player that they received more cards.
  def add_cards(cards)
    super
    update_card_frame  
    @status_panel.update
  end
  
  def build_card_string(card_list)
    counts = RESOURCE_TYPES.map{|res| 
      count = card_list.count(res)
      (count.to_s + " " + @@resource_aliases[res]) if count > 0
    }.compact.join(', ')
    counts
  end
  
  #Tell this player to move the bandit
  #[old_hex] the hex where the bandit currently sits
  #return a new hex
  #TODO: replace this with real interaction
  def move_bandit(old_hex)
    initial_state = @current_state 
    $log.debug("#{name} told to move bandit")
    $log.debug("app=#{@app}")
    $log.debug("#{self} Changing state to MovingBanditState")
    @current_state = MovingBanditState.new(self)
    @current_state.validate_action_widget(@action_widget)
    while not @current_state.chosen_hex 
      sleep(0.5)
      $log.debug('still moving bandit')
    end
    hex = @current_state.chosen_hex 
    $log.debug("#{self} Changing state to #{initial_state}")
    @current_state = initial_state
    @current_state.validate_action_widget(@action_widget)
    hex
  end
  
  #Ask the player to choose a player among the given list of PlayerInfo objects
  def select_player(players)
    $log.debug("#{name} told to select a player from #{players.join(',')}")
    other = players.find{|p| p != self}
    raise Exception.new("I'm being forced to select myself") unless other
    other
  end
  
  #Ask the player to select some cards from a list.
  #This is used when a player must discard
  def select_resource_cards(cards, count)
    card_classes = cards.uniq
  
    #count the number of occurances in the list
    def count(list, test)
      sum = 0
      list.each{|o| sum += 1 if o == test}
      sum
    end
    items = card_classes.map{|t| [t, get_resource_alias(t), count(cards, t)]}
    selected_cards = CardSelectorDialog.get_card_counts(@app, 
                                               "Select #{count} resources to discard", 
                                               items, count)
    #remove unwanted cards from the list                                               
    selected_cards.map{|type, c| [type] * c }.flatten
  end
  
  ##IObserver methods##
  
  #This is called by the admin anytime a player receives cards.
  #[player] the player that received the cards
  #[cards] a list of Card Classes
  def player_received_cards(player_info, cards)
   add_message(player_info, "received #{cards.size} cards")    
  end

  #This is called by the admin when anyone rolls the dice
  #[player] the acting player
  #[roll] A list (length 2) of the numbers that were rolled
  def player_rolled(player_info, roll)
    add_message(player_info, "rolled a #{roll.sum}")    
  end 

  #This is called by the admin whenever a player steals cards from another player
  #[theif] the player who took the cards
  #[victim] the player who lost cards
  def player_stole_card(theif, victim, num_cards)
    if num_cards == 1
      add_message(theif, "stole a card from #{victim.name}")    
    else
      add_message(theif, "stole #{num_cards} cards from #{victim.name}")    
    end
  end
      
  def player_moved_bandit(player_info, new_hex)
    super
    draw_board
    nil
  end

      
  #Notify the observer that the game has begun  
  def game_start
  
  end

  #Inform the observer that the game has finished.
  #[player] the player who won
  #[points] the number of points they won with.
  def game_end(winner, points)
    if winner == self
      FXMessageBox::information(@frame, DECOR_ALL, "Horray!", "You won the game with #{points} points!")
    else
      FXMessageBox::error(@frame, DECOR_ALL, "Awwww", "#{winner.name} won the game with #{points} points!")
    end
  end
          
  # Update this observer's version of the board
  # [board] the new version of the board
  def update_board(board)
    super
    set_board(board)
    @action_widget.validate
    draw_board if calculated_coordinate_data?
    @status_panel.update
    @right_info_panel.layout
    @right_info_panel.repaint
  end
  
  # Notify this observer that a road was placed
  # [player] The player that placed the road
  # [x, y, edge] The edge coordinates
  def placed_road(player_info, x, y, edge)
    super
    add_message(player_info, "placed a road")
    draw_board
    @canvas.repaint
  end

  # Notify this observer that a settlement was placed
  # [player] The player that placed the settlement
  # [x, y, node] The node coordinates
  def placed_settlement(player_info, x, y, node)
    super
    add_message(player_info, "placed a settlement")
    draw_board
    @canvas.repaint
  end

  # Notify this observer that a city was placed
  # [player] The player that placed the city
  # [x, y, node] The node coordinates
  def placed_city(player_info, x, y, node)
    super
    add_message(player_info, "placed a city")
    draw_board
    @canvas.repaint
  end
  
  def update_card_frame
  return
    #Create a buffer for the canvas to limit the amount of rendering the screen does
    buffer = FXBMPImage.new(@app, nil, IMAGE_SHMI|IMAGE_SHMP, 
                            @bottom_canvas.width, @bottom_canvas.height) 
    buffer.create

    FXDCWindow.new(buffer) do |dc|
      dc.foreground = FXColor::White
      dc.fillRectangle(0, 0, @bottom_canvas.width, @bottom_canvas.height)
      dc.drawImage(@key_image,@bottom_canvas.width-@key_image.width,0) #at work
      
      res_cards = 0
      dev_cards = 0
      @cards.each{ |type, amount| 
        res_cards += amount if RESOURCE_TYPES.include?(type)
        dev_cards += amount if type.is_a?(DevelopmentCard)
      }
      if res_cards > 0
        n = res_cards
        theta_d = Math::PI / 10
        r = 280
  
        theta_d_2_over_n = theta_d * 2 / n
        theta_i = (Math::PI / 2) - theta_d
        k = 0
        for card_type, num in @cards
            if RESOURCE_TYPES.include?(card_type)
              for i in 1..num
                theta = (theta_d_2_over_n * k) + theta_i
                theta_deg = (theta * 180 / Math::PI).to_i
                x = (r * Math.cos(theta) * 2.5) + 300
                y = @bottom_canvas.height - (r * Math.sin(theta)) 
                
                img = FXJPGIcon.new(@app, nil, IMAGE_KEEP)
                filename = @@card_image_files[card_type]
                FXFileStream.open("lib/img/#{filename}", FXStreamLoad) { |stream| 
                  img.loadPixels(stream) 
                }
                scale = 1.5
                img.scale((img.width*scale).to_i, (img.height*scale).to_i)
                img.create
                img.render
  #              img.rotate(270)
                
  #            @resource_images[card_type].rotate(theta_deg)
               dc.drawImage(img, x, y) #At work
 #             @resource_images[card_type].rotate(-theta_deg)
              k += 1
            end
            end
        end
      end
    end
    FXDCWindow.new(@bottom_canvas) do |dc|
      dc.drawImage(buffer, 0, 0)
    end
  end
  
  #Draw the board
  #[piece] an optional temporary piece to draw on top of the board
  #        it can be an Edge or [Class, Node] where the class is
  #        either a city or settlement
  def draw_board(piece=nil, temp_bandit_hex=nil)
    return unless @board
    return unless calculated_coordinate_data?

    if (not @board_image) or @scale_changed
      @board_image = FXBMPImage.new(@app, nil, IMAGE_SHMI|IMAGE_SHMP, @canvas.width, @canvas.height) 
      @board_image.create
      FXDCWindow.new(@board_image) do |board_dc|
        board_dc.foreground = FXColor::DarkBlue
        board_dc.fillRectangle(0,0, @board_image.width, @board_image.height)
        
        #Draw the tiles
        @board.tiles.values.each{|t| drawHex(board_dc, t)}
        
        #Draw the ports
        @board.all_edges.each{|edge| 
          if edge.nodes.all?{|n| n.port}
            draw_port(board_dc, edge)
          end
        }
        @scale_changed = false
      end
    end

    #Create a buffer for the canvas to limit the amount of rendering the screen does
    buffer = FXBMPImage.new(@app, nil, IMAGE_SHMI|IMAGE_SHMP, 
                            @canvas.width, @canvas.height) 
    buffer.create

    FXDCWindow.new(buffer) do |dc|
      dc.foreground = FXColor::DarkBlue
#      dc.foreground = FXColor::White #At work

      dc.fillRectangle(0,0, @canvas.width, @canvas.height)
      dc.drawImage(@board_image, 0,0) #At work
      
      @widget_manager.paint(dc)

      
      #Draw the roads
      for t in @board.tiles.values
        for e in t.edges 
          draw_road(dc, e, e.road.color) if e.road
        end
      end   

      #Draw the temp road
      if piece and piece.class == Edge
        draw_road(dc, piece, @color)
      end
      
      #Draw cities and settlements
      for n in board.all_nodes
        if n.city
          draw_city(dc, n.city.class, n, n.city.color)
        end
      end
      #Draw the temp city
      if piece and piece.class == Array
        city, node = piece
        draw_city(dc, city, node, @color)
      end
      
      
      #Draw The bandit
      if temp_bandit_hex
        draw_bandit(dc, temp_bandit_hex)
      else
        for t in board.tiles.values
          draw_bandit(dc, t) if t.has_bandit
        end      
      end
      
    end
    
    FXDCWindow.new(@canvas) do |dc|
      dc.drawImage(buffer, 0, 0)
    end
  end
 
  def draw_port(dc, edge)
    touching_hex = edge.hexes.reject{|h| h.nil?}[0]
    x, y = getOppositeCoords(touching_hex, edge)
    x, y = get_real_hexXY_coords(x, y)
    port = edge.nodes[0].port

    img = FXTIFIcon.new(@app, nil)
    FXFileStream.open("lib/img/port.tif", FXStreamLoad) { |stream| 
      img.loadPixels(stream) 
    }
    img.scale(@hex_width, @hex_height)
    img.create
    dc.drawIcon(img, x, y)
    f = FXFont.new(@app, "arial", 12)
    f.create
    dc.setFont(f)
    dc.foreground = FXColor::White
    dc.drawText(x+15, y+10, port.type.to_s[0..-5])
  end
  
  def draw_bandit(dc, tile)
    x,y = get_real_hex_coords(tile)
    square_size = @hex_side * 0.8
    x += (@hex_width / 2) - (square_size / 2)
    y += (@hex_height / 2) - (square_size / 2)
    dc.foreground = FXColor::Black
    dc.fillRectangle(x, y, square_size, square_size) 
  end

  def drawHex(dc, hex)
    raise ArgumentError.new("Cannot draw Hex with a nil cardType") if hex.card_type.nil?
    x, y = get_real_hex_coords(hex)
    
    if @scale_changed or not @@cached_images[hex.card_type]
      img = FXTIFIcon.new(@app, nil)
      filename = IMAGE_FILES[hex.card_type]
      filename = "lib/img/#{filename}"
      raise "File not found: #{filename}" unless File.exists?(filename)
      FXFileStream.open(filename, FXStreamLoad) { |stream| 
        img.loadPixels(stream) 
      }
      img.scale(@hex_width, @hex_height)
      img.create
      @@cached_images[hex.card_type] = img
    end
    img = @@cached_images[hex.card_type]    
    
    dc.drawIcon(img, x, y)
    f = FXFont.new(@app, "arial", 12)
    f.create
    dc.setFont(f)
    dc.drawText(x+(@hex_side*0.8), y+@hex_side, hex.number.to_s) if hex.card_type != DesertType
  end
  
  #Draw a road on the DC
  def draw_road(dc, edge, color)
    x1,y1 = get_real_node_coords(edge.nodes[0])
    x2,y2 = get_real_node_coords(edge.nodes[1])
    dc.foreground = COLOR_HASH[color]
    dc.drawLine(x1, y1, x2, y2)
    if [0,3].include?(edge.coords[2])
      dc.drawLine(x1, y1+1, x2, y2+1)
      dc.drawLine(x1, y1-1, x2, y2-1)
      dc.drawLine(x1, y1+2, x2, y2+2)
      dc.drawLine(x1, y1-2, x2, y2-2)
    else 
      dc.drawLine(x1+1, y1, x2+1, y2)
      dc.drawLine(x1-1, y1, x2-1, y2)
      dc.drawLine(x1+2, y1, x2+2, y2)
      dc.drawLine(x1-2, y1, x2-2, y2)
    end
  end
  
  #Draw a city or a settlement on the DC
  def draw_city(dc, city_class, n, color)
    x,y = get_real_node_coords(n)
    s = city_class == Settlement ? @hex_width/12 : @hex_width/5
    x1,y1 = x-s, y-s
    x2,y2 = x+s, y+s   
         
    dc.foreground = COLOR_HASH[color]
    dc.fillRectangle(x1, y1, 2*s, 2*s)
   end  
end
