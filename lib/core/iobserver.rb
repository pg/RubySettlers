

#Observer interface to watch the game.
#Every player must implement this so they can monitor game events.
module IObserver

  #This is called by the admin anytime any player recieves cards.
  #[player] the player that recieved the cards
  #[cards] a list of Card Classes
  def player_received_cards(player, cards)
    raise 'Not Implemented'
  end
  
  #This is called by the admin when anyone rolls the dice
  #[player] the acting player
  #[roll] A list (length 2) of the numbers that were rolled
  def player_rolled(player, roll)
    raise 'Not Implemented'  
  end

  #This is called by the admin whenever a player steals cards from another player
  #[theif] the player who took the cards
  #[victim] the player who lost cards
  def player_stole_card(theif, victim, num_cards)
    raise 'Not Implemented'  
  end

  #Notify the observer that the game has begun  
  def game_start
    raise 'Not Implemented'  
  end
  
  #Inform the observer that the game has finished.
  #[player] the player who won
  #[points] the number of points they won with.
  def game_end(winner, points)
    raise 'Not Implemented'
  end
  
  #Inform this observer that a player has joined the game.
  def player_joined(player)
    raise 'Not Implemented'  
  end
  
  #Inform this observer that it is the given player's turn
  # (PlayerInfo, TurnClass) => nil
  def get_turn(player, turn_class)
    raise 'Not Implemented'  
  end
  
  # Update this observer's version of the board
  # [board] the new version of the board
  def update_board(board)
    raise 'Not Implemented'
  end

  #This is called by the admin anytime another player moves the bandit
  #[player] the player that moved the bandit
  #[new_hex] the hex that the bandit is now on.
  def player_moved_bandit(player, new_hex)
    raise 'Not Implemented'    
  end

  # Notify this observer that a road was placed
  # [player] The player that placed the road
  # [x, y, edge] The edge coordinates
  def placed_road(player, x, y, edge)
    raise 'Not Implemented'
  end

  # Notify this observer that a settlement was placed
  # [player] The player that placed the settlement
  # [x, y, node] The node coordinates
  def placed_settlement(player, x, y, node)
    raise 'Not Implemented'
  end

  # Notify this observer that a city was placed
  # [player] The player that placed the city
  # [x, y, node] The node coordinates
  def placed_city(player, x, y, node)
    raise 'Not Implemented'
  end 
end
