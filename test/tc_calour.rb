#-*-encoding: utf-8-*-
require "test/unit"

require_relative "../lib/calour"

class TestCal < Test::Unit::TestCase
  def setup
    @c = Calour.new
    @t = Time.now
    @holidays2011 = [[1, 1], [1, 10], [2, 11], [3, 21], [4, 29], [5, 3], [5, 4], [5, 5], [7, 18], [9, 19], [9, 23], [10, 10], [11, 3], [11, 23], [12, 23]]
  end

  def test_argument_variation
    assert_match(/Oct.*2012/, @c.cal(10, 2012))
    assert_match(/Feb.*1980/, @c.cal(1980, 2))
    assert_match(/Jul.*2200/, @c.cal(2200, 07))
    assert_match(/Dec.*2010/, @c.cal())
    assert_match(/May.*2010/, @c.cal(5))
    assert_match(/1800/, @c.cal(1800))
    assert_match(/2010/, @c.cal(2010))
  end
  
  def test_argument_error
    assert_raise(ArgumentError) { @c.cal(45) }
    assert_raise(ArgumentError) { @c.cal(13, 2000) }
    assert_raise(ArgumentError) { @c.cal(:hello) }
  end
  
  def test_initialize_opts
    c = Calour.new(:hello => :orange, :title => :blue)
    expected = {:title=>:blue, :today=>:green, :saturday=>:cyan, :sunday=>:magenta, :holiday => :red}
    assert_equal(expected, c.colors)
  end
  
  def test_color_today
    c = Calour.new(:today => :blue)
    assert_match(/\e\[42m#{@t.day}\e\[0m/, @c.cal)
    assert_match(/\e\[44m#{@t.day}\e\[0m/, c.cal)
  end
  
  def test_color_weekend
    sat = @t.day % 7 + (6 - @t.wday)
    sun = @t.day % 7 + (7 - @t.wday)
    assert_match(/\e\[36m #{sat}\e\[0m/, @c.cal)
    assert_match(/\e\[35m #{sun}\e\[0m/, @c.cal)
  end
  
  def test_color_title
    month = @t.strftime("%B")
    assert_match(/\e\[32m#{month}\e\[0m/, @c.cal)
    assert_match(/\e\[32mAugust\e\[0m/, @c.cal(8, 2000))
  end
  
  def test_color_specific_days_for_monthly_calendar
    c = Calour.new(holiday_opt: {country: :ja_ja})
    assert_match(/\e\[42m#{@t.day}\e\[0m/, c.cal)
    @holidays2011.each do |mon, day|
      assert_match(/\e\[31m#{day}\e\[0m/, c.cal(mon, 2011))
    end
  end

  def test_color_specific_days_for_yearly_calendar
    puts @c.cal(2011)
    puts @c.cal()
  end

  def test_holiday_option
    puts Calour.new(holiday_opt: {country: :ja}).cal
    puts Calour.new(holiday_opt: {country: :us, verbose:true}).cal
    puts Calour.new(holiday_opt: {country: :au, verbose:true}).cal(2012)
    puts Calour.new(holiday_opt: {country: :ja_ja, verbose:true}).cal(5, 2013)
  end
end
