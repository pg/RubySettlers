class WidgetManager
  attr_reader :app, :canvas, :children

  def initialize(app, canvas, player)
    @app = app
    @canvas = canvas
    @player = player
    @children = []
    @canvas.connect(SEL_LEFTBUTTONPRESS, method(:on_click))
    @canvas.connect(SEL_MOTION, method(:on_mouse_motion))
  end

  def on_click(sender, sel, event)
    for child in @children
      if child.respond_to?(:on_click)
        consumed = child.on_click(sender, sel, event)
        return if consumed
      end
    end
    @player.on_canvas_left_click(sender, sel, event)
  end

  def on_mouse_motion(sender, sel, event)
    for child in @children
      if child.respond_to?(:on_mouse_motion)
        consumed = child.on_mouse_motion(sender, sel, event)
        return if consumed
      end
    end
    @player.on_canvas_mouse_motion(sender, sel, event)
  end


  def add(widget)
    widget.manager = self
    @children << widget
  end

  #layout all the children
  def layout(available_width, available_height)
    #the left anchored children
    left_anchored = @children.select{|c| c.horizontal_anchor == CanvasWidget::ANCHOR_LEFT }
    #the right anchored children
    right_anchored = @children.select{|c| c.horizontal_anchor == CanvasWidget::ANCHOR_RIGHT }
    #the bottom anchored children
    bottom_anchored = @children.select{|c| c.vertical_anchor == CanvasWidget::ANCHOR_BOTTOM }
    #the top anchored children
    top_anchored = @children.select{|c| c.vertical_anchor == CanvasWidget::ANCHOR_TOP }

    @children.each{|c| c.layout(available_width, available_height) }

    left_anchored.each{|c| c.x = 0}
    right_anchored.each{|c| c.x = available_width - c.width}
    top_anchored.each{|c| c.y = 0}
    bottom_anchored.each{|c| c.y = available_height - c.height}

    
    for child in left_anchored
      tainted = left_anchored.select{|c| c.tainted? }
      overlapped = tainted.select{|c| children_overlap_y?(child, c) }
      if overlapped.size > 0
        #Now find the left-most overlapping child
        overlapped_max_x = overlapped.map{|c| c.x + c.width}.max
        leftmost_child = overlapped.find{|c| c.x+c.width == overlapped_max_x}
        if leftmost_child
          child.x = leftmost_child.x + leftmost_child.width + 1
        end
      else
        child.x = 0
      end
      child.taint
#      puts "CHILD x:#{child.x}, y#{child.y} height#{child.height}"
    end
    left_anchored.each{|c| c.untaint }

    
  end

  #Do the given children overlap on the y axis? (assuming that they are on the same x axis)
  def children_overlap_y?(child1, child2)
    true
  end


  def paint(dc)
    @children.each{|c| c.paint(dc) }
  end

  def invalidate
    layout(@canvas.width, @canvas.height)
  end
end



class CanvasWidget
  VERTICAL_ANCHOR_MASK = 3
  ANCHOR_BOTTOM = 1
  ANCHOR_TOP = 2

  HORIZONTAL_ANCHOR_MASK = 12
  ANCHOR_LEFT = 4
  ANCHOR_RIGHT = 8


  #Vertical anchors can be ORed together with horizontal anchors
  #For instance, you can anchor bottom with left or top with right
  ANCHORS = [ANCHOR_RIGHT, ANCHOR_LEFT, ANCHOR_TOP, ANCHOR_BOTTOM]

  attr_reader :app
  attr_accessor :manager
  attr_reader :anchor
  attr_reader :horizontal_anchor, :vertical_anchor
  attr_accessor :x, :y

  def initialize(app, canvas)
    @manager = nil
    @canvas = canvas
    @app = app
    @anchor = ANCHOR_BOTTOM #default anchor
    @x = 0
    @y = 0
  end

  def anchor=(a)
    horizontal_anchor = a & HORIZONTAL_ANCHOR_MASK
    vertical_anchor = a & VERTICAL_ANCHOR_MASK
    raise "Invalid anchor: #{a}" unless ANCHORS.include?(horizontal_anchor) and ANCHORS.include?(vertical_anchor) 
    @anchor = a
    @horizontal_anchor = horizontal_anchor
    @vertical_anchor = vertical_anchor
  end

  #layout the child
  #This should be overriden by the implmenting child
  #After this method is finished, the height and width should be set.
  def layout
  end

  def repaint
    @canvas.repaint
  end
end



class ExpandableWidget < CanvasWidget
  
  attr_reader :is_expanded, :width, :height, :player
  attr_accessor :collapsed_width, :collapsed_height, :expanded_width, :expanded_height, :x, :y


  def initialize(app, canvas, player)
    super(app, canvas)
    @player = player
    
    #set some defaults
    @collapsed_height = 25
    @collapsed_width = 100
    @expanded_height = 100
    @expanded_width = 200
    
    @is_expanded = false
    @collapsed_text_label = 'Collapsed Widget'
    @collapsed_text_color = FXColor::Black
    @collapsed_back_color = FXColor::Blue
    @f = FXFont.new(@app, "arial", 14)
    @f.create
    @drew_hover_text = false #Is the hover text color being drawn?
  end

  def on_click(sender, sel, event)
    change = (event.win_x.between?(@toggle_x, @toggle_x+@collapsed_width) and
              event.win_y.between?(@toggle_y, @toggle_y+@collapsed_height))
    if change
      @is_expanded = !@is_expanded    
      @manager.layout(@canvas.width, @canvas.height)
      @canvas.update
    end
    change
  end
  
  def on_mouse_motion(sender, sel, event)
    return false unless @toggle_y and @toggle_x
    hover = (event.win_x.between?(@toggle_x, @toggle_x+@collapsed_width) and
                event.win_y.between?(@toggle_y, @toggle_y+@collapsed_height))
    if hover
      prevColor = @collapsed_text_color
      @collapsed_text_color = FXColor::Red
      @player.draw_board
      @collapsed_text_color = prevColor
      @drew_hover_text = true
    elsif @drew_hover_text
      @player.draw_board
      @drew_hover_text = false
    end
    hover
  end


  def paint(dc)
    if is_expanded
      draw_expanded(dc)
    else
      draw_toggle_button(dc, @x, @y)
    end
  end
  
  def draw_toggle_button(dc, x, y)
    @toggle_x = x #The current x of the toggle button
    @toggle_y = y+3 #The current x of the toggle button
    dc.foreground = @collapsed_back_color
    dc.fillRoundRectangle(x, y+3, @collapsed_width, @collapsed_height, 30, @collapsed_height*0.3)     
    dc.foreground = @collapsed_text_color
    dc.setFont(@f)
    dc.drawText(x+10, y+@collapsed_height-3, @collapsed_text_label)
  end

  def layout(width, height)
    if is_expanded
      @width = @expanded_width
      @height = @expanded_height
    else
      @width = @collapsed_width
      @height = @collapsed_height
    end
  end

end

