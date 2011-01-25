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
  
require 'logger'
require 'timeout'
require 'lib/core/admin'
require 'lib/core/player'
require 'lib/core/game_definition'
  
## Logger init
$log = Logger.new(STDOUT)
$log.level = Logger::WARN

def wait_with_timeout(time = 10)
  timeout(time) do
    while yield
      sleep(0.1)
    end
  end
end

#increase visiblity in test classes
class Turn
  attr_accessor :hasRolled, :isDone, :admin, :player
end

#just a simple helper method to give a player a TON of cards
def make_rich(player)
  player.add_cards([OreType]*100+
                             [WheatType]*100+
                             [BrickType]*100+
                             [SheepType]*100+
                             [WoodType]*100)
end

def test_board1
  BoardManager.load_board('../../tests/boards/TestBoard_FixedGame1.board')
end
