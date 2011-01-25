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

require 'lib/ui/board_viewer'


module BoardPanel
  include BoardViewer
  attr_reader :temp_piece
  attr_accessor :last_roll
  
  HEX_IMAGE_FILES = {OreType=>'ore.tif',
                   WheatType=>'wheat.tif',
                   WoodType=>'wood.tif',
                   BrickType=>'brick.tif',
                   DesertType=>'desert.tif',
                   SheepType=>'sheep.tif'}
  IMAGE_DIR = 'lib/img/'
  BLACK_PEN = Wx::Pen.new(Wx::BLACK, 1)  
  
  #Proximity of how close the mouse has to be to place a road or settlement
  #This depends on the current visible size of the board
  def proximity 
    @hex_width / 15.0 
  end
  
  def refresh
     paint_dc
  end
  def init
    unless @inited
      @temp_piece = nil unless @temp_piece
      @gui_board = nil unless @gui_board
#      unless @hex_images
        @hex_images = {}                    
        initialize_viewer 
        for klass, file in HEX_IMAGE_FILES
          image = Wx::Image.new
          image.load_file(IMAGE_DIR + file, Wx::BITMAP_TYPE_TIF)
          @hex_images[klass] = image
#        end
      end
      @paint_mutex = Mutex.new
      @inited = true
      @hightlight_last_roll = true
      @last_roll = nil #indicates the last number that was rolled
    end
  end

  #redraw the current board on the current DC
  def paint_dc(paint_event=nil)
    init
    self.paint_buffered do |dc|
      dc.set_background($dark_blue_brush)
      dc.clear
      if @gui_board
         paint_board(dc, current_board)
      end
    end
  end
  
  #Paint the given board on the given DC
  def paint_board(dc, board)
    scale = (@hex_width / 5).to_i
    scale_half = scale / 2
  
    #Draw the Hexes
    for hex in board.tiles.values
      x, y = get_real_hex_coords(hex)
      if @hex_bitmaps[hex.card_type]
        bitmap = @hex_bitmaps[hex.card_type]
        
        dc.draw_bitmap(bitmap, x.to_i, y.to_i, false)
         if !human_player.state.is_a?(MovingBanditState)
           draw_bandit(dc, x, y, scale*2) if hex.has_bandit
         end
         draw_number(dc, hex.number, x, y, scale) unless hex.card_type == DesertType
      end
    end
    
    #Draw the Roads
    for edge in board.all_edges.reject{|e| e.road.nil?}
      draw_road(dc, edge, edge.road.color, scale_half)
    end
    
    #Draw the settlements and cities
    for node in board.all_nodes.select{|n| n.city}
      draw_city_or_settlement(dc, node, node.city.class, node.city.color, scale, scale_half)
    end    
    #paint the temporary pieces
    #The user can place roads, cities, and settlements on the board by clicking
    #so, we need to draw them 
    if @temp_piece
      if @temp_piece.is_a?(Hex)
        #Temporary bandit
        x, y = get_real_hex_coords(@temp_piece)
        draw_bandit(dc, x, y, scale*2)
      else
        color = human_player.color
        if @temp_piece.pieceKlass == Road
          edge = current_board.getEdge(*@temp_piece.coords)
          draw_road(dc, edge, color, scale_half)
        elsif @temp_piece.pieceKlass <= Settlement
          node = current_board.getNode(*@temp_piece.coords)
          draw_city_or_settlement(dc, node, @temp_piece.pieceKlass, color, scale, scale_half)
        end
      end
    end
  end
  
  #Helper method to draw a single road
  def draw_road(dc, edge, color, scale_half)
    x1,y1 = get_real_node_coords(edge.nodes[0]).map{|x| x.to_i}
    x2,y2 = get_real_node_coords(edge.nodes[1]).map{|x| x.to_i}
    pen = Wx::Pen.new($player_color_map[color], scale_half+1)
    pen.set_cap(Wx::CAP_ROUND)
    dc.set_pen(pen)
    dc.draw_line(x1,y1,x2,y2)
  end
  
  #Helper method to draw a settlement or city
  def draw_city_or_settlement(dc, node, pieceKlass, color, scale, scale_half)
    x,y = get_real_node_coords(node).map{|x| x.to_i}
    dc.set_pen(BLACK_PEN)
    dc.set_brush($player_color_brushes[color])
    points = if pieceKlass == Settlement
               calculate_settlement_points(x, y, scale, scale_half)
             else
               calculate_city_points(x, y, scale, scale_half)
             end
    dc.draw_polygon(points)  
  end
  
  #Draw a number on a hex
  #x and y here should be the real hex coords (the upper left hand corner)
  def draw_number(dc, number, x, y, scale)
    if @last_roll == number and @hightlight_last_roll
      scale *= 2
      font = Wx::Font.new(scale, Wx::FONTFAMILY_DEFAULT, Wx::FONTSTYLE_NORMAL, Wx::FONTWEIGHT_BOLD)
      y_coord = y.to_i+(@hex_side * 0.21).to_i
      if number > 9
        x_coord = x.to_i+(@hex_side * 0.51).to_i
      else
        x_coord = x.to_i+(@hex_side * 0.66).to_i
      end
    else
      font = Wx::Font.new(scale, Wx::FONTFAMILY_DEFAULT, Wx::FONTSTYLE_NORMAL, Wx::FONTWEIGHT_NORMAL)
      y_coord = y.to_i+(@hex_side * 0.59).to_i
      if number > 9
        x_coord = x.to_i+(@hex_side * 0.72).to_i
      else
        x_coord = x.to_i+(@hex_side * 0.9).to_i
      end
    end
    dc.set_pen(BLACK_PEN)    
    dc.set_font(font)
    
    dc.draw_text(number.to_s, x_coord, y_coord)
  end
  
  #Draw the bandit on the given hex
  #x and y here should be the real hex coords (the upper left hand corner)
  def draw_bandit(dc, x, y, scale)
    dc.set_pen(BLACK_PEN)
    dc.set_brush(Wx::BLACK_BRUSH)
    dc.draw_rounded_rectangle(x.to_i+(@hex_side * 1.45).to_i-scale, 
                                      y.to_i+(@hex_side * 1.22).to_i-scale, 
                                      scale, scale, scale/4)
  end
  
  def on_mouse_move(event)
    previous_piece = @temp_piece
    @temp_piece = human_player.state.get_temp_piece(event.get_x, event.get_y) 
    paint_dc if @temp_piece != previous_piece
  end
  
  def on_mouse_click(event)
    state = human_player.state
    Thread.new {
      state.on_board_left_click(event)
    }
  end
  
  def on_mouse_leave(event)
    @temp_piece = nil
    paint_dc
  end
  
  def update_board_dimensions(size_event = nil)
    init
    size = get_size
    if size.get_width > 0 and size.get_height > 0
      set_board_dimensions(0,0,size.get_width, size.get_height)
      @hex_bitmaps = {}
      @hex_width = @hex_width.to_i
      @hex_height = @hex_height.to_i
      @hex_images.each{|h, img|
        img = img.copy
        img.rescale(@hex_width, @hex_height) 
        @hex_bitmaps[h] = Wx::Bitmap.new(img)  
      }
    end
  end
  
  def on_size(event)
    update_board_dimensions if @gui_board
	paint_dc
  end
  
  #Helper method to calculate what piece the mouse is close to
  #This method does NOT take rules into account, JUST the mouse x,y, and threshold
  def get_temp_piece(x, y)
    threshold = proximity
    found_coords = isTouchingNode?(x,y, threshold)
    if found_coords
      existing_city = current_board.getNode(*found_coords[0].coords).city
      klass = if existing_city then City else Settlement end 
      return TempPiece.new(klass, found_coords[0].coords)
    else
      found_coords = isTouchingEdge?(x,y, threshold)
      if found_coords
      return TempPiece.new(Road, found_coords[0].coords)
      else
        return nil
      end
    end  
  end
  
  def current_board
    p = human_player
    return p.board if p
    return nil
  end
  
  def human_player 
    RealMainFrame.instance.human_player
  end

  #given the real node coords, this method will calcualte the 
  #polygon points to draw a settlement
  #[scale] the size of 1 side of the settlement
  #[scale_half] half of scale.  This is passed in to save on division
  def calculate_settlement_points(x, y, scale, scale_half)
    [[x-scale_half, y+scale_half-1],
     [x+scale_half, y+scale_half-1],
     [x+scale_half, y-scale_half+1],
     [x, y-scale+2],
     [x-scale_half, y-scale_half+1]]
  end
  
  
  #given the real node coords, this method will calcualte the 
  #polygon points to draw a settlement
  #[scale] the size of 1 side of the settlement
  #[scale_half] half of scale.  This is passed in to save on division
  def calculate_city_points(x, y, scale, scale_half)
    [[x-scale+1, y+scale_half],
     [x+scale-1, y+scale_half],
     [x+scale-1, y-scale_half],
     [x, y-scale_half],
     [x, y-scale],
     [x-scale_half+1, y-scale-scale_half],
     [x-scale+1, y-scale]]
  end
end

#[pieceKlass] is one of City, Settlement, or Road
#[coords] is a 3 element array of [hex_x, hex_y, position]
TempPiece = Struct.new(:pieceKlass, :coords)