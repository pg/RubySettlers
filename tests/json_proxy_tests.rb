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

require 'test/unit'
require 'tests/test_utils'
require 'lib/boards/board_impl'
require 'lib/core/bots'
require 'lib/core/proxies/json_rpc'
require 'lib/core/proxies/settlers_json'
require 'rubygems'
require 'flexmock/test_unit'
require 'timeout'

#Test that the game objects can be created and used as JSON proxy objects
class JSONProxyTest < Test::Unit::TestCase

  def test_proxy_constructors
    board = StandardBoard.new
    admin = Admin.new(board, 4)
    player = RandomPlayer.new('me', admin)
    t = Turn.new(admin, player, board)
    assert_equal(player, t.player)
  end

  def test_board_reconstruction_basic
    board = StandardBoard.new
    data = JSON.parse(board.to_json) 
    empty_connection = JSONConnection.new(nil)
    board2 = JSONBoard.from_json(data, empty_connection)
    assert_equal(board.name, board2.name)
    assert_equal(board.expansion, board2.expansion)
    assert_equal(board.tiles.values.size, board2.tiles.values.size)
  end

  def test_board_reconstruction_detailed_hexes
    board = StandardBoard.new
    data = JSON.parse(board.to_json)
    empty_connection = JSONConnection.new(nil)
    board2 = JSONBoard.from_json(data, empty_connection)
    for t in board.tiles.values
      assert(board2.tiles.values.include?(t))
      t2 = board2.getTile(*t.coords)
      assert_equal(t.nodes, t2.nodes)
      assert_equal(t.edges, t2.edges)
    end
  end

  def test_board_reconstruction_detailed_hexes
    board = StandardBoard.new
    data = JSON.parse(board.to_json) 
    empty_connection = JSONConnection.new(nil)
    board2 = JSONBoard.from_json(data, empty_connection)
    for e in board.all_edges
      e2 = board2.getEdge(*e.coords)
      assert_equal(e, e2)
      assert_equal(e.road, e2.road)
    end
  end

 def test_board_reconstruction_detailed_nodes
    board = StandardBoard.new
    board.getNode(0,0,0).city = City.new('blue')
    board.getNode(0,1,0).city = Settlement.new('blue')
    data = JSON.parse(board.to_json)
    empty_connection = JSONConnection.new(nil)
    board2 = JSONBoard.from_json(data, empty_connection)
    for n in board.all_nodes
      n2 = board2.getNode(*n.coords)
      assert_equal(n, n2)
      assert_equal(n.city, n2.city)
      assert_equal(n.port, n2.port)
    end
  end

 def test_board_reconstruction_detailed_roads
    board = StandardBoard.new
    board.getEdge(0,0,0).road = Road.new('blue')
    data = JSON.parse(board.to_json)
    empty_connection = JSONConnection.new(nil)
    board2 = JSONBoard.from_json(data, empty_connection)
    for e in board.all_edges
      e2 = board2.getEdge(*e.coords)
      assert_equal(e, e2)
      assert_equal(e.road, e2.road)
    end
  end

 def assert_not_respond_to(obj, method)
   fail("Object DOES respond to #{method}") if obj.respond_to?(method)
 end



end

class JSONConnectionTest < Test::Unit::TestCase
  def setup

  end

  def test5
  end
  
end

#Test actual games using different threads through JSON connections
class RealJSONTest < Test::Unit::TestCase

  def add_player(num, smart=true)
    begin
      client = SettlersJSONClient.new('localhost', SettlersJSONServer::DEFAULT_PORT, @log)
      admin = client.initial_object
	  if smart
		admin.register(SinglePurchasePlayer.new("smart player#{num}", admin))
	  else
		admin.register(RandomPlayer.new("player#{num}", admin))
	  end
      client
    rescue Exception
      client.close if client
      puts $!
      retry
    end
  end

  def setup
    #Log for th game
    $log = Logger.new(STDOUT)
    $log.level = Logger::WARN
    
    #Logger for the JSON Connection
    @log = Logger.new(STDOUT)
    @log.level = Logger::WARN
  end

  #run a full game
  def run_full_game(num_players)
    assert_nothing_raised("Game didn't finish in time") do
      Timeout::timeout(300) {
        players = []
        board = StandardBoard.new
        admin = Admin.new(board, num_players, 4)
        @server = SettlersJSONServer.new(admin, SettlersJSONServer::DEFAULT_PORT, @log) 
        Thread.new{ @server.serve }   
        (num_players).times {|n|
          Thread.new{
            players << add_player(n+1, true)
          }
        }
        while admin.gameThread == nil; sleep(0.1); end
        admin.gameThread.join
        @server.close
      }
    end
  end
  
  def test_full_game_2_players
    run_full_game 2
  end

  def test_full_game_4_players
    run_full_game 3
  end

  #This test fails on cygwin/ruby, but works fine in windows.
  #  Apparently cygwin/ruby doesn't release the port correctly
  def test_port_release
    port = 5459
    host = 'localhost'
    server = TCPServer.open(port)
    socks = []
    Thread.new {
      while socks.size < 3
        begin
          sock = server.accept
          socks << sock
          $log.info("Accepted SOCKET #{sock}")
        rescue Errno::EAGAIN, Errno::ECONNABORTED, Errno::EPROTO, Errno::EINTR
          IO.select([server])
          sleep(0.5)
          retry
        end    
      end
    }

    Thread.new {
      3.times do
        c = TCPSocket.open(host, port)
      end
    }

    while socks.size < 3
      sleep(0.1)
    end
    socks.each {|s| 
      s.shutdown
      s.close 
    }

    server.close
    assert_nothing_raised("Could not re-open port") do
      TCPServer.new(port)
    end
  end
  

end
