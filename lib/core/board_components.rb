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
 

class Resource
  def ==(o)
    o.class == self.class
  end
end

class BrickType < Resource; end
class OreType < Resource; end
class WheatType < Resource; end
class WoodType < Resource; end
class SheepType < Resource; end
RESOURCE_TYPES = [BrickType, OreType, WheatType, WoodType, SheepType]
class DesertType < Resource; end
HEX_TYPES = RESOURCE_TYPES + [DesertType]



# Edge numbers
#         0
#     ---------
#    /         \
#  5/           \1
#  /             \
#  \             /
#  4\           / 2
#    \         /
#     ---------
#        3

# Node numbers              
#    5---------0
#    /         \
#   /           \
# 4/             \1
#  \             /
#   \           / 
#    \         /
#    3---------2
class Hex
  attr_accessor :nodes, :edges, :number, :coords, :card_type
  attr_accessor :has_bandit
  
  # Probability distribution for dice rolls
  # dice_probs[die value] = probability
  @@dice_probs = {}
  @@dice_probs.default=0
  for x in 1..6
    for y in 1..6
      @@dice_probs[x+y] += 1/36.0
    end
  end

  def initialize(card, number, has_bandit=false)
    @card_type = card
    @number = number
    @has_bandit = has_bandit
    @nodes = []
    @edges = []
  end

  def get_card() 
    raise Exception.new("Cannot take card from a desert.") if @card_type == DesertType
    @card_type 
  end

  def get_2_cards()
    raise Exception.new("Cannot take card from a desert.") if @card_type == DesertType
    [@card_type, @card_type] 
  end

  def connect_hex(edgeIndex, hex2)
    edgeIndex2 = (edgeIndex-1)%6
    if hex2
      i2 = (edgeIndex + 3) % 6
      @edges[edgeIndex].nodes = [] if @edges[edgeIndex]
      hex2.edges[i2].nodes = [] if hex2.edges[i2]

      edge = @edges[edgeIndex]
      edge = hex2.edges[i2] if hex2.edges[i2]
      edge = Edge.new if not edge
      hex2.edges[i2] = edge
      tempNodes = connect_to_nodes(edge, edgeIndex, i2, hex2)
    else
      edge = Edge.new
      tempNodes = connect_to_nodes(edge, edgeIndex, i2, nil)
      edge.nodes = tempNodes
    end
    @edges[edgeIndex] = edge
    edge.hexes << self
    edge.hexes.uniq!
    
    edge.coords = @coords + [edgeIndex]

    tempNodes.each_with_index{|n,i|
      tempEdgeIndex = i==0 ? edgeIndex : edgeIndex2
      n.coords = @coords + [tempEdgeIndex]
      n.edges.uniq!
      @nodes[tempEdgeIndex] = n
      n.hexes << self
      n.hexes.uniq!
    }
  end 

  #helper for connectHex 
  def connect_to_nodes(edge, edgeIndex, i2, hex2 = nil)
    n1 = @nodes[edgeIndex]
    n2 = @nodes[(edgeIndex-1)%6]
    n1 = hex2.nodes[(i2-1)%6] if not n1 and hex2
    n2 = hex2.nodes[i2] if not n2 and hex2
    n1 = Node.new if not n1
    n2 = Node.new if not n2
    n1.edges << edge
    n2.edges << edge
    
    if hex2
      hex2.nodes[i2] = n2
      hex2.nodes[(i2-1)%6] = n1
      edge.nodes = [n1, n2]
    end
    [n1,n2]
  end

  
  #get the probablity for this hex's number
  def get_prob() @@dice_probs[@number] end

  #gets the cartesian coordinatess of the rightmost point of this hex
  def get_cartesian
    x,y = @coords
    [x, y+((x%2)/2.0)]
  end
  
  def to_s() 
    if coords.nil?
      "Resource tile: #{@card_type}"
    else
      "Resource tile: #{@card_type} (#{@coords.join(',')})"
    end
  end
  
  def inspect
    to_s
  end
  
  def <=>(o)
    to_s <=> o.to_s
  end
  
  def ==(o)
    return (o.is_a?(Hex) and @coords == o.coords)
  end
end

#This is a random Hex that is pulled out of the Board's Hex bag.
class RandomHexFromBag < Hex
  def initialize
    super(nil, 0, false)
  end
end


#A Port for trading resources
class Port < Struct.new(:type, :rate)
  def initialize(type, rate=2)
    super
  end
  
  def ==(o)
    self.type == o.type and self.rate == o.rate
  end
end

class RandomPortFromBag < Port
  def initialize(type=nil, rate=nil)
    super
  end
end



#A randomized collection of development cards.
class DevelopmentCardBag
  attr_reader :cards

  def initialize
    @cards = []
    (1..9).each{ @cards << SoldierCard }
    (1..4).each{ @cards << RoadBuildingCard }
    (1..1).each{ @cards << ResourceMonopolyCard }
    (1..4).each{ @cards << YearOfPlentyCard }
  end

  #This gets called by the admin to give a card to somebody
  def get_card
    raise RuleException.new('No Development cards left') if @cards.empty?
    klass = @cards.delete_at(rand(@cards.length))
    klass.new
  end
end


# An Edge is basically just a collection of 2 nodes that belongs to a hex
class Edge
  attr_accessor :hexes, :nodes, :road, :coords
  
  #A cache of the longest road lengths connected to this edge
  #This is used to speed up the longest road calculations.
  attr_accessor :road_lengths
  
  def initialize
    @nodes = []
    @hexes = []
    @road_lengths = []
  end
  
  #Get all the Edges touching this Edge.
  #This will return a List with size bewteen 2 and 4.
  def get_adjecent_edges
    result = []
    for n in @nodes
      result += n.edges
    end
    result.delete(self)
    result.uniq
  end

  # An iterator to visit every connected road with the same color
  # yields the edge containing the road
  def visit_road(visitedEdges=[])
    if @road
      visitedEdges << self
      yield self
      for e in get_adjecent_edges
        if not visitedEdges.include?(e) 
          if e.road and e.road.color == @road.color
            e.visit_road(visitedEdges){|edge| yield edge}
          end
        end
      end
    end
  end
  
  def ==(o)
    return false unless o
    @hexes == o.hexes and @nodes == o.nodes and @coords == o.coords
  end
end


#This Corresponds to a node on the board where settlements and cities can be placed.
class Node
  attr_accessor :edges, :hexes, :city, :port, :coords

  def initialize
    @edges = []
    @hexes = []
    @city = nil
    @port = nil
    @coords= nil
  end
  
  # The Array of adjecent nodes
  def get_adjecent_nodes
    @edges.collect{|e| e.nodes - [self]}.flatten
  end

  #Gets the sum of hex probablities touching this node
  def get_hex_prob
    @hexes.map{|h| h.get_prob}.sum
  end
  
  def inspect
    "<node coords=\"#{@coords}\" />"
  end
  
  def ==(o)
    begin
		@coords == o.coords
	rescue => e
		puts e.inspect
  puts e.backtrace

		end
  end
end

#A bag of items that can be grabbed at random
class RandomBag
  attr_reader :items
  def grab
    @items.delete_at(rand(@items.length))
  end
end

Road = Struct.new(:color)

#A Settlement object with a color and points
class Settlement < Struct.new(:color)
  def getPoints() 1 end
end

#A City object with a color and points
class City < Settlement
  def getPoints() 2 end
end

#Base class of a card that does something
class ActionCard
  #Use this card on a turn
  def use(turn)
    if turn != turn.admin.currentTurn
      raise RuleException.new("Cannot play a card on with a finished turn") 
    end
    raise RuleException.new("Cannot play a card without a turn") if turn == nil
    raise RuleException.new("Turn must have a player") if turn.player == nil
  end
  
  # Are the card's actions finished?
  def is_done
    true
  end
  
  # Does this card HAVE to be finished at the end of a turn?  Or can it 
  # be played across multiple turns?
  def single_turn_card
    true
  end
end

class DevelopmentCard < ActionCard
end

#Allows a player to move the bandit.
#NOTE: this can be played before the dice are rolled.
class SoldierCard < DevelopmentCard
  def use(turn)
    super
    old_bandit_hex = turn.admin.board.tiles.values.find{|t| t.has_bandit}
    new_banit_loc = turn.player.move_bandit(old_bandit_hex)
    turn.move_bandit(new_banit_loc)
  end
end

#Allows a player to build 2 roads in his turn
class RoadBuildingCard < DevelopmentCard
  def use(turn)
    super
    turn.player.purchased_pieces += 2
    $log.debug("Giving 2 roads to #{turn.player}: #{turn.player.purchased_pieces}")
  end

  #We don't need to override is_done because NO TURN should be allowed 
  #to finish with unused, purchased pieces already.
end

#Allows a user to steal a specific resource from all other players
class ResourceMonopolyCard < DevelopmentCard
  def use(turn)
    super
    res = turn.player.select_resource_cards(RESOURCE_TYPES, 1).first
    unless RESOURCE_TYPES.include?(res)
      raise RuleException.new("Player must select a resource. Found #{res} instead")
    end
    turn.admin.other_players(turn.player) do |p| 
      cards = [res] * p.cards[res]
      $log.info("#{turn.player} is taking #{cards} from #{p}")
      p.del_cards(cards)
      turn.player.add_cards(cards)
     end
  end
end

#Lets a user select 2 resources and add them to his hand
class YearOfPlentyCard < DevelopmentCard
  def use(turn)
    super
    cards = RESOURCE_TYPES * 2
    res = turn.player.select_resource_cards(cards, 2)
    turn.player.add_cards(res)
  end
end

