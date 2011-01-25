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
require 'lib/core/bots'
require 'test/unit'
require 'tests/test_utils'
require 'pp'

class BotTest < Test::Unit::TestCase

  def test_full_game_with_single_purchase
    winners = []
    i = 0
    100.times do
      b = StandardBoard.new
      a = Admin.new(b, 2, 10)
      p1 = RandomPlayer.new("Player1", a)
      p2 = RandomPlayer.new("Player2", a)
      p3 = RandomPlayer.new("Player3", a)
      p4 = SinglePurchasePlayer.new("SinglePurchasePlayer", a)
      p5 = SinglePurchasePlayer.new("SinglePurchasePlayer2", a)
      a.register(p1, p4)
      until a.is_game_done; sleep(0.005)end
      winners << a.has_winner?.name
      i+= 1; puts "Finished #{i} game(s)"; 
    end
#    winners.each{|w| puts w}
    pp winners.to_count_hash
  end

end
