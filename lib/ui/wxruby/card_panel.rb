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

module CardPanel
  CARD_FILES = {BrickType=>'brick_resource.jpg',
                WoodType=>'wood_resource.jpg',
                OreType=>'ore_resource.jpg',
                SheepType=>'sheep_resource.jpg',
                WheatType=>'wheat_resource.jpg'}
                
  IMAGE_DIR = 'lib/img/'
  CARD_IMAGE_BUFFER = 5

  def self.get_card_images
    @@average_width = 0
    card_images = {}
    for klass, file in CARD_FILES
      bitmap = Wx::Bitmap.new
      bitmap.load_file(IMAGE_DIR + file, Wx::BITMAP_TYPE_JPEG)
      card_images[klass] = bitmap
      @@average_width += bitmap.get_width
    end
    @@average_width /= CARD_FILES.keys.size  
    card_images
  end

  def init_icons
    @@card_images = CardPanel.get_card_images
  end
  
  def paint_dc(paint_event)
    self.paint_buffered do |dc|
      init_icons unless defined?(@@card_images)
      cards = sorted_resource_cards
      dc.set_background($dark_blue_brush)
      dc.clear
      if cards.size > 0
        width = dc.get_size.get_width - (CARD_IMAGE_BUFFER * 2)
        y = (dc.get_size.get_height - @@card_images.values[0].get_height) / 2
        increment = [(width / (cards.size+1)), @@average_width + CARD_IMAGE_BUFFER].min 
        cards.each_with_index do |cardKlass, i|
          dc.draw_bitmap(@@card_images[cardKlass], (increment * i) + CARD_IMAGE_BUFFER, y, false)
        end
      end
    end
  end
  
  #returns a list of resource card classes 
  def sorted_resource_cards
    result = []
    if player 
      RESOURCE_TYPES.each{|r|    
        count = player.cards[r]
        result += [r] * count
      }
    end
    result  
  end
  
  def player
    mf = RealMainFrame.instance
    mf.human_player
  end

end