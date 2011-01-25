class RealStartupDialog < StartupDialog
  
  IMAGE_DIR = 'lib/img/'
  
  def initialize(*a)
    super
    @parent = a[0]
    buttons = ['quick_start', 'join', 'host']
    for name in buttons
      button_name = "startup_#{name}_button"
      big, small = create_big_and_small_bitmaps(button_name+".png")
      button = send(button_name)
      button.set_bitmap_label(small)
      button.set_bitmap_hover(big)
      evt_button(button, "on_"+name)
    end
  end
  
  def create_big_and_small_bitmaps(filename)
    image = Wx::Image.new
    image.load_file(IMAGE_DIR + filename, Wx::BITMAP_TYPE_PNG)
    small = image.copy
    small.rescale(175,45) 
    small_bitmap = Wx::Bitmap.new(small) 
    big = image.copy
    big.rescale(200,50) 
    big_bitmap = Wx::Bitmap.new(big)     
    [big_bitmap, small_bitmap]
  end
  
  def on_quick_start
    @parent.on_quick_start_menu
    end_modal(Wx::ID_OK)
    close
  end
  
  def on_join
    @parent.on_join_menu
    end_modal(Wx::ID_OK)
    close
  end
  
  def on_host
    @parent.on_host_menu
    end_modal(Wx::ID_OK)
    close
  end
end