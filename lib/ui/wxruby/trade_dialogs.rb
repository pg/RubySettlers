module CommonTradeFunctions
  
  def main_frame
    RealMainFrame.instance
  end

  def show(*a)
    result = super
    clear
    result
  end
  
  def on_chat
    if @chat_input_text.value and @chat_input_text.value.size > 0
      main_frame.human_player.admin.chat_msg(main_frame.human_player, @chat_input_text.value)
      @chat_input_text.value = ''
    end
  end
end

# This is the dialog where you can offer a trade to other players
class RealTradeDialog < TradeDialog
  include CommonTradeFunctions

  def initialize(*a)
    super(*a)
    evt_button(@chat_send_button, :on_chat)
    evt_button(@quote_request_button, :on_request_quote)
    evt_button(@quote_accept_button, :on_accept_quote)
    evt_text_enter(@chat_input_text, :on_chat)
    @give_checkboxes = {@wood_give_check => WoodType, @wheat_give_check => WheatType, @ore_give_check => OreType, 
                        @brick_give_check => BrickType, @sheep_give_check => SheepType}
    @want_checkboxes = {@wood_want_check => WoodType, @wheat_want_check => WheatType, @ore_want_check => OreType, 
                        @brick_want_check => BrickType, @sheep_want_check => SheepType}
  end

  def on_request_quote(event)
    @quote_list.clear
    give_resources = @give_checkboxes.map{|cb, type| type if cb.value}.compact
    want_resources = @want_checkboxes.map{|cb, type| type if cb.value}.compact
    @recent_quotes = main_frame.human_player.currentTurn.get_quotes(want_resources, give_resources)
    if @recent_quotes.empty?
      @quote_list.append('No Quotes', nil)
    else
      for quote in @recent_quotes
        name = quote.bidder ? quote.bidder.name : "The Bank"
        give_name = main_frame.get_resource_alias(quote.giveType)
        receive_name = main_frame.get_resource_alias(quote.receiveType)
        @quote_list.append("#{name} will give you #{quote.giveNum} #{give_name} for #{quote.receiveNum} #{receive_name}", quote)
      end
    end
  end

  def on_accept_quote(event)
    #TODO: Need to re-work this, right now, the control lets you select several quotes at once,
    #I can't handle the logic for this just yet ... 
    # I think i need logic to check that you have enough cards to accept multiple quotes, otherwise, don't let the user accept so many quotes
    selections = @quote_list.get_selections
    if selections.empty?
      return unless @quote_list.get_count == 1
      quote = @quote_list.get_item_data(0)
    else
      quote = @quote_list.get_item_data(selections[0])
    end
    main_frame.human_player.currentTurn.accept_quote(quote) if quote
    clear
  end

  def validate
    @give_checkboxes.each{|cb, type| 
      if main_frame.human_player.cards[type] > 0
        cb.enable
      else
        cb.disable
      end
    }
  end

  def clear
    validate
    @quote_list.clear
    @give_checkboxes.each{|cb, type| cb.value = false }
    @want_checkboxes.each{|cb, type| cb.value = false }
  end

end


# This is the dialog where you accept/reject other people's offers
class RealOfferTradeDialog < MakeTradeOfferDialog
  include CommonTradeFunctions
  attr_reader :quotes
  
  def initialize(main_frame)
    super
    evt_button(@chat_send_button, :on_chat)
    evt_button(Wx::ID_CANCEL, :on_reject)
    evt_button(@make_offer_button, :on_make_offer)
    evt_text_enter(@chat_input_text, :on_chat)
    @give_checkboxes = {@wood_give_spinner => WoodType, @wheat_give_spinner => WheatType, @ore_give_spinner => OreType, 
                        @brick_give_spinner => BrickType, @sheep_give_spinner => SheepType}
    @want_checkboxes = {@wood_want_spinner => WoodType, @wheat_want_spinner => WheatType, @ore_want_spinner => OreType, 
                        @brick_want_spinner => BrickType, @sheep_want_spinner => SheepType}
    @quotes = nil
  end

  def clear
    validate
    @quotes = nil
    @give_checkboxes.each{|cb, type| cb.value = 0 }
    @want_checkboxes.each{|cb, type| cb.value = 0 }
  end
  
  def on_reject
    @quotes = []
  end
  
  def on_make_offer(event)
    give = @give_checkboxes.find{|spinner, type| spinner.value > 0 }
    want = @want_checkboxes.find{|spinner, type| spinner.value > 0 }
    if give and want
      @quotes = [Quote.new(main_frame.human_player, want[1], want[0].value, give[1], give[0].value)]
    else
      @quotes = []
    end
    puts self
  end

  def display(want, give)
    clear
    want = want.uniq.map{|r| RealMainFrame.instance.get_resource_alias(r) }.join(', ').downcase
    give = give.uniq.map{|r| RealMainFrame.instance.get_resource_alias(r) }.join(', ').downcase
    player = RealMainFrame.instance.admin.currentTurn.player
    
    @notice_text.set_font(Wx::Font.new(16, Wx::FONTFAMILY_DEFAULT, Wx::FONTSTYLE_NORMAL, Wx::FONTWEIGHT_NORMAL))
    @notice_text.clear
    @notice_text.append_text "#{player.name} is looking for #{want} and is offering #{give}"
    self.layout
    self.update
    self.refresh
    self.show(true)
  end

  def validate
    @give_checkboxes.each{|spinner, type|
      spinner.set_range(0,[3, main_frame.human_player.cards[type]].min)
      if spinner.get_max == 0
        spinner.disable
      else
        spinner.enable
      end
    }
    @want_checkboxes.each{|spinner, type|
      spinner.set_range(0,3)
    }
  end

end