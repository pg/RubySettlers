require 'lib/core/board'
require 'lib/boards/board_manager'
require 'lib/boards/board_impl'
require 'fox16'
require 'fox16/colors'
include Fox

require 'lib/ui/fxruby/fxplayer'

class BoardBuilder < FXMainWindow
  def initialize(app, filename=nil)
    super(app, "Board Builder", :x=>300, :y=>200, :width=>600, :height=>600)
    build_menubar    
    @h_frame = FXHorizontalFrame.new(self, :opts => LAYOUT_FILL_X|LAYOUT_FILL_Y)
    @board_canvas = FXCanvas.new(@h_frame, :opts => LAYOUT_FILL_X|LAYOUT_FILL_Y|LAYOUT_LEFT)
    @board_canvas.connect(SEL_PAINT) do |sender, sel, event|
      FXDCWindow.new(@board_canvas, event) do |dc|
        dc.foreground = FXColor::White
        dc.fillRectangle(event.rect.x, event.rect.y, event.rect.w, event.rect.h)
      end
    end
    
    @board_canvas.dropEnable
    
    # Handle SEL_DND_MOTION messages from the canvas
    @board_canvas.connect(SEL_DND_MOTION) do
      # Accept drops unconditionally (for now)
      @board_canvas.acceptDrop
    end

  
    @toolbox = PieceToolBox.new(@h_frame, :opts => FRAME_SUNKEN|LAYOUT_FILL_Y,
      :padding => 0, :hSpacing => 0, :vSpacing => 0)

    
    @prop_frame = FXMatrix.new(@h_frame, 2, MATRIX_BY_COLUMNS)
    @board_name = text_field(@prop_frame, "Name:", "")
    
    games = get_game_definitions.map{|gd| gd.name}
    @board_expansion = combo_box(@prop_frame, "Expansion:", games)
    
    
    FXLabel.new(@prop_frame, "Recomened Players:")
    recomended_h_frame = FXHorizontalFrame.new(@prop_frame, :opts => LAYOUT_FILL_X)
    FXLabel.new(recomended_h_frame, "from")
    @recomended_min = FXSpinner.new(recomended_h_frame, 2, nil, FRAME_SUNKEN|FRAME_THICK)
    @recomended_min.range = 2..10
    @recomended_min.connect(SEL_COMMAND) do |sender, sel, event|
       @recomended_max.range = @recomended_min.value..@recomended_max.range.max
    end
    FXLabel.new(recomended_h_frame, "to")
    @recomended_max = FXSpinner.new(recomended_h_frame, 2, nil, FRAME_SUNKEN|FRAME_THICK)
    @recomended_max.range = 2..10
    load_board(filename)
  end
  
  def build_menubar
    #menus
    menubar = FXMenuBar.new(self, LAYOUT_SIDE_TOP|LAYOUT_FILL_X)
    filemenu = FXMenuPane.new(self)
    FXMenuTitle.new(menubar, "&File", nil, filemenu)
    FXMenuCommand.new(filemenu, "&New board", nil, getApp()).connect(SEL_COMMAND) do |sender, selector, data|
      load_board(nil)
    end
    
    FXMenuCommand.new(filemenu, "&Open board", nil, getApp()).connect(SEL_COMMAND) do |sender, selector, data|
   	  filename = FXFileDialog.getOpenFilename(self, "Open a board", BoardManager::BOARD_DIR, "*.board")
   	  if filename != nil and filename != '' 
        begin
          load_board(filename)
          @current_filename = filename
        rescue
          puts 'Error while opening board'
          puts $!
          puts $!.backtrace.join("\n")
        end
      end
    end
    
    FXMenuSeparator.new(filemenu);
    FXMenuCommand.new(filemenu, "&Save", nil, getApp()).connect(SEL_COMMAND) do |sender, selector, data|
      if @current_filename == nil or @current_filename == '' 
        @current_filename = FXFileDialog.getSaveFilename(self, "Save board", BoardManager::BOARD_DIR, "*.board")
      end
      if @current_filename != nil and @current_filename != '' 
        BoardManager.save_board(@board, @current_filename) 
      end
    end
    
    FXMenuCommand.new(filemenu, "Save &As", nil, getApp()).connect(SEL_COMMAND) do |sender, selector, data|
      @current_filename = FXFileDialog.getSaveFilename(self, "Save board", BoardManager::BOARD_DIR, "*.board")
      if @current_filename != nil and @current_filename != '' 
        BoardManager.save_board(@board, @current_filename) 
      end
    end
    
    FXMenuSeparator.new(filemenu);
    FXMenuCommand.new(filemenu, "&Close", nil, getApp()).connect(SEL_COMMAND) do |sender, selector, data|
    
    end
    
    expansion_menu = FXMenuPane.new(self)
    FXMenuTitle.new(menubar, "&Help", nil, expansion_menu)
    FXMenuCommand.new(expansion_menu, "&Help Contents", nil, getApp()).connect(SEL_COMMAND) do |sender, selector, data|
    
    end  
    FXMenuCommand.new(expansion_menu, "&About", nil, getApp()).connect(SEL_COMMAND) do |sender, selector, data|
    
    end  
  end
  
  #loads a board onto the editor
  #[filename] The board to load.  It this is nil, then a new board is loaded.
  def load_board(filename)
    if filename
      @board = BoardManager.load_board(filename)
      self.title = 'Board Builder - ' + filename
    else
      @board = BlankBoard.new
      self.title = 'Board Builder - Untitled Board'
    end
    @board_name.text = @board.name
    (0..@board_expansion.numItems-1).each do |i|
      @board_expansion.setCurrentItem(i) if @board_expansion.getItem(i) == @board.expansion.name
    end
    @recomended_max.value = @board.recomended_players.first
    @recomended_max.value = @board.recomended_players.last
  end
  
  # Create and initialize
  def create
    super
    
    # Register the drag type for colors
    FXWindow.colorType = getApp().registerDragType(FXWindow.colorTypeName)
    
    show(PLACEMENT_SCREEN)
  end
end


class EmptyBag < RandomBag
  def initialize
    @items = []
  end
end


class BlankBoard < Board
  def init_bags
    @tile_bag = EmptyBag.new
    @port_bag = EmptyBag.new
    @number_bag = EmptyBag.new
  end

  def subclass_init
    @name = 'New Board'
    @expansion = StandardGame.new
    @recomended_players = 2..4    
    connectTiles
  end
end

#The toolbox of pieces that users can add from.
class PieceToolBox < FXShutter
  def initialize(*args)
    super(*args)
    @hexItems = FXShutterItem.new(self, "Hexes")
    @portItems = FXShutterItem.new(self, "Ports")
    @numberItems = FXShutterItem.new(self, "Numbers")
    imgDir = 'lib/img/'    
    RESOURCE_TYPES.each{|r|
      filename = imgDir + FXPlayer::IMAGE_FILES[r]
      img = FXTIFIcon.new(app, nil)
      FXFileStream.open(filename, FXStreamLoad) { |stream| 
        img.loadPixels(stream) 
      }
      img.scale(50, 42)
      img.create   
      FXButton.new(@hexItems, r.to_s, img)
      break
    }
    
    
  end
  
end


if __FILE__ == $0
  require 'bin/rubysettlers'

  # Construct the application
  application = FXApp.new("RubySettlers", "RubySettlers")
  
  application.disableThreads

  # Construct the main window
  bb = BoardBuilder.new(application)

  # Create the app's windows
  application.create
  # Run the application
  application.run
end

