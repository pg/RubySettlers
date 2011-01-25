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
  
  
require 'tk'
require 'board'
require 'admin'
require 'player'
require 'boardViewer'

class BoardViewerTK < BoardViewer
  include Math

  attr_reader :board, :thread

  def initialize
    super
    @thread = Thread.new{
      root = TkRoot.new{ title 'BoardViewerTK'; height 600; width 600}
      @canvas = TkCanvas.new(root){height 600; width 600}
      @canvas.bind("ButtonPress"){|e| buttonClick(e) }
      @canvas.bind("Motion"){|e| buttonMove(e) }
      @canvas.pack
      ObjectSpace.each_object(Class){|c| 
        #puts c if c.to_s =~ /Tk/
        #        if c.methods.find{|m| m.to_s == "mainloop"}
        #          puts c
        #        end
      }
      
#      puts @canvas.methods.select{|m| 
#        m.to_s =~ /wait|active|appsend/
#}
      
      Tk.mainloop
    }
    @scale = 40
  end
  
  def buttonClick(e)
    x, y = e.x, e.y
    puts x, y
  end

  def buttonMove(e)
    x, y = e.x, e.y
#    puts x, y
  end

  def update(board)

    leftMostCoord = board.tiles.values.map{|t| t.coords[0]}.min
    leftMostCoord = (leftMostCoord * @scale * (1+cos(@angle60))).abs
    if not @board
      board.tiles.values.each{|t| drawHex(@canvas, t, @scale, leftMostCoord)}
    end
    @board = board

    #roads
    for t in board.tiles.values
      for e in t.edges
        if e.road and not e.road.tainted?
          e.road.taint
          x1,y1 = getNodeCoords(e.nodes[0], @scale, leftMostCoord)
          x2,y2 = getNodeCoords(e.nodes[1], @scale, leftMostCoord)
          TkcLine.new(@canvas, x1, y1, x2, y2).fill(e.road.color)
          for i in 1..2
            TkcLine.new(x1, y1+i, x2, y2+i).fill(e.road.color)
            TkcLine.new(x1, y1-i, x2, y2-i).fill(e.road.color)            
          end
        end
      end
    end
    

    #cities
    for n in board.all_nodes
      if n.city and not n.city.tainted?
        n.city.taint
        x,y = getNodeCoords(n, @scale, leftMostCoord)
        s = n.city.instance_of?(Settlement) ? @scale/7 : @scale/3
        TkcRectangle.new(@canvas, x-s, y-s, x+s, y+s).fill(n.city.color)
      end
    end

  end

  #xShift is the amount to shift the graph to the right
  def drawHex(canvas, hex, side, xShift)
    vs = getVertices(hex, side, xShift)
    colors={
      WoodType=>'darkgreen',
      SheepType=>'green',
      BrickType=>'red',
      OreType=>'darkviolet',
      WheatType=>'gold',
      "desert"=>'brown'}
    TkcPolygon.new(canvas, vs).fill(colors[hex.cardType])
    if hex.cardType != "desert"
      TkcText.new(canvas, vs[4][0]+@scale, vs[4][1]){text hex.number.to_s; font TkFont.new()}
    end
  end
end

b = Board2.new
a = Admin.new(b, 2)
gui = BoardViewerTK.new
gui.update(b)
p1 = RandomPlayer.new("p1", a, gui)
p2 = RandomPlayer.new("p2", a)
a.register(p1, p2)

while gui.thread.alive?; sleep(0.1) end
