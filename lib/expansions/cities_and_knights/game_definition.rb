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
  
class CNExpansionGame 
  include GameDefinition

  def initialize
    @name = "Cities and Knights"
  end
  
  def make_admin(board, maxPlayers, maxPoints=10)
    CKAdmin.new(board, maxPlayers, maxPoints)
  end
end


def get_game_definition
  CNExpansionGame.new
  nil #not ready yet
end