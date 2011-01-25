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
require 'lib/boards/board_impl'
require 'lib/ui/fxruby/fxplayer'
require 'drb'
require 'commandline'
require 'lib/core/proxies/settlers_json'


class Client < CommandLine::Application
  def initialize
    version           "0.0.1"
    author            "John J Kennedy III"
    copyright         "2007, John J Kennedy III.  This Software is under the GPL License."
    synopsis  "[-p port] [--host hostname] [--extra_bot_names names][--client_type client_type] player_name"
    short_description "Launches a settlers client."
    long_description  "Launches a settlers client and attempts to connect to the specified server."
    option :names => %w(--host), 
           :opt_found => get_args, :opt_not_found => 'localhost',
           :opt_description => "The location of the Settlers server.  Default is 'localhost'",
           :arg_description => "<hostname>"
           
    option :names => %w(--port -p), 
           :opt_found => get_args, :opt_not_found => 7643,
           :opt_description => "The server's port",
           :arg_description => "<port number>"
           
    option :names => %w(--client_type -cl), 
           :opt_found => get_args, :opt_not_found => 'fx_player',
           :opt_description => "the player class to create",
           :arg_description => "(can be fxplayer, simple_bot)"  
    
    option :names => %w(--extra_bot_names), 
           :arity => [1,-1],
           :opt_found => get_args, :opt_not_found => [],
           :opt_description => "This option is used when creating bots.  It lets you add extra bots to a game.",
           :arg_description => "<list of strings>"  
  
    option :help
    expected_args :username
  end
  
  def main
    $log = Logger.new(STDOUT)
    $log.level = Logger::INFO
    begin
      puts "Connecting to #{@option_data.host}:#{@option_data.port}"
      client = SettlersJSONClient.new(@option_data.host, @option_data.port, $log)
      admin = client.initial_object
      cl = opt["--client_type"]
      players = []
      if cl == 'fx_player'
        players << FXPlayer.new(@username, admin)
      elsif cl == 'simple_bot'
        players << SinglePurchasePlayer.new(@username, admin)
        for name in opt["--extra_bot_names"]
          players << RandomPlayer.new(name, admin)
        end
      else
        raise "Unknown player type: #{cl}"
      end
      players.each{|p| puts "Registering player '#{p.name}' [#{p.class}]"}
      puts admin
      STDOUT.flush

      admin.register(*players)
      until players[0].game_finished
        sleep(0.01)
      end
    rescue DRb::DRbConnError
      puts 'disconnected'
    end
  end
end

