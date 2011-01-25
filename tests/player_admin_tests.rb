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
require 'test/unit'
require 'tests/mock_objects'
require 'tests/test_utils'
require 'lib/boards/board_impl'

class AdminTest < Test::Unit::TestCase
  
  def setup
    @board = StandardBoard.new
    @admin = MockAdmin.new(@board, 4)
    p1 = MockPlayer.new('test player', @admin)
    p1.update_board(@board)
    turn = Turn.new(@admin, p1, @board)
    @admin.currentTurn = turn
  end
  
  # Roll the dice, make sure that they have valid numbers
  def test_roll_dice1
    for x in 0..100    
      assert_equal(2, @admin.roll_dice.length)
      for d in @admin.roll_dice
        assert(d<=6, "die roll <=6")
        assert(d>=1, "die roll >=1")
      end
    end
  end
  
  # register some players 
  def test_register_1
    p1 = MockPlayer.new("Player1", @admin)
    p2 = MockPlayer.new("Player2", @admin)
    @admin.register(p1, p2)
    assert_equal(2, @admin.players.size)
  end
  
  # register some players 
  def test_register_2
    p1 = MockPlayer.new("Player1", @admin)
    p2 = MockPlayer.new("Player2", @admin)
    @admin.register(p1)
    @admin.register(p2)
    assert_equal(2, @admin.players.size)
  end
end



class PlayerTest < Test::Unit::TestCase

  def test_add_cards
    p = Player.new("P1", nil)
    p.add_cards([OreType, OreType, OreType, WheatType])
    assert_equal(3, p.cards[OreType])
    assert_equal(1, p.cards[WheatType])
  end

  def test_del_cards
    p = Player.new("P1", nil)
    p.add_cards([OreType, OreType, OreType, WheatType])
    assert_raise(RuleException) do
      del = p.del_cards([OreType, OreType, OreType, WheatType, WheatType])
    end
    assert_equal(3, p.cards[OreType])
    assert_equal(1, p.cards[WheatType])
    del = p.del_cards([OreType, OreType, OreType, WheatType])
    assert_equal(0, p.cards[OreType])
    assert_equal(0, p.cards[WheatType])
    assert(del, "del_cards 2")
  end
end


