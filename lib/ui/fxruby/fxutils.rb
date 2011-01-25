class FXListBox
  def append_item(*args)
    appendItem(*args)
    setNumVisible([5, numItems].min)
  end
end

def text_field(frame, label, initial_value=nil, columns = 20)
  FXLabel.new(frame, label)
  field = FXTextField.new(frame, columns, nil, FRAME_SUNKEN|FRAME_THICK)
  field.text = initial_value if initial_value
  field
end

def number_option(frame, text, range, initial_value=nil)
  FXLabel.new(frame, text)
  option = FXSpinner.new(frame, 5, nil, DECOR_ALL)
  option.setRange(range)
  option.value = initial_value if initial_value
  option
end

def number_field(parent, label_text, initial_value, cols=5)
  FXLabel.new(parent, label_text)
  f = FXTextField.new(parent, cols, :opts=>TEXTFIELD_INTEGER)
  f.text = initial_value.to_s
  f
end

def combo_box(parent, label_text, choices, default_index=0, width = 15, hidden=false)
  label = FXLabel.new(parent, label_text)
  label.hide if hidden
  combo = FXListBox.new(parent, nil, default_index)
  combo.hide if hidden
  choices.each{|c| combo.append_item(c) }
  combo
end


COLOR_HASH ={"blue"=>FXColor::Blue,
           "red"=>FXColor::Red, 
           "white"=>FXColor::White, 
           "orange"=>FXColor::Orange, 
           "green"=>FXColor::Green,
           
           BrickType=>FXColor::Red, 
           OreType=>FXColor::MediumPurple, 
           WheatType=>FXColor::LightYellow,
           WoodType=>FXColor::SandyBrown, 
           SheepType=>FXColor::Green, 
           DesertType=>FXColor::Yellow
          }