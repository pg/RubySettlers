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
require 'test/unit'
require 'tests/test_utils'
require 'lib/boards/board_impl'

# This test suite tests the system using LARGE maps with a LOT of pieces
#TODO: write tests for running multiple games at once. i.e. big game servers.
class StressTest < Test::Unit::TestCase

  def setup
    @board = StandardBoard.new
  end

  #Stress tests has_longest_road on a board with LOTS of roads.
  #Adds 40 roads to a board and calls has_longest_road each time.
  #[NOTE] this starts to slow down a lot around 50 roads or so.  This is ok since
  # it only scans connected roads of the same color.  and most versions of the game
  # don't allow more than 20 roads.
  def test_has_longest_road
    counter = 0
    for x, y in @board.tiles.keys
      tile = @board.getTile(x, y)
      tile.edges.each_with_index{ |edge, i|
        unless edge.road
          timestamp = Time.now          
          @board.place_road!(Road.new("red"), x,y,i) 
          counter += 1
          assert_operator(Time.now - timestamp, :<, 5, "Adding a road took longer than 3 seconds.")          
          return if counter == 40
        end
      }
    end
  end

  def test_build_HUGE_board
    ts = Time.now
    b = SquareBoard.new(100)
    assert_operator(Time.now - ts, :<, 30, "Board took too long to create")
    assert_equal(b.tiles.size, 10000)
  end

end

