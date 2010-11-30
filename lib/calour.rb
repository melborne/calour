#-*-encoding: utf-8-*-
require 'tempfile'
require 'termcolor'
autoload :Date, 'date'

class Calour
  WD = %w(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec)
  attr_accessor :colors

  def initialize(opts={})
    @colors = {title: [:green,:yellow], today: :green, saturday: :cyan, sunday: :magenta}
    opts.keep_if { |k, v| colors.keys.include? k }
    colors.update(opts)
  end

  def cal(*args)
    @mon, @year = parse_argument(args)
    rdtout, rdterr = redirect_system_out { "cal #{@mon} #{@year}" }
    @calendar, err = [rdtout, rdterr].map { |io| io.open.read }
    raise ArgumentError, err unless err.empty?
    colorize_calendar
  ensure
    [rdtout, rdterr].map { |io| io.close if io }
  end

  
  private
  def parse_argument(args)
    mon, year = args.sort
    if !mon.nil? && year.nil?
      if mon >= 100
        year, mon = mon, year
      else
        year = Time.now.year
      end
    end
    return mon, year
  end

  def redirect_system_out
    stdout, stderr = [STDOUT, STDERR].map(&:dup)
    rdtout, rdterr = ["temp_std", "temp_err"].map { |f| Tempfile.open f }
    STDOUT.reopen(rdtout); STDERR.reopen(rdterr)
    system yield
    STDOUT.flush; STDERR.flush
    STDOUT.reopen(stdout); STDERR.reopen(stderr)
    return rdtout, rdterr
  end

  def colorize_calendar
    colorize_weekend(:sunday => 0, :saturday => 18) # this colorize must be first.
    colorize_today
    colorize_title
    colorize_holiday
    @calendar.termcolor
  end

  def colorize_title
    wd, year = colors[:title]
    @calendar =
      @calendar.lines.inject("") do |cal, line|
        if title_line?(line) || year_line?(line)
          line.gsub!(/(#{WD.join("|")})\w*(?=\b)/) { "<#{wd}>#{$&}</#{wd}>" }
          line.gsub!(/\d{4}/) { "<#{year}>#{$&}</#{year}>"}
        end
        cal << line
      end
  end

  def title_line?(line)
    line =~ /#{WD.join("|")}/
  end
  
  def year_line?(line)
    line =~ /\b\d{4}\b/
  end
  
  def colorize_weekend(opts)
    unit_width = 22
    opts = opts.sort_by { |_, v| -v }
    @calendar =
      @calendar.lines.inject("") do |cal, line|
        unless title_line?(line) || line =~ /^\n$/
          2.downto(0) { |i|
            opts.each do |wd, offset|
              pos = unit_width*i+offset
              (line[pos, 2] = \
                  "<#{colors[wd]}>#{line[pos, 2]}</#{colors[wd]}>") rescue nil
            end
          }
        end
        cal << line
      end
  end

  def colorize_today
    t = Time.now
    if [/#{t.year}/, /#{t.strftime("%b")}/].all? { |e| @calendar =~ e }
      n = @year ? count_nth(t) : 1
      pos = -1
      n.times { pos = @calendar.index(/#{t.day}/, pos+1) }
      @calendar[pos, 2] = "<on_#{colors[:today]}>#{t.day}</on_#{colors[:today]}>"
    end
    @calendar
  end

  # calculate position of the target date in a yearly calendar
  def count_nth(date)
    mindex = ->obj{ obj.index(date.mon).next  }
    case date.day
    when 31
      mindex.call [1,3,6,8,12]
    when 30
      mindex.call (1..12).to_a - [2]
    when 29
      Date.new(date.year).leap? ? mindex.call((1..12).to_a - [2]) : date.mon
    else
      date.mon
    end
  end
  
  @@url = "http://www.google.com/calendar/feeds/
                japanese@holiday.calendar.google.com/public/full?"

  def colorize_holiday
    
  end
end

__END__
http://www.google.com/calendar/feeds/
japanese@holiday.calendar.google.com/public/full
?start-min=2007-01-01&start-max=2008-01-01

−1      一つの月だけを出力する (これがデフォルトである)。

  −3      先月/今月/来月 形式で出力する。

  −s      日曜日を週の最初の曜日にする (これがデフォルトである)。

  −m      月曜日を週の最初の曜日にする。

  −j      ユリウス日付 (1 月 1 日を第 1 日とする年間通算日) を表示する。

  −y      今年のカレンダーを表示する。