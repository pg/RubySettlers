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
 
require 'lib/core/util'
require 'lib/core/board_components'

# The central data structure for the game.  
# This holds all the user game pieces (Cities, Settlements, Roads) 
# and also all the admin pieces(Cards, Tiles etc.)
# This is an abstract class that must be implemented by a subclass
class Board
  attr_reader :tiles, :nodes, :edges, :card_pile
  #The game definition that this board applies to
  attr_reader :expansion
  #The number of recomended players for this board. (Range)
  attr_reader :recomended_players
  #The human readable name for this board
  attr_reader :name
  #The RandomBag of Hex tiles.
  attr_reader :tile_bag
  #The RandomBag of Port objects.
  attr_reader :port_bag
  #The RandomBag of numbers.
  attr_reader :number_bag

  public

  #Get the Hex object at the given coordinates
  def getTile(x, y) @tiles[[x,y]] end

  #Get the Node object at the given coordinates
  #[x,y] The cartesian coordinates that specify a Hex
  #[n] The node number on that Hex
  def getNode(x, y, n) getTile(x,y).nodes[n]; end

  #Get the Edge object at the given coordinates
  #[x,y] The cartesian coordinates that specify a Hex
  #[e] The edge number on that Hex
  def getEdge(x, y, e) getTile(x,y).edges[e]; end

  #A master list of all unique nodes on the board.
  def all_nodes
    @nodes = @tiles.values.collect{|t| t.nodes }.flatten.uniq if not @nodes
    @nodes
  end
  
  def all_edges
    @edges = all_nodes.map{|n| n.edges}.flatten.uniq unless @edges
    @edges
  end
  
  #Traverses a road and calculates the length of the longest road touching it.
  #[edge] The edge to start on.  If the Edge has no road, it returns 0.
  #[visitedNodes] Is a list used in the recursion of this method.  
  #It should not be used by anyone calling it.
  def longest_road(edge, visitedNodes=[])
    if edge.road 
      color = edge.road.color
      
      length = 0
      (edge.nodes - visitedNodes).each{|n|
        max = 0
        n.edges.each{|e|
          if e != edge and e.road and e.road.color == color
            sub_length = longest_road(e, visitedNodes + [n])
            max = sub_length if sub_length > max
          end  
        }
        length += max
      }
      length + 1
    else
      0
    end
  end

  #Finds the longest road in a specific direction
  #[initial_direction] should be 1 or 0
  #In 99.9% of the time, this method is fast.  But if you have a huge board 
  #with 50+ connected roads of the same color, this method could take up to a 
  #minute to finish.
  #Returns an int
  def find_longest_road(edge, initial_direction=nil, visitedNodes=[])
    if edge.road 
      color = edge.road.color
      nodes_to_visit = edge.nodes
      nodes_to_visit = [edge.nodes[initial_direction]] if initial_direction
      
      length = 0
      
      (nodes_to_visit - visitedNodes).each{|n|
        length += n.edges.collect{|e|
          if e != edge and e.road and e.road.color == color
            find_longest_road(e, nil, visitedNodes + [n])
          else  
            0
          end  
        }.max
      }
      length + 1
    end
  end

  def has_longest_road?(color)
    maxs = {}
    maxs.default = 0
    
    for e in @roadEdges
      for road_length in e.road_lengths
        color2 = e.road.color
        maxs[color2] = road_length if road_length>maxs[color2] and road_length>=5
      end
    end
    winners = maxs.keys.select{|k| maxs[k]==maxs.values.max}
    
    #only 1 player can have longest road
    #if more than 1 player has the longest road, than neither of them count
    winners.length == 1 and winners[0] == color
  end

  #Gets the list of ports for this player
  def get_ports(color)
    all_nodes().collect{|n| 
      n.port if n.city and n.city.color == color 
    }.compact
  end

  #Gets a list of cards, that the given player should receive
  def get_cards(number, color)
    result=[]
    for t in @tiles.values
      if t.number == number and not t.has_bandit and t.card_type != DesertType
        for n in t.nodes
          if n.city and n.city.color == color
            case n.city
            when City then result += t.get_2_cards
            when Settlement then result << t.get_card
            end
          end
        end
      end
    end
    result
  end

  #Called ONLY by a Turn object, this method mutates the board by placing a 
  #road on it.
  def place_road!(road, tileX, tileY, edgeNum)
    t = getTile(tileX, tileY) 
    raise "Hex not found: (#{tileX}, #{tileY})" if t.nil?
    edge = t.edges[edgeNum]
    edge.road = road
    @roadEdges << edge
    
    #update the longest road markers
    edge.visit_road do |e|
      e.road_lengths[0] = find_longest_road(e, 0)
      e.road_lengths[1] = find_longest_road(e, 1)
    end
    
    return edge
  end

  def remove_road!(tileX, tileY, edgeNum)
    t = getTile(tileX, tileY)
    raise "Hex not found: (#{tileX}, #{tileY})" if t.nil?
    edge = t.edges[edgeNum]
    raise "Edge does not have a road on it" unless edge.road
    adjecentEdges = edge.get_adjecent_edges.reject{|e| e.road.nil?}
    edge.road = nil
    @roadEdges.delete(edge)
    
    #update the longest road markers
    adjecentEdges.each do |ae|
      ae.visit_road do |e|
        e.road_lengths[0] = find_longest_road(e, 0)
        e.road_lengths[1] = find_longest_road(e, 1)
      end
    end
  end

  #Called ONLY by a Turn object, this method mutates the board by placing a 
  #City or Settlement on it.
  def place_city!(city, x, y, nodeNum)
    t = getTile(x, y)
    node = t.nodes[nodeNum]
    node.city = city
  end

  #Move the bandit to a new hex
  def move_bandit(new_hex)
    raise RuleException.new("Cannot move bandit to nil") if new_hex.nil?
    current_bandit_hex = @tiles.values.find{|t| t.has_bandit}
    raise RuleException.new("Board does not currently have a bandit #{self}") unless current_bandit_hex
    raise RuleException.new("Bandit cannot be moved to the Tile it's already on") if current_bandit_hex == new_hex
    local_tile = @tiles.values.find{|t| t.coords == new_hex.coords}
    local_tile.has_bandit = true
    current_bandit_hex.has_bandit = false
  end

  #Gets a list of Nodes that settlements can be placed on.
  #[roadConstraint] A boolean that ensures that settlements can only be placed 
  #on pre-existing roads. For SetupTurns, this should be false.
  #(Players don't need to connect settlements to roads during setup. )
  #[roadColor] The color of the road to constrain against.  For a normal turn, 
  #you need to ask which spots are valid for your player's color.
  #returns a list of Node objects
  def get_valid_settlement_spots(roadConstraint, roadColor)
    all_nodes.select{|n| 
      ##make sure there are no cities in the adjecent nodes
      is2AwayFromCities = (not n.get_adjecent_nodes.find{|n2| n2.city})
  
      if roadConstraint
        hasAdjecentRoad = n.edges.find{|e| e.road and e.road.color == roadColor}
        hasAdjecentRoad and is2AwayFromCities and not n.city
      else 
        is2AwayFromCities and not n.city
      end
    }.uniq
  end

  #Get all the valid places to put a road.
  #NOTE: if someone else builds a settlement, you can't build a road through it.
  #[touching_node] If specified, valid road spots MUST touch this node.
  #This is used during setup when players can only place a road touching the 
  #settlement they just placed.
  def get_valid_road_spots(road_color, touching_node=nil)
    result=[]
    all_nodes.each{|n|
      if n.city and n.city.color == road_color
        result += n.edges.select{|e| not e.road}
      elsif not n.city
        for e in n.edges
          if e.road and e.road.color == road_color
            spaces = n.edges.select{|e| not e.road}
            result += spaces
          end
        end
      end
    }
    result = result.select{|e| e.nodes.include?(touching_node)} if touching_node
    result.uniq
  end 

  #Get all the valid spots to place a city.
  def get_valid_city_spots(color)
    all_nodes.select{|node| node.city.class == Settlement and node.city.color == color}
  end
  
  #This method initializes tile_bag, port_bag, number_bag
  #This should be overriden by the subclasses
  def init_bags
    raise 'Not Implemented'
  end
  
  #Randomize any Hexes that need to be taken from the Hex bag
  #Or randomize any hex numbers or ports.
  #i.e. The standard board is all random, so this should randomize the whole board.
  def randomize_board!
    init_bags
    for t in @tiles.values
      if t.is_a?(RandomHexFromBag)
        temp_hex = @tile_bag.grab
        t.card_type = temp_hex.card_type
      end
    end
    
   
    #Randomize the Numbers
    for t in @tiles.values.reject{|t| t.card_type == DesertType}
      t.number = @number_bag.grab
    end
    
    #Randomize the ports
    all_edges.each{|e| 
      if e.nodes.all?{|n| n.port}
        port = e.nodes[0].port
        if port.is_a?(RandomPortFromBag)   
          port = @port_bag.grab
          for n in e.nodes
            n.port.type = port.type
            n.port.rate = port.rate
          end      
        end
      end
    }
    enforce_bandit    
  end
  
  def enforce_bandit
    bandit_tiles = @tiles.values.select{|t| t.has_bandit}
    if bandit_tiles.size > 1
      bandit_tiles.each{|t| t.has_bandit = false}
      $log.warn("Initializing Board with #{bandit_tiles.size} bandits")
    end
    desert = @tiles.values.find{|t| t.card_type == DesertType}
    if desert
      desert.has_bandit = true
    elsif !@tiles.values.empty?
      $log.warn('Could not find desert tile, placing bandit on first hex')
      @tiles.values.first.has_bandit = true
    end
  end

  private

  def initialize(randomize=true, should_enforce_bandit=true)
    @tiles = {}
    @nodes = nil
    @edges = nil
    @roadEdges = [] #keep track of roads for performance
    @card_pile = DevelopmentCardBag.new
    init_bags
    subclass_init
    randomize_board! if randomize
    
    #Enforce that only ONE tile has the bandit
    if should_enforce_bandit
      enforce_bandit
    end
    
    all_edges.select{|e| e.nodes.all?{|n| n.port}}.each{|port_edge|
      if port_edge.hexes.size != 1 
        coords = port_edge.coords.join(',')
        raise Exception.new("Attempting to build a board with an inland port at (#{coords})")
      end
    }
  end  
  
  #This method takes all the tiles in @tiles and connects them.  It adds edges 
  #and nodes to each of the Hexes.  This method does a lot of calculation since
  #it makes sure that all the Hexes share Edges and Nodes
  def connectTiles
    @tiles.each_pair{|coord, hex|
      x,y = coord
      mod = x%2
      above = getTile(x, y-1)
      below = getTile(x, y+1)
      rightabove = getTile(x+1, y+mod-1)
      rightbelow = getTile(x+1, y+mod)
      leftabove = getTile(x-1, y+mod-1)
      leftbelow = getTile(x-1, y+mod)
      hex.connect_hex(0, above)
      hex.connect_hex(1, rightabove)
      hex.connect_hex(2, rightbelow)
      hex.connect_hex(3, below)
      hex.connect_hex(4, leftbelow)
      hex.connect_hex(5, leftabove)
    }
  end
  
  #Initializes all the sub-class specific data.  
  #i.e. name, expansion, tile-locations, tile-numbers etc.
  #Should be overriden by subclass
  def subclass_init
    raise 'Not Implemented'  
  end
end
