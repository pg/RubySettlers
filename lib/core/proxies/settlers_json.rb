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

###############################################################################
# This file defines all the Settlers-specific JSON info needed
# It defines how to convert Settlers-specific objects to and from JSON strings.
###############################################################################

require 'lib/core/proxies/json_rpc'

class SettlersJSONServer < JSON_RPC_Server
  DEFAULT_PORT = 7643
end

class SettlersJSONClient < JSON_RPC_Client
end


class Admin
  extend RemotelyAccessible
  allow_remote_methods :register, :register_observer, :is_game_done, :get_price
  allow_remote_methods :get_score, :count_resource_cards, :count_dev_cards, :chat_msg  

  def to_json(*a)
    {'class_name' => 'Admin',
     'remote_id' => object_id
    }.to_json(*a)
  end 
end

class PlayerInfo

  def to_json(*a)
    {'class_name' => 'PlayerInfo',
	 'name' => name,
	 'color' => color,
    }.to_json(*a)
  end 
  
  def PlayerInfo.from_json(json_hash, connection)
    info = PlayerInfo.new;
	info.color = json_hash['color'];
	info.name = json_hash['name'];
    info
  end
end


#Add json funcionality to the Board
class Board

  def to_json(*a)
    {
      'class_name' => 'JSONBoard',
      'tiles'  => @tiles.values,
      'meta_nodes' => all_nodes.select{|n| n.city or n.port}, #This will store the city, port data for all the nodes.
      'meta_edges' => all_edges.select{|e| e.road}, #This will store the road and coords for the edges
      'expansion' => @expansion.name,
      'name' => @name
    }.to_json(*a)
  end
  
  def inspect
    'board'
  end
end


class JSONBoard < Board

  def initialize(tiles, json_nodes, json_edges, expansion, name)
    @tile_list = tiles
    @expansion = expansion
    @name = name
    @json_nodes = json_nodes
    @json_edges = json_edges
    @connection = nil
    super(false, false)
  end
  
  def init_bags
  end
  
  def subclass_init
    @tiles = {}
    @tile_list.each{|t|
      @tiles[t.coords] = t
    }
    connectTiles
    
    for n in @json_nodes
      real_node = getNode(*n['coords'])
      city_hash = n['city']
      real_node.city = Settlement.from_json(city_hash, nil) if city_hash
      port_hash = n['port']
      real_node.port = Port.from_json(port_hash, nil) if port_hash
    end
    
    for e in @json_edges
      real_edge = getEdge(*e['coords'])
      road_hash = e['road']
      real_edge.road = Road.from_json(road_hash, nil) if road_hash
    end
  end
  
  def self.from_json(data, json_connection)
    @connection = json_connection
    hex_json = data['tiles']
    expansion = data['expansion']
    expansion = get_game_definitions.find{|ex| ex.name == expansion}
    name = data['name']
    tiles = hex_json.map{|hex|
      @connection.parse(hex) 
    }
    json_nodes = data['meta_nodes']
    json_edges = data['meta_edges']
    board = JSONBoard.new(tiles, json_nodes, json_edges, expansion, name)
    remote_id = data['remote_id']
    board
  end  
end


class Settlement
  def to_json(*a)
    { 'color' => self.color,
     'cityclass' => self.class,
     'class_name' => 'Settlement'}.to_json(*a)
  end

  def Settlement.from_json(json_hash, connection)
    klass = Class.from_json(json_hash['cityclass'], connection)
    klass.new(json_hash['color'])
  end
end


class Road
  def to_json(*a)
    { 'color' => self.color,
     'class_name' => 'Road',}.to_json(*a)
  end
  
  def Road.from_json(hash, connection)
    Road.new(hash['color'])
  end
end


class Port
  def to_json(*a)
    {
      'class_name' => 'Port',
      'remote_id' => object_id, 
      'type' => self.type,
      'rate' => self.rate,
    }.to_json(*a)
  end
  
  def Port.from_json(json_hash, json_connection)
    type_name = json_hash['type']
    type = if type_name then Class.from_json(type_name, json_connection) else nil end
    Port.new(type, json_hash['rate'])
  end
end


class Hex
  def to_json(*a)
    {
      'class_name' => 'Hex',
      'remote_id' => object_id, 
      'number' => @number,
      'coords' => @coords,
      'card_type' => @card_type,
      'has_bandit' => @has_bandit,
	  'nodes' => @nodes,
	  'edges' => @edges
    }.to_json(*a)
  end
  
  def Hex.from_json(json_hash, json_connection)
    card_type = json_connection.get_real_object(json_hash['card_type'])
    number = json_connection.get_real_object(json_hash['number'])
    has_bandit = json_connection.get_real_object(json_hash['has_bandit'])

    hex = Hex.new(card_type, number, has_bandit)
    hex.coords = json_hash['coords']
    hex
  end
end


class Node
  def to_json(*a)
    {
      'class_name' => 'Node',
      'city' => self.city,
      'port' => self.port,
      'coords' => self.coords
    }.to_json(*a)
  end
  
  def Node.from_json(hash, json_connection)
    n = Node.new
    n.city = hash['city']
    n.coords = hash['coords']
    n
  end
end


class Edge
  def to_json(*a)
    {
      'class_name' => 'Edge',
      'road' => @road,
      'coords' => @coords,
	  'nodes' => @nodes
    }.to_json(*a)
  end
  
  def Edge.from_json(hash, json_connection)
    e = Edge.new
    e.coords = hash['coords']
    e.road = hash['road']
    e
  end
end


class Turn
  extend RemotelyAccessible
  allow_remote_methods :roll_dice, :buy_development_card, :get_quotes, :is_setup
  allow_remote_methods :get_quotes_from_bank, :accept_quote, :done
  allow_remote_methods :place_road!, :place_settlement!, :place_city!
  allow_remote_methods :place_road, :place_settlement, :place_city
  allow_remote_methods :play_development_card!, :move_bandit, :active_cards
  allow_remote_methods :placed_settlement, :placed_road, :isDone, :get_valid_settlement_spots
  
  def to_json(*a)
    {'class_name' => 'Turn',
     'remote_id' => object_id}.to_json(*a)
  end
end


class Quote
  def Quote.from_json(hash, connection)
    tradee = nil
    if hash['tradee']
      tradee = connection.parse(hash['tradee'])
    end
    receiveType = connection.parse(hash['receiveType'])
    receiveNum = hash['receiveNum']
    giveType = connection.parse(hash['giveType'])
    giveNum = hash['giveNum']
    Quote.new(tradee, receiveType,receiveNum, giveType, giveNum) 
  end

  def to_json(*a)
    { 'class_name' => 'Quote',
     'tradee' => @bidder,
     'receiveType' => @receiveType, 
     'receiveNum' => @receiveNum,
     'giveType' => @giveType, 
     'giveNum' => @giveNum
    }.to_json(*a)
  end 

end


class Player
  extend RemotelyAccessible
  allow_remote_methods :color=, :update_board, :next_turn, :game_end, :played_dev_card
  allow_remote_methods :placed_city, :placed_settlement, :placed_road, :player_moved_bandit
  allow_remote_methods :player_stole_card, :game_start, :add_cards, :del_cards
  allow_remote_methods :player_joined, :get_turn, :player_rolled, :player_received_cards, :addPiecesLeft
  allow_remote_methods :preferred_color, :take_turn, :move_bandit, :select_resource_cards, :select_player, :chat_msg
  allow_remote_methods :get_user_quotes
  allow_remote_methods :info, :name, :piecesLeft, :color, :get_played_dev_cards, :purchased_pieces
  allow_remote_methods :count_resources, :cards, :resource_cards  
  
  def to_json(*a)
    { 'class_name' => 'Player',
      'remote_id' => object_id,
    }.to_json(*a)
  end
end
