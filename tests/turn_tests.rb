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
require 'lib/boards/board_impl'
require 'test/unit'
require 'flexmock'
require 'tests/test_utils'
require 'tests/mock_objects'

#Unit tests for the Turn class
class TurnTest < Test::Unit::TestCase

  def setup
    @board = StandardBoard.new
    @admin = MockAdmin.new(@board, 2)
    @player = MockPlayer.new('player1', @admin)
    
    @player.color = 'red'
    @player.update_board(@board)
    make_rich(@player)
    @turn = Turn.new(@admin, @player, @board)
#    @admin.should_receive(:currentTurn).and_return(@turn)
    @admin.currentTurn = @turn
  end

  def test_roll_dice
    @turn.roll_dice
    assert(@turn.hasRolled)
  end
  
  def test_roll_dice_with_soldier
    card = SoldierCard.new
    @player.cards[card.class] += 1
    @turn.play_development_card!(card)
    assert_nothing_raised { @turn.roll_dice }
    assert(@turn.hasRolled)
  end

  def test_buy_development_card
#    @admin.should_receive(:buy_development_card).once
    assert_raises(RuleException){ @turn.buy_development_card}
    @turn.roll_dice
    cards = @player.cards.dup
    card = nil
    assert_nothing_raised{ 
      card = @turn.buy_development_card
    }
    assert_equal(cards[OreType]-1, @player.cards[OreType])
    assert_equal(cards[WheatType]-1, @player.cards[WheatType])
    assert_equal(cards[SheepType]-1, @player.cards[SheepType])
    assert_equal(1, @player.cards[card.class])
  end

  def test_get_quotes
    assert_raises(RuleException){ @turn.get_quotes([BrickType], [OreType])}
    @turn.roll_dice
    assert_nothing_raised{ 
      @turn.get_quotes([BrickType], [OreType])
    }
  end

  def test_get_quotes_from_bank
    assert_raises(RuleException){ 
      @turn.get_quotes_from_bank(BrickType, OreType)
    }
    @turn.roll_dice
    assert_nothing_raised{ 
      @turn.get_quotes_from_bank(BrickType, OreType)
    }
  end

  def test_accept_quote
    assert_raises(RuleException){ @turn.accept_quote(nil)}
    @turn.roll_dice
    # Haven't recieved any quotes yet
    assert_raises(RuleException){ @turn.accept_quote(nil)}
  end

  def test_place_road
    @board.getNode(0,0,0).city = Settlement.new('red')
    assert_raises(RuleException){ @turn.place_road!(0,0,0)}
    @turn.roll_dice
    assert_nothing_raised{ @turn.place_road!(0,0,0) }
  end

  #This test makes sure that placing a road is a transaction
  #Nothing should be affected if the player cannot but a piece
  def test_place_road_cannot_afford
    #make the player have not enough cards
    @player.cards[WoodType] = 0
    @board.getNode(0,0,0).city = Settlement.new('red')
    @admin.should_roll = [5,5]
    @turn.roll_dice
    num_of_roads = @player.piecesLeft(Road)
    cards = @player.cards.dup
    assert_raises(RuleException){ @turn.place_road!(0,0,0) }
    assert_equal(num_of_roads, 
                 @player.piecesLeft(Road), 
                 "piecesLeft decreased during transaction")
    assert_equal(cards, @player.cards)
  end

  def test_place_settlement
    @board.getEdge(0,0,1).road = Road.new('red')
    assert_raises(RuleException){ @turn.place_settlement!(0,0,0)}
    @turn.roll_dice
    assert_nothing_raised{ @turn.place_settlement!(0,0,0) }
  end
  
  #This test makes sure that placing a settlement is a transaction
  #Nothing should be affected if the player cannot but a piece
  def test_place_settlement_cannot_afford
    #make the player have not enough cards
    @player.cards[WheatType] = 0
    @board.getEdge(0,0,1).road = Road.new('red')
    @turn.roll_dice
    num_of_pieces = @player.piecesLeft(Settlement)
    cards = @player.cards.dup
    assert_raises(RuleException){ @turn.place_settlement!(0,0,0) }
    assert_equal(num_of_pieces,
                 @player.piecesLeft(Settlement), 
                 "piecesLeft decreased during transaction")
    assert_equal(cards, @player.cards)
  end
  
  def test_place_city
    @board.getNode(0,0,0).city = Settlement.new('red')
    assert_raises(RuleException){ @turn.place_city!(0,0,0)}
    @turn.roll_dice
    assert_nothing_raised{ @turn.place_city!(0,0,0) }
  end

  #This test makes sure that placing a city is a transaction
  #Nothing should be affected if the player cannot but a piece
  def test_place_city_cannot_afford
    #make the player have not enough cards
    @player.cards[OreType] = 2
    @board.getNode(0,0,0).city = Settlement.new('red')
    @turn.roll_dice
    num_of_pieces = @player.piecesLeft(City)
    cards = @player.cards.dup
    assert_raises(RuleException){ @turn.place_city!(0,0,0) }
    assert_equal(num_of_pieces,
                 @player.piecesLeft(City), 
                 "piecesLeft decreased during transaction")
    assert_equal(cards, @player.cards)
  end

  def test_done
    assert_raises(RuleException){ @turn.done}
    @turn.roll_dice
    @turn.done
    assert_raises(RuleException){ @turn.done}
  end
  
  def test_play_development_card
    card = MockCard.new
    assert_raises(RuleException){ @turn.play_development_card!(card)}
    @turn.player.add_cards([card.class])
    assert_raises(RuleException){ @turn.play_development_card!(card)}
    @turn.roll_dice
    assert(!card.was_used)
    @turn.play_development_card!(card)
    assert(card.was_used)
  end

  def test_play_development_card_soldier
    card = SoldierCard.new
    @turn.player.add_cards([card.class])
    dev_card_count = @turn.player.cards[SoldierCard]
    assert_equal(1, dev_card_count)
    assert_equal(0, @turn.active_cards.size)
    assert_nothing_raised(RuleException){ @turn.play_development_card!(card)}
    assert_equal(0, @turn.active_cards.size)
    dev_card_count = @turn.player.cards[SoldierCard]
    assert_equal(0, dev_card_count)
  end

  def test_play_development_card_resource_monopoly
    card = ResourceMonopolyCard.new
    @turn.player.add_cards([card.class])
    dev_card_count = @turn.player.cards[ResourceMonopolyCard]
    assert_equal(1, dev_card_count)
    assert_equal(0, @turn.active_cards.size)
    assert_raises(RuleException){ @turn.play_development_card!(card)}
    @turn.roll_dice
    assert_nothing_raised(RuleException){ @turn.play_development_card!(card)}
    assert_equal(0, @turn.active_cards.size)
    dev_card_count = @turn.player.cards[ResourceMonopolyCard]
    assert_equal(0, dev_card_count)
  end

  def test_play_development_card_road_builder
    card = RoadBuildingCard.new
    @turn.player.add_cards([card.class])
    assert_equal(0, @turn.active_cards.size)
    assert_raises(RuleException){ @turn.play_development_card!(card)}
    @turn.roll_dice
    assert_nothing_raised{ @turn.play_development_card!(card)}
    assert_equal(2, @player.purchased_pieces)
    assert_equal(0, @turn.active_cards.size)
    
    #place each of the roads
    @board.getNode(1,1,1).city = Settlement.new(@player.color)
    spots = @board.get_valid_road_spots(@player.color)
    @turn.place_road!(*spots[0].coords)
    assert_equal(1, @player.purchased_pieces)

    spots = @board.get_valid_road_spots(@player.color)
    @turn.place_road!(*spots[0].coords)
    assert_equal(0, @player.purchased_pieces)
  end
  
  #Try to end the turn before you've placed all the roads
  def test_play_development_card_road_builder_cheat
    card = RoadBuildingCard.new
    @turn.player.add_cards([card.class])
    @turn.roll_dice
    @turn.play_development_card!(card)
    
    #place each of the roads
    @board.getNode(1,1,1).city = Settlement.new(@player.color)
    spots = @board.get_valid_road_spots(@player.color)
    assert_raises(RuleException) do @turn.done end
    @turn.place_road!(*spots[0].coords)

    assert_raises(RuleException) do @turn.done end
  end
  
  def test_play_development_card_year_of_plenty
    card = YearOfPlentyCard.new
    @turn.player.add_cards([card.class])
    assert_equal(0, @turn.active_cards.size)
    player_card_count = @player.cards.values.sum
    assert_raises(RuleException){ @turn.play_development_card!(card)}
    
    #Make sure that the player has the same # of cards
    assert_equal(player_card_count, @player.cards.values.sum)
    @turn.roll_dice
    assert_nothing_raised{ @turn.play_development_card!(card)}
    #Make sure that the player got 2 more cards
    assert_equal(0, @turn.active_cards.size)
  end

  # a helper method to count the number of tiles with the bandit.
  def count_bandit
    total = 0
    @board.tiles.values.each{ |tile| 
      total += 1 if tile.has_bandit
    }
    total
  end

  def test_move_bandit
    assert_equal(1, count_bandit)
        
    #Play a soldier card
    card = SoldierCard.new
    @turn.player.add_cards([card.class])
    @turn.play_development_card!(card)
    assert_equal(1, count_bandit)
    
    @admin.should_roll = [3,4]
    @turn.roll_dice
    assert_equal(1, count_bandit)
  end

  def helper_test_active_card(card)
    assert_equal(0, @turn.active_cards.size)
    @turn.player.add_cards([card.class])
    @turn.play_development_card!(card)
    assert_equal(1, @turn.active_cards.size)
    yield
    assert_equal(0, @turn.active_cards.size)
  end
end


class MockCard < DevelopmentCard
  attr_reader :was_used
  def use(turn)
    @was_used = true
  end
end
