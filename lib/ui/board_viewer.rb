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
  
  
#Base module for any GUI that wants to draw the board
#this includes math to calculate the cartesian coordinates for 
#hexes and nodes
module BoardViewer
  include Math
  
  attr_reader :hex_centers, :gui_board

  #Some simple math contants
  Angle60 = PI / 3
  SinAngle60 = Math::sin(Angle60)
  CosAngle60 = Math::cos(Angle60)
  
  #The ratio of height to width of a hexagon
  #height * HeightRatio = width
  #HeightRation = 1/2 + (cos60 / sin 60)
  HeightRatio = 0.5 + (CosAngle60 / SinAngle60) 
  
  def initialize_viewer
    #A mapping of nodes to real x, y coordinates.
    #This is cached to save time.
    #<node, [x,y]>
    @allVertices = {} 
    
    #This is a mapping of nodes to their proximity boundaries <n, (x1,y1,x2,y2)>
    @allVerticesProx = {}
    
    #[edge, slope, point1, point2] (points are [x,y] pairs
    @allEdges = {}
   
    # A cached mapping of hex -> [x,y] where x and y are the center coordinates
    # of that hex    
    @hex_centers = nil
  end
  
  #Set the board that is to be used for GUI calculations
  #[board] The Board object
  def set_board(board)
    @gui_board = board
 
    #calculate the board's tile dimensions.
    board_x_min = 0
    board_x_max = 0
    board_y_min = 0
    board_y_max = 0
    board.tiles.values.each{|t|
      x,y = t.coords
      y -= 1 if (x % 2) == 1
      
      #Account for the port tiles
      #We want to increase the board's dimensions to hold the port tiles.
      if t.nodes[4].port
        x -= 1 
        y += 1 
      elsif t.nodes[5].port
        x -= 1 
        y -= 1
      elsif t.nodes[0].port
        y -= 1 
      elsif t.nodes[3].port
        y += 1 
      elsif t.nodes[1].port
        x += 1 
        y -= 1
      elsif t.nodes[2].port
        x += 1 
        y += 1
      end   
      
      board_x_min = x if x < board_x_min
      board_x_max = x if x > board_x_max
      board_y_min = y if y < board_y_min
      board_y_max = y if y > board_y_max
    }
    #The board height (in tiles)
    @board_tile_height = board_y_max - board_y_min

    #The board width (in tiles)
    @board_tile_width = board_x_max - board_x_min
    
    #The x (game coordinate) of the leftmost board tile.
    @left_most_tile_coord = board_x_min

    #The y (game coordinate) of the topmost board tile.
    @top_most_tile_coord = board_y_min + 1
  end
  
  
  #Sets the 2D UI dimensions that the board is shown in
  #All other methods rely on the board position to make assumptions about
  #the pixel placement. So, this method must be set before any UI methods 
  #are called.
  #
  #[left] the left most position (in pixels) of the board.
  #[top] the top most position (in pixels) of the board
  #[width] the pixel width of the board.
  #[height] the pixel height of the board.
  def set_board_dimensions(left, top, width, height)
    unless @gui_board and @board_tile_width and @board_tile_height
      raise Exception.new('Board not set. set_board(board) needs to be called before this method.')
    end
    @board_left = left
    @board_top = top
    @board_pixel_width = width
    @board_pixel_height = height
    
    #The width (in pixels) of a single hex
    if width > height
      @hex_height = height / @board_tile_height
      @hex_width = @hex_height * HeightRatio
    else
      @hex_width = width / @board_tile_width
    end
    
    #The size of a single hex side
    @hex_side = calculate_side_from_full_width(@hex_width).floor
    
    #Now that we've decided on the hex side, recalculate the width and height
    @hex_width = calculate_width_from_side(@hex_side)
    @hex_height = calculate_height_from_side(@hex_side)
    
    @xShift = (width / 2) - (@hex_side / 2)  # center it

    @yShift = (@hex_height * @top_most_tile_coord).abs
    calculate_all_vertices
    calculate_hex_centers
    $log.debug('GUI - Board Dimensions updated')
  end  
  
  #Get the coordinates (in pixels) of a given node.
  def get_real_node_coords(node)
    @allVertices[node] 
  end
  
  #Get the xy coordinates (in pixels) of the given hex
  #This is used to draw a specific hex
  def get_real_hex_coords(hex)
    n1 = @allVertices[hex.nodes[4]]
    n2 = @allVertices[hex.nodes[5]]
    Kernel.raise "Bad Node at #{hex.nodes[4].coords}" if n1.nil?
    x = n1[0]
    y = n2[1]
    [x, y]
  end
  
  #Get the xy coordinates (in pixels) of the given hex coordinates
  #This is used to draw a specific hex
  def get_real_hexXY_coords(hex_x, hex_y)
    vs = calculate_hex_verticies(hex_x, hex_y)
    [vs[4][0], vs[5][1]]
  end
  
  def calculated_coordinate_data?
    return false unless @gui_board
    @allVertices.size == @gui_board.all_nodes.size and (not @allVertices.empty?)
  end
  
  #Calculate all 6 vertex pairs for a particular hex coordinates
  def calculate_hex_verticies(x, y)
    x1 = CosAngle60*@hex_side
    x2 = x1+@hex_side
    x3 = x1+x2
    y1 = SinAngle60*@hex_side
    y2 = -y1

    #get the real hex offsets
    realX = (x*x2) + @xShift
    realY = (y*2*y1)+((x%2)*y1) + y1 + @yShift

    v1 = [x2, y2]
    v2 = [x3,  0]
    v3 = [x2, y1]
    v4 = [x1, y1]
    v5 = [0,   0]
    v6 = [x1, y2]
    [v1,v2,v3,v4,v5,v6].map{|a,b| [a+realX,b+realY]}
  end
  
  # A cached mapping of hex -> [x,y] where x and y are the center coordinates
  # of that hex
  def calculate_hex_centers
    @hex_centers = {}
    half_width = @hex_width / 2
    half_height = @hex_height / 2
    @gui_board.tiles.values.each{|t|
      x,y = get_real_hex_coords(t)
      @hex_centers[t] = [x + half_width, y + half_height]
    }
  end

  #Calculate and cache all real x,y coordinates for all
  #hex nodes and edges
  def calculate_all_vertices
    @allEdges = {}
    @gui_board.tiles.values.each do |t| 
      verticies = calculate_hex_verticies(*t.coords)
      
      #Cache node coordinates
      verticies.each_with_index do |xy, i|
        @allVertices[t.nodes[i]] = xy
      end
      
      #cache edge values
      t.nodes.each_with_index do |node, i|
        j = (i+1)%6 
        edge = t.edges[j]
        unless @allEdges.has_key?(edge)
          x1,y1 = verticies[i]
          x2,y2 = verticies[j]
          slope = (y2-y1) / (x2-x1)
          @allEdges[edge] = [slope, verticies[i], verticies[j]]
        end
      end
    end
    @allVerticesProx = calculate_proximities(proximity)
  end
  
  #Given the width of a hex, this will calculate the
  #Length of a single side.
  def calculate_side_from_full_width(width)
    return (width / (1 + (CosAngle60 * 2)))
  end
  
  #Given the length of the side of a hex, this method will return the full
  #with of the hex.
  def calculate_width_from_side(side)
    side + (CosAngle60 * side * 2)
  end

  #Given the length of the side of a hex, this method will return the full
  #with of the hex.
  def calculate_height_from_side(side)
    SinAngle60 * side * 2
  end
  
  #ensure that the nodeVertices are calculated
  def calculate_proximities(prox)
    @allVertices.map do |n, coords|
      x,y = coords
      [n, x-prox, y-prox, x+prox, y+prox]
    end
  end

  #Given a hex and an edge,
  #this method will return the xy coords of the other side
  #of the edge.  For instance, if you give this a hex on the side
  #of the board and an edge on the side of the board, this will return
  #the xy coords of the imaginary hex.
  def getOppositeCoords(hex, edge)
    edgeNum = hex.edges.index(edge)
    x, y = hex.coords
    if edgeNum == 0
      y -= 1
    elsif edgeNum == 1
      x += 1
      y -= 1
    elsif edgeNum == 2
      x += 1
      y += 1 if (y % 2 == 1)      
    elsif edgeNum == 3
      y += 1
    elsif edgeNum == 4
      x -= 1
      y += 1 if (y % 2 == 1)      
    elsif edgeNum == 5
      x -= 1
      y -= 1
    end
    [x, y]
  end
  
  
  
  #gets the piece the user has the cursor on, 
  # returns an Edge for a road, [Settlement, node], or [City, node], or nil
  def getTouchingPiece(x, y, proximity, turn)
    return unless turn
    nodeTouch = isTouchingNode?(x, y, proximity)

    is_setup_turn = turn.is_setup

    if nodeTouch 
      n, nx, ny = nodeTouch
      if @player.can_afford?([City]) and @player.piecesLeft[City] > 0
        spots = @player.board.get_valid_city_spots(@player.color)
        return [City, n] if spots.include?(n)
      end

      if (is_setup_turn and !turn.placed_settlement) or 
              (@player.can_afford?([Settlement]) and 
               @player.piecesLeft[Settlement] > 0)
        spots = @player.board.get_valid_settlement_spots(!is_setup_turn, @player.color)
        return [Settlement, n] if spots.include?(n)
      end
    end
    
    edgeTouch = isTouchingEdge?(x, y, proximity)
    if edgeTouch
      if is_setup_turn and turn.placed_settlement
        edge, c1, c2 = edgeTouch
        placed_settlement = @player.board.getNode(*turn.placed_settlement)
        spots = @player.board.get_valid_road_spots(@player.color, placed_settlement)
        return edge if spots.include?(edge)
      elsif (@player.can_afford?([Road]) or @player.purchased_pieces > 0) and @player.piecesLeft[Road] > 0
        edge, c1, c2 = edgeTouch
        spots = @player.board.get_valid_road_spots(@player.color)
        return edge if spots.include?(edge)
      end
    end

    return nil
  end
  
  
  def isTouchingEdge?(x, y, threshold)
#    return false unless calculated_coordinate_data?  
    for edge, angles in @allEdges
      slope, coord1, coord2 = angles
      coord1, coord2 = coord2, coord1 if coord1[0] > coord2[0]
      x1,y1 = coord1
      x2,y2 = coord2
      lineY = ((x - x1) * slope)+y1
      deltaY = (y - lineY).abs
      return [edge, coord1, coord2] if deltaY < threshold and x.between?(x1,x2)
    end
    false
  end

  # are the given coordinates touching a node?
  # if so, return [node, node-x, node-y] where x and y are the real x and y of the node
  def isTouchingNode?(x, y, proximity)
    for n,x1,y1,x2,y2 in @allVerticesProx
      if x.between?(x1,x2) and y.between?(y1,y2)
        nx, ny = x1+proximity, y1+proximity
        return [n, nx, ny]
      end
    end
    return false
  end  
  
  def isTouchingHex?(x, y, proximity)
   for hex, center in @hex_centers
      center_x,center_y = center
      if is_in_proximity(center_x,center_y, proximity, x, y)
        return hex
      end
    end
    return false
  end
  
  # Are the given 2D test coordinates within proximity of the target coords?
  def is_in_proximity(target_x, target_y, proximity, test_x, test_y)
    return ((target_x - test_x).abs < proximity and
           (target_y - test_y).abs < proximity)
  end
  
end
