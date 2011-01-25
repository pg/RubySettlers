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
require 'logger'

#This module handles the saving and loading of Boards to the filesystem
module BoardManager
  
  BOARD_DIR = 'lib/boards/'
  $log = Logger.new(STDOUT)
  $log.level = Logger::INFO

  # gets a list of board objects and their corresponding filenames
  # [expansion] the game definition to filter the boards by
  # if expansion if nil, then this will get all available boards
  def BoardManager.get_boards(expansion=nil)
    result = []
    Dir.glob(BOARD_DIR+'*.board'){|file| 
      begin
        b = BoardManager.load_board(File.basename(file))
        result << [b, file] if b.expansion == expansion or expansion == nil
      rescue
        puts "error loading file: #{file}"
        puts $!
        puts $!.backtrace.join("\n")
      end
    }
    result
  end
  
  def BoardManager.save_board(board, filename)
    File.open(BOARD_DIR+filename, 'w+') do |f|
      Marshal.dump(board, f)
    end
  end
  
  def BoardManager.load_board(filename)
    File.open(BOARD_DIR+filename) do |f|
      board = Marshal.load(f)
      board.randomize_board! #Randomize any necessary pieces.
      board.enforce_bandit
      return board
    end
  end
  
  #Creates files for all the standard boards
  def BoardManager.save_out_standard_boards
    save_board(StandardBoard.new, 'standard.board')
    save_board(L_Board.new, 'l_shaped.board')
    save_board(SquareBoard.new(20), 'square.board')
  end
end


if __FILE__ == $0
  BoardManager.save_out_standard_boards
  puts 'Created Files'
  STDOUT.flush
  BoardManager.get_boards.each{|b, filename| 
    puts "Successfully loaded #{b.name} to #{filename}"
  }
end
