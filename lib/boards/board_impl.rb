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
  
  
# This file contains Implementations of the abstract Board Class

require 'lib/core/board'
require 'lib/core/game_definition'

#The randomized bag of tile hexes and ports
class TileBag < RandomBag
  #[randAdd] add a number of completely random tiles
  def initialize(randAdd=0)
    @items = [Hex.new(DesertType, 0)]
    for x in 1..3 do 
      @items << Hex.new(BrickType, 0)
      @items << Hex.new(OreType, 0)
    end
    for x in 1..4 do 
      @items << Hex.new(WheatType, 0)
      @items << Hex.new(WoodType, 0)
      @items << Hex.new(SheepType, 0)
    end
    
    for i in 1..randAdd
      @items << Hex.new(RESOURCE_TYPES[rand(RESOURCE_TYPES.length)], 0)
    end
  end
end

class StandardPortBag < RandomBag
  def initialize
    @items = [Port.new(BrickType, 2), 
              Port.new(WheatType, 2), Port.new(WoodType, 2),
              Port.new(OreType, 2),   Port.new(SheepType, 2)]
    for x in 1..4 do @items << Port.new(nil, 3) end
  end
end

class NumberBag < RandomBag
  def initialize
    @items = [2, 3, 3, 4, 4, 5, 5, 6, 6, 8, 8, 9, 9, 10, 10, 11, 11, 12]
  end 
end

#The Standard Board
class StandardBoard < Board
  def init_bags
    @tile_bag = TileBag.new
    @port_bag = StandardPortBag.new
    @number_bag = NumberBag.new
  end

  #Initializes all the sub-class specific data.  
  #i.e. name, expansion, tile-locations, tile-numbers etc.
  def subclass_init
    @recomended_players = 3..4
    @expansion = StandardGame.new
    @name = 'Standard Board'
    
    coords = [[-2,1],[-2,2],[-2,3],
              [-1,0],[-1,1],[-1,2],[-1,3],
              [0,0],[0,1],[0,2],[0,3],[0,4],
              [1,0],[1,1],[1,2],[1,3],
              [2,1],[2,2],[2,3]]
              
    for c in coords
      @tiles[c] = RandomHexFromBag.new
      @tiles[c].coords = c
    end
    connectTiles

    #Ports
    #each one is a tile coord + the edge number to put the port on
    coords = [[1,0,0], [2,1,1], [2,2,2], [1,3,2], 
              [0,4,3], [-1,3,4], [-2,2,4],[-2,1,5],[-1,0,0]]
    
    for x,y,edge in coords
      portEdge = getTile(x, y).edges[edge]
      port = RandomPortFromBag.new
      for n in portEdge.nodes
        n.port = port
      end
    end  
  end

end


class NSizeNumberBag < RandomBag
  def initialize(n)
    @items = (1..n).map{ new_number }
  end 
  
  #Pick at a hex number at random
  def new_number
    n = rand(10) + 2
    if n == 7
      new_number 
    else
      n
    end
  end
end

#An L-shaped board
class L_Board < StandardBoard

  def init_bags
    @tile_bag = TileBag.new(100)
    @port_bag = StandardPortBag.new
    @number_bag = NSizeNumberBag.new(100)
  end

  def subclass_init
    @name = 'L-Shaped Board'
    @expansion = StandardGame.new
    @recomended_players = 2..4
    
    bag = TileBag.new(100)
    #Tiles
    coords = [
      [-7,0],[-7,1],[-7,2],[-7,3],[-7,4],[-7,5],[-7,6],[-7,7],
      [-6,0],[-6,1],[-6,2],[-6,3],[-6,4],[-6,5],[-6,6],[-6,7],
      [-5,7],[-5,6],
      [-4,7],[-4,6],
      [-3,7],[-3,6],
      [-2,7],[-2,6]
    ]
    for c in coords
      @tiles[c] = @tile_bag.grab
      @tiles[c].coords = c
    end
    connectTiles
    
  end
end

# a "Square" board where x and y dimenstions are the same.
class SquareBoard < StandardBoard
  def initialize(side)
    @side = side
    super()
  end
  
  def init_bags
    @tile_bag = TileBag.new(@side*@side)
    @port_bag = StandardPortBag.new
    @number_bag = NSizeNumberBag.new(@side*@side)
  end
  
  def subclass_init
    @name = "Square Board (#{@side}x#{@side})"
    @expansion = StandardGame.new
    @recomended_players = 2..4
  
    bag = TileBag.new(@side ** 2)
    #Tiles
    coords = []
    for x in 1..@side do
      for y in 1..@side do
        coords << [x,y]
      end
    end
    for c in coords
      @tiles[c] = @tile_bag.grab
      @tiles[c].coords = c
    end
    connectTiles
  end  
end

class FixedBoard < StandardBoard
  alias_method :old_randomize_board!, :randomize_board!

  def subclass_init
    super
    @name = "Fixed Board"
    old_randomize_board!
  end

  def randomize_board!
  end
end
