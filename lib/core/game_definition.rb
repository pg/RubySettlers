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
  
  
#This class defines a game type or expansion pack.
#For instance, there could be a GameDefinition for the Standard version of 
#Settlers or Cities and Knights, SeaFearers, or even a custom game.
#The standard game definition is found in this file, but all others should be 
#located in the expansions directory
module GameDefinition
  attr_reader :name
  
  #Create an Admin that will enforce all the rules for this given game type
  def make_admin(board, maxPlayers, maxPoints=10)
    raise 'Not Implemented'
  end

  #Two GameDefinitions are equal if they are the same class.  
  def ==(o)
    self.class == o.class
  end
end


# Game definition for the standard game
# This separates the standard game from the expansions
class StandardGame 
  include GameDefinition

  def initialize
    @name = "Standard Game"
  end

  #Create an Admin that will enforce all the rules for this given game type
  def make_admin(board, maxPlayers, maxPoints=10)
    Admin.new(board, maxPlayers, maxPoints)
  end

end


#Gets all the game definitions found in the file system
def get_game_definitions
  result = [StandardGame.new]
  Dir.glob('lib/expansions/*/*.rb'){ |file|
    begin
      require file
      result << get_game_definition    
    rescue
      
    end
  }
  result.compact
end 

