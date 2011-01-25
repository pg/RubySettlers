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
  
  
require 'lib/core/board'
require 'lib/boards/board_impl'
require 'test/unit'
require 'tests/test_utils'

class BoardTest < Test::Unit::TestCase

  def setup
    @board  = StandardBoard.new
    @expected_hexes = 19
    @expected_edges = 72
    @expected_nodes = 54
    @expected_ports = 18
  end 

  # Test the number of hexes
  def test_hexes
    assert_equal(@expected_hexes, @board.tiles.length)
  end

  def test_hex_numbers
    @board.tiles.values.reject{|t| t.card_type == DesertType}.each{|hex| 
      assert_operator(hex.number, :<=, 12)      
      assert_not_equal(7, hex.number)     
      assert_operator(hex.number, :>=, 2)     
    }
  end

  # Test the number of edges
  def test_edges
    edges = []
    @board.tiles.values.each{|t|
      t.edges.each{|e|
        edges << e if not edges.include?(e)
      }
    }
    assert_equal(@expected_edges, edges.length)
  end

  def test_all_edges
    assert_not_nil(@board.all_edges)
    assert(! @board.all_edges.empty?)
    @board.all_edges.each{|e|
      assert_not_nil(e)    
      assert_not_nil(e.hexes)    
      assert_operator(e.hexes.size, :>=, 1)
      assert_operator(e.hexes.size, :<=, 2)
    }
  end
  
    
  
  #Test that a board cannor be created with a port inland
  def test_create_board_with_inland_port
    assert_raise(Exception) do
      InlandPortBoard.new
    end    
  end

  # Create a board and place some roads on it.
  def test_has_longest_road
    e1 = @board.place_road!(Road.new("red"), 0, 2, 2)
    @board.place_road!(Road.new("red"), 1, 2, 0)
    @board.place_road!(Road.new("red"), 1, 1, 2)
    e4 = @board.place_road!(Road.new("blue"), 1, 1, 1)
    @board.place_road!(Road.new("blue"), 1, 1, 0)
    @board.place_road!(Road.new("red"), 0, 2, 3)
    @board.place_road!(Road.new("red"), 0, 2, 4)
    assert(@board.has_longest_road?("red"))
    assert((not @board.has_longest_road?("blue")))

    e5 = @board.place_road!(Road.new("orange"), 0, 0, 0)
    @board.place_road!(Road.new("orange"), 0, 0, 5)
    @board.place_road!(Road.new("orange"), -1, 0, 0)
    @board.place_road!(Road.new("orange"), -1, 0, 5)
    @board.place_road!(Road.new("orange"), -1, 0, 4)
    assert((not @board.has_longest_road?("red")))
    assert((not @board.has_longest_road?("blue")))
    assert((not @board.has_longest_road?("orange")))
    
    @board.place_road!(Road.new("orange"), -1, 0, 1)
    count = @board.longest_road(e5)
    assert_equal(5, count, "orange road length2")
    assert((not @board.has_longest_road?("red")))
    assert((not @board.has_longest_road?("blue")))
    assert((not @board.has_longest_road?("orange")))

    @board.place_road!(Road.new("orange"), -1, 0, 3)
    count = @board.longest_road(e5)
    assert_equal(6, count, "orange road length3")
    assert(@board.has_longest_road?("orange"))

    @board.place_road!(Road.new("orange"), -1, 0, 2)
    count = @board.longest_road(e5)
    assert_equal(8, count, "orange road length4")
    assert(@board.has_longest_road?("orange"))
  end
  
  # test the find_longest_road method
  def test_find_longest_road__simple
    @board.place_road!(Road.new("orange"), 0, 0, 0)
    edge1 = @board.place_road!(Road.new("orange"), 0, 0, 1)
    edge2 = @board.place_road!(Road.new("orange"), 0, 0, 4)
    @board.place_road!(Road.new("orange"), 0, 0, 5)
    @board.place_road!(Road.new("orange"), -1, 0, 0)
    @board.place_road!(Road.new("orange"), -1, 0, 2)
    assert_equal(5, @board.find_longest_road(edge1, 1))
    assert_equal(1, @board.find_longest_road(edge1, 0))
    assert_equal(4, @board.find_longest_road(edge2, 1))
    assert_equal(2, @board.find_longest_road(edge2, 0))
  end

  # test that cities and settlements produce the right cards.
  def test_get_cards
    @board.tiles.values.each{|t| t.number = 12}
    assert_equal(0, @board.get_cards(1, nil).length, "1 nil")
    assert_equal(0, @board.get_cards(13, nil).length, "13 nil")

    tile = @board.getTile(0,0)
    tile.card_type = OreType
    tile.has_bandit = false
    tile.number = 5
    tile.nodes[0].city = City.new("red")
    tile.nodes[5].city = Settlement.new("blue")
    cards = @board.get_cards(5, "red")
    assert_equal(2, cards.length)

    cards = @board.get_cards(5, "blue")
    assert_equal(1, cards.length)
    tile.nodes[1].city = Settlement.new("red")
    @board.getTile(1,0).number = 2
    cards = @board.get_cards(5, "red")
    assert_equal(3, cards.length)
  end

  # test that cities and settlements produce the right cards.
  def test_get_cards_with_bandit
    tile = @board.getTile(0,0)
    tile.has_bandit = true
    tile.number = 5
    tile.nodes[0].city = City.new("red")
    tile.nodes[5].city = Settlement.new("blue")
    assert_equal(0, @board.get_cards(5, "red").length)
    assert_equal(0, @board.get_cards(5, "blue").length)
    tile.nodes[1].city = Settlement.new("red")
    @board.getTile(1,0).number = 2
    assert_equal(0, @board.get_cards(5, "red").length)
    assert_equal(0, @board.get_cards(5, "blue").length)
  end
  
  def test_get_valid_road_spots
    assert_equal(0, @board.get_valid_road_spots("red").length)
    @board.place_city!(Settlement.new("red"), 0,0,0)
    assert_equal(2, @board.get_valid_road_spots("red").length)
    @board.place_road!(Road.new("red"), 0, 0, 1)
    assert_equal(3, @board.get_valid_road_spots("red").length)
    @board.place_road!(Road.new("red"), 0, 0, 2)
    assert_equal(4, @board.get_valid_road_spots("red").length)

    @board.place_city!(Settlement.new("blue"), 0, 0, 2)
    assert_equal(2, @board.get_valid_road_spots("red").length)
    assert_equal(2, @board.get_valid_road_spots("blue").length)
  end


  # Test that if you have 2 settlements connected with 1 road, 
  # You're still allowed to build other roads
  def test_get_valid_road_spots_on_settlement
    @board.place_city!(Settlement.new("red"), 0,0,0)
    @board.place_road!(Road.new("red"), 0, 0, 1)
    @board.place_road!(Road.new("red"), 1, 0, 0)
    @board.place_road!(Road.new("blue"), 0, 0, 2)
    @board.place_road!(Road.new("blue"), 0, 0, 0)
    assert_equal(1, @board.get_valid_road_spots("red").length)
    @board.place_city!(Settlement.new("red"), 1, 0, 0)
    assert_equal(1, @board.get_valid_road_spots("red").length)
  end

  def test_getValidSettlementSpots
    i = @board.get_valid_settlement_spots(false, nil).length
    assert_equal(@expected_nodes, i, "length0")
    i = @board.get_valid_settlement_spots(true, "red").length
    assert_equal(0, i, "length1")
    @board.place_road!(Road.new("red"), 0, 0, 0)
    i = @board.get_valid_settlement_spots(true, "red").length
    assert_equal(2, i, "length2")

    @board.place_road!(Road.new("red"), 0, 0, 1)
    i = @board.get_valid_settlement_spots(true, "red").length
    assert_equal(3, i, "length3")

    @board.place_road!(Road.new("red"), 0, 0, 2)
    @board.place_road!(Road.new("red"), 1, 0, 0)
    i = @board.get_valid_settlement_spots(true, "red").length
    assert_equal(5, i, "length4")
    i = @board.get_valid_settlement_spots(true, "blue").length
    assert_equal(0, i, "length4-blue")    

    @board.place_city!(Settlement.new("red"), 0, 0, 0)
    i = @board.get_valid_settlement_spots(true, "red").length

    assert_equal(2, i, "length5 w/settlement")
  end
  
  #Test the number of nodes that are created in a standard board.
  def test_nodes
    # count the nodes by edges
    ns=[]
    for t in @board.tiles.values
      for e in t.edges
        for n in e.nodes
          ns << n if not ns.include?(n)
        end
      end
    end
    assert_equal(@expected_nodes, ns.length)
    #count the nodes on the tiles
    nodes = []
    portNodes=[]
    @board.tiles.values.each{|t|
      t.nodes.each{|n|
        portNodes << n if n.port and not portNodes.include?(n)
        nodes << n if not nodes.include?(n)
      }
    }
    assert_equal(@expected_nodes, nodes.length)
    assert_equal(@expected_ports, portNodes.length)
  end
  
  def test_dev_card_bag
    dcb = DevelopmentCardBag.new
    (1..18).each do 
      card = dcb.get_card    
      assert(card.is_a?(DevelopmentCard))
    end
    assert_raise(RuleException) do
      dcb.get_card
    end
  end
  
  #A Board must have the bandit on it by default.  ONLY one
  def test_has_bandit
    bandit_hex = @board.tiles.values.select{|t| t.has_bandit}
    assert_equal(1, bandit_hex.size)
  end
end

#A invalid board used in the test_create_board_with_inland_port
class InlandPortBoard < StandardBoard
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
    coords = [[1,0,0], [2,1,1], 
            [0,2,2],  ## <-- inland port
            [1,3,2], [0,4,3], [-1,3,4], [-2,2,4],[-2,1,5],[-1,0,0]]
    
    for x,y,edge in coords
      portEdge = getTile(x, y).edges[edge]
      port = RandomPortFromBag.new
      for n in portEdge.nodes
        n.port = port
      end
    end  
  end
end    
 

class EdgeTest < Test::Unit::TestCase
  def setup
    @board  = StandardBoard.new
  end 

  #Assert that each edge has adjecent 2 <= edges <= 4
  def test_get_adjecent_edges
    @board.all_nodes.each{|node| 
      node.edges.each{|edge|
        assert_operator(edge.get_adjecent_edges.size, :<=, 4)      
        assert_operator(edge.get_adjecent_edges.size, :>=, 2)      
      }
    }
  end

  # Create a board and visit roads that touch but have differing colors.
  def test_visit_road_1
    e1 = @board.place_road!(Road.new("red"), 0, 2, 2)
    @board.place_road!(Road.new("red"), 1, 2, 0)
    @board.place_road!(Road.new("red"), 1, 1, 2)
    count=0
    e1.visit_road{|r| count+=1 }
    assert_equal(3, count, "red road length")

    e4 = @board.place_road!(Road.new("blue"), 1, 1, 1)
    @board.place_road!(Road.new("blue"), 1, 1, 0)
    count=0
    e4.visit_road{|r| count+=1 }
    assert_equal(2, count, "blue road length")

    @board.place_road!(Road.new("red"), 0, 2, 3)
    @board.place_road!(Road.new("red"), 0, 2, 4)
    count=0
    e1.visit_road{|r| count+=1 }
    assert_equal(5, count, "red road length2")
    count=0
    e4.visit_road{|r| count+=1 }
    assert_equal(2, count, "blue road length again")
  end
  
  # Create a board and visit the roads of a circle
  def test_visit_road_2
    e5 = @board.place_road!(Road.new("orange"), 0, 0, 0)
    @board.place_road!(Road.new("orange"), 0, 0, 1)
    @board.place_road!(Road.new("orange"), 0, 0, 2)
    @board.place_road!(Road.new("orange"), 0, 0, 3)
    @board.place_road!(Road.new("orange"), 0, 0, 4)
    @board.place_road!(Road.new("orange"), 0, 0, 5)
    count=0
    e5.visit_road{|r| count+=1 }
    assert_equal(6, count, "visiting a circle of roads")
  end
end


class NodeTest < Test::Unit::TestCase
  def setup
    @board  = StandardBoard.new
  end 

  #Test nodes know which nodes are touching.
  def test_getAdjecentNodes
    n5 = @board.getTile(0,0).nodes[5]
    n0 = @board.getTile(0,0).nodes[0]
    n1 = @board.getTile(0,0).nodes[1]
    assert(n5.get_adjecent_nodes.include?(n0))
    assert(n0.get_adjecent_nodes.include?(n1))
    assert((not n5.get_adjecent_nodes.include?(n1)))
  end

  #Test nodes know which nodes are touching.
  def test_getAdjecentNodes2
    for n in @board.all_nodes
      x = n.get_adjecent_nodes()
      assert(x.length >= 2)
      assert(x.length <= 3)
    end
    #test some specific nodes
    #tileCoord, node#, expectedResult
    tileNodeResult = [[0,0,0,2], [0,1,5,3], [1,1,3,3]]
    for x,y,node,result in tileNodeResult
      assert_equal(result, 
                   @board.getTile(x,y).nodes[node].get_adjecent_nodes().length,
                   "tile "+x.to_s+" "+y.to_s)
    end
  end
  
  #Test that a node knows the probablities touching it.
  def test_get_hex_prob
    @board.getTile(1,1).number = 3
    @board.getTile(0,2).number = 2
    @board.getTile(0,1).number = 12
    assert_equal(4.0 / 36, @board.getNode(1,1,4).get_hex_prob)
  end
end




class TileBagTests < Test::Unit::TestCase
  def test_standard_bag
    @bag = TileBag.new
    assert_equal(19, @bag.items.size)
  end

  def test_get_hex
    @bag = TileBag.new(50)
    for i in 1..69
       assert_not_nil(@bag.grab)
    end
    assert_nil(@bag.grab)
  end

  def test_get_port
    @bag = StandardPortBag.new
    for i in 1..9
       assert_not_nil(@bag.grab)
    end
    assert_nil(@bag.grab)
  end
end

require 'lib/boards/board_manager'
require 'lib/core/game_definition'
require 'lib/boards/board_impl'
#Run all the board tests but with a boarded loaded from disk
class SavedBoardTest < BoardTest
  def setup
    super
    @board  = BoardManager.load_board('standard.board')
  end
end

#class SavedBoardTest2 < BoardTest
#  def setup
#    @expected_hexes = 900
#    @expected_edges = 2819
#    @expected_nodes = 1920
#    @expected_ports = 0
#    @board  = BoardManager.load_board('lib/boards/square.board')
#  end
#end
#
#class SavedBoardTest3 < BoardTest
#  def setup
#    @expected_hexes = 24
#    @expected_edges = 99
#    @expected_nodes = 76
#    @expected_ports = 0
#    @board  = BoardManager.load_board('lib/boards/l_shaped.board')
#  end
#end
