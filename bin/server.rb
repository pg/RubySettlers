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
  
  
require 'lib/core/admin'
require 'lib/core/player'
require 'lib/core/bots'
require 'lib/boards/board_manager'
require 'lib/core/game_definition'
require 'socket'
require 'drb'
require 'commandline'
require 'logger'
require 'lib/core/proxies/settlers_json'


## Logger init
$log = Logger.new(STDOUT)
$log.level = Logger::DEBUG

class GameServer < CommandLine::Application
  def initialize
    version           "0.0.1"
    author            "John J Kennedy III"
    copyright         "2007, John J Kennedy III.  This Software is under the GPL License."
    synopsis  "[--players -p number] [--board filename] [--points number] [--bots number] [-i level] [-port number]"
    short_description "Launches a settlers game server"
    long_description  "Launches a settlers game server and waits for the max number of players."
    
    option :names => %w(--players -p), 
           :opt_found => get_args, :opt_not_found => 4,
           :opt_description => "The number of players allowed. "+
                               "The server will wait until this many players connect before the game starts.",
           :arg_description => "<number>"

    option :names => %w(--board), 
           :opt_found => get_args, :opt_not_found => 'standard.board',
           :opt_description => "The board file to play",
           :arg_description => "<filename>"

    option :names => %w(--points), 
           :opt_found => get_args, :opt_not_found => 10,
           :opt_description => "How many points to play to",
           :arg_description => "<number>"

#    option :names => %w(--expansion -x), 
#           :opt_found => get_args, :opt_not_found => 'Standard',
#           :opt_description => "The expansion pack to play()",
#           :arg_description => "<expansion name>"

    option :names => %w(--bots), 
           :opt_found => get_args, :opt_not_found => 0,
           :opt_description => "The number of bots to play",
           :arg_description => "<number>"

    option :names => %w(--bot-intelligence -i), 
           :opt_found => get_args, :opt_not_found => 0,
           :opt_description => "The level of intelligence for the artificial players",
           :arg_description => "<number>"
           
    option :names => %w(--port), 
           :opt_found => get_args, :opt_not_found => SettlersJSONServer::DEFAULT_PORT,
           :opt_description => "The port to run on",
           :arg_description => "<port number>"
    option :help
  end  
  
  def main(opt=opt)
    
    players = opt["--players"].to_i
    board = BoardManager.load_board(opt["--board"])
    port = opt["--port"].to_i
    points = opt["--points"].to_i

    puts "Starting a server on localhost:#{port} ..."
    puts "Maximum Players: #{players}"
    puts "Board: #{board.name}"
    puts "Play to #{points} points"
    @admin = Admin.new(board, players, points)
		if opt["--bots"]
		  for i in (1..(opt["--bots"].to_i))
				puts "Adding Bot##{i}"
				@admin.register(RandomPlayer.new("player#{i}", @admin))
			end
		end		
    puts 'Waiting for connections...'
    STDOUT.flush
   # DRb.start_service("druby://localhost:#{port}", @admin)
    
    server = SettlersJSONServer.new(@admin, port, $log) 
    server.serve
    
    while @admin.gameThread == nil; sleep(1); end
    @admin.gameThread.join
    sleep(1)
    puts 'done'
  end
end

