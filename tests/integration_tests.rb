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

require 'lib/core/admin'
require 'lib/core/player'
require 'lib/core/bots'
require 'lib/boards/board_impl'
require 'lib/boards/board_manager'
require 'test/unit'
require 'tests/test_utils'
require 'tests/mock_objects'


# Some basic helper methods for the integration tests.
module IntegrationTest
  def on_next_turn(expected_player, params={})
    wait_with_timeout { @a.currentTurn == @lastTurn }
    wait_with_timeout { @a.currentTurn != expected_player.currentTurn }
    wait_with_timeout { @a.currentTurn == nil }
    if params.has_key?(:should_roll)
      die1 = params[:should_roll] / 2
      die2 = params[:should_roll] - die1
      @a.should_roll = [die1, die2]
      @a.currentTurn.roll_dice
    end

    yield @a.currentTurn
    @lastTurn = @a.currentTurn
    @a.currentTurn.done
  end

  def setup
    @b = StandardBoard.new
    @a = MockAdmin.new(@b, 4)
    @p1 = MockPlayer.new("Player1", @a)
    @p2 = MockPlayer.new("Player2", @a)
    @a.register(@p1, @p2)
  end

  # Creates a basic board w/ 2 players
  # each player places 2 roads and 2 settlements
  def use_test_board!
    make_rich(@p1)
    make_rich(@p2)
    @a.start_game
    #Setup
    on_next_turn(@p1) do |turn|
      turn.place_settlement!(0,0,0)
      turn.place_road!(0,0,0)
    end
    #Setup
    on_next_turn(@p2) do |turn|
      assert_equal(SetupTurn, turn.class)
      turn.place_settlement!(-1,0,0)
      turn.place_road!(-1,0,0)
    end
    on_next_turn(@p2) do |turn|
      assert_equal(SetupTurn, turn.class)
      turn.place_settlement!(-1,1,0)
      turn.place_road!(-1,1,0)
    end
    on_next_turn(@p1) do |turn|
      assert_equal(SetupTurn, turn.class)
      turn.place_settlement!(1,0,0)
      turn.place_road!(1,0,0)
    end
    wait_with_timeout{@a.currentTurn == @lastTurn}
  end

end

# Test aspects of a partial game.
# These tests use every aspect of the game, but do not run full games.
class GameTest < Test::Unit::TestCase
  include IntegrationTest

  def initialize(*a)
    super
    @lastTurn = nil
  end

  # Test that the game begins correctly 
  def test_game_start
    @a.start_game
    wait_with_timeout { @a.currentTurn != @p1.currentTurn }
    assert_equal(SetupTurn, @p1.currentTurn.class)
  end

  # Test that each player picks up cards for their 2nd settlement
  def test_game_start_pickup_cards
    @a.start_game
    #Setup
    on_next_turn(@p1) do |turn|
      turn.place_settlement!(0,0,0)
      turn.place_road!(0,0,0)
    end
    #Setup
    on_next_turn(@p2) do |turn|
      turn.place_settlement!(-1,0,0)
      turn.place_road!(-1,0,0)
    end
    p2_resource_hash = nil
    on_next_turn(@p2) do |turn|
      turn.place_settlement!(-1,2,0)
      turn.place_road!(-1,2,0)
      p2_resources = @b.getNode(-1,2,0).hexes.map{|h| h.card_type}
      p2_resource_hash = {}
      p2_resource_hash.default = 0      
      p2_resources.each{|r| p2_resource_hash[r] += 1 unless r == DesertType}
    end
    
    p1_resource_hash = nil
    on_next_turn(@p1) do |turn|
      turn.place_settlement!(1,2,0)
      turn.place_road!(1,2,0)
      p1_resources = @b.getNode(1,2,0).hexes.map{|h| h.card_type}
      p1_resource_hash = {}
      p1_resource_hash.default = 0      
      p1_resources.each{|r| p1_resource_hash[r] += 1 unless r == DesertType}
    end
    
    assert_equal(p1_resource_hash, @p1.cards)
    assert_equal(p2_resource_hash, @p2.cards)    
  end

  # Test that setup turns DO NOT allow normal turn actions
  def test_setup_turn
    @a.start_game
    on_next_turn(@p1) do |turn|
      assert_raise(RuleException){turn.roll_dice}
      assert_raise(RuleException){turn.buy_development_card}
      assert_raise(RuleException){turn.place_city!}
      return
    end
  end
  
  # Test that setup turns force you to add pieces.
  # An error should occur if a user does not place a settlement 
  # AND a road on his turn
  def test_setup_turn__premature_end
    @a.start_game
    on_next_turn(@p1) do |turn|
      assert_raise(RuleException) {turn.done}
      
      turn.place_settlement!(0,0,0)
      assert_raise(RuleException) {turn.done}
      
      turn.place_road!(0,0,0)
      assert_nothing_raised {turn.done}
      return
    end
  end

  def test_place_pieces
    use_test_board!
    on_next_turn(@p1) do |turn|
      turn.roll_dice
      assert_raise(RuleException){ turn.place_road!(0, 0, 0)}
      assert_raise(RuleException){ turn.place_city!(0, 0, 1)}
      assert_raise(RuleException){ turn.place_settlement!(0, 0, 0)}
    end
    on_next_turn(@p2) do |turn|
      make_rich(@p2)
      turn.roll_dice
      assert_raise(RuleException){ turn.place_road!(0, 0, 0) }
      assert_nothing_raised do
        turn.place_road!(-1, 0, 5)
        turn.place_road!(-1, 0, 4)
        turn.place_settlement!(-1, 0, 4)
        turn.place_city!(-1, 0, 4)
      end
    end
  end

  # Tests getting the standard 4:1 quotes from the bank
  # Inherritly, any user can trade resources at a 4:1 ratio on their turn.
  def test_get_quotes_default
    @a.start_game
    on_next_turn(@p1) do |turn|
      make_rich(@p1)
      assert_equal(1, turn.get_quotes([OreType], [WheatType]).length)
      assert_equal(4, turn.get_quotes([OreType], [WheatType])[0].receiveNum)

      #Setup
      turn.place_settlement!(0,0,0)
      turn.place_road!(0,0,0)
      assert_equal(1, turn.get_quotes([OreType], [WheatType]).length)
      assert_equal(4, turn.get_quotes([OreType], [WheatType])[0].receiveNum)
    end
  end

  # Test turn.getquotes
  def test_get_quotes
    make_rich(@p1)
    @b.getTile(1,0).nodes[0].port = Port.new(WheatType)
    @b.getTile(-1,0).nodes[0].port = Port.new(nil, 3)
    @b.getTile(-1,1).nodes[0].port = Port.new(nil, 3)
    @a.start_game
    #Setup
    on_next_turn(@p1) do |turn|
      turn.place_settlement!(0,0,0)
      turn.place_road!(0,0,0)
    end
    on_next_turn(@p2) do |turn|
      turn.place_settlement!(-1,0,0)
      turn.place_road!(-1,0,0)
      make_rich(@p2)
      assert_equal(1, turn.get_quotes([OreType], [WheatType]).length)
      assert_equal(3, turn.get_quotes([OreType], [WheatType])[0].receiveNum)
    end
    on_next_turn(@p2) do |turn|
      turn.place_settlement!(-1,1,0)
      turn.place_road!(-1,1,0)
      assert_equal(1, turn.get_quotes([OreType], [WheatType]).length)
      assert_equal(3, turn.get_quotes([OreType], [WheatType])[0].receiveNum)
    end
    on_next_turn(@p1) do |turn|
      turn.place_settlement!(1,0,0)
      turn.place_road!(1,0,0)
      assert_equal(1, turn.get_quotes([OreType], [WheatType]).length)
      assert_equal(2, turn.get_quotes([OreType], [WheatType])[0].receiveNum)
    end
  end

  # Users should not be allowed to ask for quotes for cards that they don't have
  def test_bad_get_quotes
    use_test_board!
    on_next_turn(@p1) do |turn|
      turn.roll_dice
      @p1.cards = {}
      @p1.cards.default = 0
      assert_raises(RuleException) do turn.get_quotes([OreType], [WheatType]) end
    end
  end
  
  # Roll the dice, and collect some cards for a settlement.
  def test_get_cards_1
    use_test_board!
    @b.tiles.values.each{|t| t.number = 1}
    prev_ore_cards = @p1.cards[OreType]
    @b.getTile(0,0).card_type = OreType
    @b.getTile(0,0).has_bandit = false
    @b.getTile(0,0).number = 10
    turn = @a.currentTurn
    @a.should_roll = [5,5]
    turn.roll_dice
    assert_equal(prev_ore_cards+1, @p1.cards[OreType])
  end

  # Roll the dice, and collect some cards for a settlement.
  def test_get_cards_with_bandit
    use_test_board!
    @b.tiles.values.each{|t| t.number = 1}
    @b.getTile(0,0).card_type = OreType
    @b.getTile(0,0).has_bandit = true
    @b.getTile(0,0).number = 10

    on_next_turn(@p1) do |turn|
      prev_ore_cards = @p1.cards[OreType]
      @a.should_roll = [5,5]
      turn.roll_dice
      assert_equal(prev_ore_cards, @p1.cards[OreType])
    end
  end

  # Roll the dice, and collect some cards for a city.
  # TODO: figure out why this breaks once in a while.
  def test_get_cards_2
    use_test_board!
    @b.tiles.values.each{|t| t.number = 1}
    @b.getTile(0,0).card_type = OreType
    @b.getTile(0,0).has_bandit = false
    @b.getTile(0,0).number = 10

    on_next_turn(@p1) do |turn|
      @a.should_roll = [1,1] #don't roll the ore
      turn.roll_dice
      turn.place_city!(0,0,0)
    end
    on_next_turn(@p2) do |turn|
      @a.should_roll = [1,1] #don't roll the ore
      turn.roll_dice
    end
    on_next_turn(@p1) do |turn|
      @p1.reset_counter(:add_cards)
      prev_ore_cards = @p1.cards[OreType]
      @a.should_roll = [5,5] # ROLL the ore
      turn.roll_dice
      assert_equal(prev_ore_cards+2, @p1.cards[OreType])
      assert_equal(1, @p1.times_called(:add_cards))
    end
  end

  # check that the bandit moves after a 7 is rolled
  def test_roll7_move_bandit
    use_test_board!
    on_next_turn(@p1) do |turn|
      bandit_hex = @b.tiles.values.select{|t| t.has_bandit}.first
      @a.should_roll = [3,4]
      turn.roll_dice
      new_bandit_hex = @b.tiles.values.select{|t| t.has_bandit}.first
      assert_not_equal(new_bandit_hex, bandit_hex)
    end  
  end
  
  # check that you cannot move the bandit to the hex it's already on
  def test_roll7_move_bandit_wrong
    use_test_board!
    on_next_turn(@p1) do |turn|
      bandit_hex = @b.tiles.values.select{|t| t.has_bandit}.first
      @a.should_roll = [3,4]
      @p1.move_bandit_to = bandit_hex
      #The player will try to place the bandit on the old hex
      assert_raise(RuleException) do
        turn.roll_dice
      end
    end  
  end

  # check that everyone loses 1/2 their cards if a 7 is rolled
  def test_roll7_lose_cards
    use_test_board!
    on_next_turn(@p1) do |turn|
      p1_resource_cards = @p1.count_resources
      p2_resource_cards = @p2.count_resources

      @a.should_roll = [3,4]
      turn.roll_dice
      p1_resource_cards_now = @p1.count_resources
      p2_resource_cards_now = @p2.count_resources
      
      assert_equal(p1_resource_cards - (p1_resource_cards / 2), p1_resource_cards_now)
      assert_equal(p2_resource_cards - (p2_resource_cards / 2), p2_resource_cards_now)
    end
  end
  
  # check that you don't lose cards if you have 7 or less
  def test_roll7_lose_cards2
    use_test_board!
    @p1.cards = {SheepType=>8}
    @p2.cards = {BrickType=>7}
    
    on_next_turn(@p1) do |turn|
      @a.should_roll = [3,4]
      turn.roll_dice
      p1_total_resource_cards = @p1.count_resources
      p2_total_resource_cards = @p2.count_resources
      
      assert_equal(4, p1_total_resource_cards)
      assert_equal(7, p2_total_resource_cards)
    end
  end

  #roll a 7 and only discard 2 cards
  def test_roll7_cheat1
    use_test_board!
    @p1.cards = {SheepType=>8}
    @p2.cards = {BrickType=>7}
    
    on_next_turn(@p1) do |turn|
      @a.should_roll = [3,4]
      @p1.select_resources_num = 2 #only discard 2 cards
      assert_raises(RuleException) do
        turn.roll_dice
      end
    end  
  end

  #Roll a 7 and try to discard a LOT of resources
  def test_roll7_cheat2
    use_test_board!
    @p1.cards = {SheepType=>8}
    @p2.cards = {BrickType=>7}
    
    on_next_turn(@p1) do |turn|
      @a.should_roll = [3,4]
      @p1.select_resources_num = 8
      assert_raises(RuleException) do
        turn.roll_dice
      end
    end  
  end

  #Roll a 7 and try to discard nil cards
  def test_roll7_cheat3
    use_test_board!
    on_next_turn(@p1) do |turn|
      @a.should_roll = [3,4]
      @p1.select_nil_resources = true
      assert_raises(RuleException) do
        turn.roll_dice
      end
    end  
  end

  def test_play_soldier
    use_test_board!
    @p1.add_cards([SoldierCard] * 10)
    @p2.add_cards([SoldierCard] * 10)
    p1_card_count = @p1.count_resources
    p2_card_count = @p2.count_resources
    
    on_next_turn(@p1) do |turn|
      @a.should_roll = [0,0]
      turn.roll_dice
      new_tile = @b.tiles.values.sort.find{|t|
        #select a tile that doesn't have the bandit and p2 has a city/settlement on
        has_p2_city = t.nodes.find{|n| n.city.color == @p2.color if n.city}
        has_p1_city = t.nodes.find{|n| n.city.color == @p1.color if n.city}
        !t.has_bandit and has_p2_city and !has_p1_city
      }
      @p1.move_bandit_to = new_tile
      turn.play_development_card!(SoldierCard.new)
      bandit_loc = @b.tiles.values.find{|t| t.has_bandit}
      assert_equal(new_tile, bandit_loc)
    end
    new_p1_card_count = @p1.count_resources
    new_p2_card_count = @p2.count_resources
    #assert that you took a card
    assert_equal(p2_card_count-1, new_p2_card_count)
    assert_equal(p1_card_count+1, new_p1_card_count)
  end

  def test_has_largest_army
    use_test_board!
    @p1.cards[SoldierCard] = 10
    @p2.cards[SoldierCard] = 10
    
    #play 2 soldier cards
    def play_cards(player, num_cards)
      on_next_turn(player) do |turn|
        turn.roll_dice
        (1..num_cards).each do
          turn.play_development_card!(SoldierCard.new)
          #move the bandit
          new_tile = @b.tiles.values.select{|t| !t.has_bandit}.first
          turn.move_bandit(new_tile)
        end
      end
    end
    
    play_cards(@p1, 2)
    assert_equal(2, @a.get_score(@p1))
    assert_equal(2, @a.get_score(@p2))
    assert_equal(nil, @a.who_has_largest_army?)
    play_cards(@p2, 3)
    assert_equal(@p2, @a.who_has_largest_army?)
    assert_equal(2, @a.get_score(@p1))
    assert_equal(4, @a.get_score(@p2))
    play_cards(@p1, 1)
    assert_equal(nil, @a.who_has_largest_army?)
    assert_equal(2, @a.get_score(@p1))
    assert_equal(2, @a.get_score(@p2))

    play_cards(@p2, 0)
    play_cards(@p1, 1)
    assert_equal(@p1, @a.who_has_largest_army?)
    assert_equal(4, @a.get_score(@p1))
    assert_equal(2, @a.get_score(@p2))
  end

  #If you place a city in the middle of your turn, the game should end 
  #right away
  def test_mid_turn_win
    use_test_board!
    @a.maxPoints = 4
    on_next_turn(@p1) do |turn|   
      turn.roll_dice
      spots = @b.get_valid_city_spots(@p1.color)
      turn.place_city!(*(spots[0].coords))
      assert(!@a.is_game_done)
      spots = @b.get_valid_city_spots(@p1.color)
      turn.place_city!(*(spots[0].coords))
      assert_equal(4, @a.get_score(@p1))
      assert_equal(@p1, @a.has_winner?)
      assert(@a.is_game_done)
      assert(@p1.was_called(:game_end))
    end
  end

end

# Full game tests
# These test full game scenarios from start to finish.
class GameScenarios < Test::Unit::TestCase
  include IntegrationTest
  
  def initialize(*a)
    super
    @lastTurn = nil
  end
  
  # Set up a game of 2 random bots
  # Assert that the game finishes
  def test_random_game
    b = StandardBoard.new
    a = Admin.new(b, 4, 7)
    p1 = SinglePurchasePlayer.new("Player1", a)
    p2 = SinglePurchasePlayer.new("Player2", a)
    a.register(p1, p2)
    a.start_game
    until a.is_game_done; end
  end
  
  
  def test_full_game
    @b = StandardBoard.new
    @a = MockAdmin.new(@b, 4, 5)
    @p1 = MockPlayer.new("Player1", @a)
    @p2 = MockPlayer.new("Player2", @a)
    @a.register(@p1, @p2)
    use_test_board!

    make_rich(@p1)
    make_rich(@p2)
    on_next_turn(@p1) do |turn|    
      turn.roll_dice    
      turn.place_road!(1,0,1)
      turn.place_road!(2,1,0)
      turn.place_settlement!(2,1,0)
    end
    assert_equal(2, @a.get_score(@p2))
    assert_equal(3, @a.get_score(@p1))
    on_next_turn(@p2) do |turn| 
      turn.roll_dice 
    end
    on_next_turn(@p1) do |turn| 
      turn.roll_dice
      turn.place_road!(1,0,2)
      turn.place_road!(1,0,3)
      turn.place_city!(2,1,0)
    end
    assert_equal(2, @a.get_score(@p2))
    assert_equal(4, @a.get_score(@p1))
    on_next_turn(@p2) do |turn| 
      turn.roll_dice 
    end
    assert(!@a.is_game_done)
    on_next_turn(@p1) do |turn| 
      turn.roll_dice
      turn.place_road!(1,0,4)
    end
    assert_equal(2, @a.get_score(@p2))
    assert_equal(6, @a.get_score(@p1))
    wait_with_timeout(2){ !@a.is_game_done }
    assert(@a.is_game_done)
  end
  
  #Test the flow of an exact, actual game
  def test_exact_game
    @b = test_board1
    @a = MockAdmin.new(@b, 2, 10)
    @p1 = MockPlayer.new("John", @a)
    @p2 = MockPlayer.new("Lisa", @a)
    john, lisa = @p1, @p2
    @a.register(john, lisa)
    assert_points(john => 0, lisa => 0)
    on_next_turn(john) do |turn|    
      turn.place_settlement!(2,1,0)
      turn.place_road!(2,1,0)
    end
    on_next_turn(lisa) do |turn|    
      turn.place_settlement!(1,1,0)
      turn.place_road!(1,1,0)
    end
    on_next_turn(lisa) do |turn|    
      turn.place_settlement!(-1,1,0)
      turn.place_road!(-1,1,0)
    end
    on_next_turn(john) do |turn|    
      turn.place_settlement!(1,2,0)
      turn.place_road!(1,2,0)
    end
    assert_points(john => 2, lisa => 2)
    on_next_turn(john, :should_roll => 4) do |turn|

      #      orchestrate_trade(lisa, WheatType, 1, OreType, 1) 

    end
    puts "John's score: #{@a.get_score(@p1)}"
    puts "Lisa's score: #{@a.get_score(@p2)}"
    assert_equal(john, @a.has_winner?, "John was supposed to win!")
  end

  private

  #helper function to offer, and accept a trade between the current player and another player
  #[tradingPlayer] is the player offering the quote
  def orchestrate_trade(tradingPlayer, receiveType, receiveAmount, giveType, giveAmount)
    quote = Quote.new(tradingPlayer.info, receiveType, receiveAmount, giveType, giveAmount) 
    tradingPlayer.should_offer = [quote]
    given_quotes = @a.currentTurn.get_quotes([WheatType], [OreType])
    @a.currentTurn.accept_quote(quote)
  end

  #Asserts that each given player has the correct score
  #[players] is a hash of {Player => points}
  def assert_points(players)
    for player, points in players
      assert_equal(points, @a.get_score(player))
    end
  end

end
