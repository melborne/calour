require "test/unit"

require_relative "../lib/calour"

class TestCal < Test::Unit::TestCase
  def setup
    @c = Calour.new
  end

  def test_argument_variation
    assert_match(/Oct.*2012/, @c.cal(10, 2012))
    assert_match(/Feb.*1980/, @c.cal(1980, 2))
    assert_match(/Jul.*2200/, @c.cal(2200, 07))
    assert_match(/Nov.*2010/, @c.cal())
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
    expected = {:title=>:blue, :today=>:green, :saturday=>:cyan, :sunday=>:magenta}
    assert_equal(expected, c.colors)
  end
end