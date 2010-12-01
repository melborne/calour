#-*-encoding: utf-8-*-
require 'tempfile'
require 'termcolor'
require "open-uri"
require "nokogiri"

class Calour
  WD = %w(January February March April May June July August September October November December)
  attr_accessor :colors

  def initialize(opts={})
    @colors = {title: [:green,:yellow], today: :green, saturday: :cyan, sunday: :magenta, :holiday => :red}
    opts.keep_if { |k, v| colors.keys.include? k }
    colors.update(opts)
  end

  def cal(*args)
    @month, @year = parse_argument(args)
    rdtout, rdterr = redirect_system_out { "cal #{@month} #{@year}" }
    @calendar, err = [rdtout, rdterr].map { |io| io.open.read }
    raise ArgumentError, err unless err.empty?
    colorize_calendar
  ensure
    [rdtout, rdterr].map { |io| io.close if io }
  end
  
  private
  def parse_argument(args)
    mon, year = args.sort
    if mon.nil? && year.nil?
      mon, year = Time.now.mon, Time.now.year
    elsif year.nil?
      if mon >= 100
        mon, year = year, mon
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
    @calendar =
      @calendar.lines.inject("") do |mem, line|
        line =
          case line
          when title? then colorize_title(line, *colors[:title])
          when year?  then colorize_year[line, colors[:title][1]]
          when dates? then colorize_weekend(line, :sunday => 0, :saturday => 18)
          else line
          end
        mem << line
      end
    colorize_specific_days(today)
    colorize_specific_days(holidays)
    @calendar.termcolor
  end

  def title?
    ->l{ l =~ /#{WD.join("|")}/ }
  end
  
  def year?
    ->l{ l =~ /\d{4}/ }
  end

  def dates?
    ->l{ l =~ /^\s*\d{1,2}\D/ }
  end

  def colorize_title(line, wd, year)
    line = line.gsub(/(#{WD.join("|")})/) { "<#{wd}>#{$&}</#{wd}>" }
    colorize_year[line, year]
  end

  def colorize_year
    ->line, year { line.gsub(/\d{4}/) { "<#{year}>#{$&}</#{year}>"} }
  end

  def colorize_weekend(line, opts)
    opts = opts.sort_by { |_, v| -v }
    2.downto(0) do |i|
      opts.each { |wd, offset|
        pos = UNIT_WIDTH()*i+offset
        (line[pos, 2] = "<#{colors[wd]}>#{line[pos, 2]}</#{colors[wd]}>") rescue nil
      }
    end
    line
  end

  def UNIT_WIDTH
    22
  end

  def today
    { Time.now => :today }
  end
  
  def holidays
    parse_xml_to_hash(get_holidays)
  end

  def colorize_specific_days(targets)
    color, on = set_color_mode(targets)

    if @month.nil?
      targets.each do |date, name|
        mon = WD[date.mon-1]
        start, side = false, nil
        @calendar =
          @calendar.lines.inject("") do |mem, line|
            if mpos = line.index(mon) # set a position of target month title
              side = detect_target_column(mpos, line) # select target column from mpos
              start = true
            end
            
            # find a target date position in the target column
            # for lines after month title
            if start
              left, right = calc_range(side, line)
              pos = line.index(/(?<=\D)#{date.day}\D/, left)
              if pos && pos < right
                line[pos, date.day.to_s.size] = 
                          "<#{on}#{color}>#{date.day}</#{on}#{color}>"
                start, side = false, nil
              end
            end
            mem << line
          end
      end
    else
      targets.each do |date, name|
        next unless date.mon == @month
        day = date.day
        pos = @calendar.index(/(?<=\D)#{day}\D/)
        @calendar[pos, day.to_s.size] =
            "<#{on}#{color}>#{day}</#{on}#{color}>"
      end
    end
    @calendar
  end

  def set_color_mode(targets)
    if targets.values.include?(:today)
      [colors[:today], 'on_']
    else
      colors[:holiday]
    end
  end

  def detect_target_column(pos, line)
    unit = line.size / 3
    case pos
    when 0...unit then return :left
    when unit...unit*2 then return :center
    else return :right
    end
  end
  
  def calc_range(side, line)
    unit = line.size / 3
    case side
    when :left then return 0, unit
    when :center then return unit, unit*2
    else return unit*2, unit*3
    end
  end

  # use Google Calendar Data API
  def get_holidays #TODO: use local db for keeping data
    open URL() + PARAM(*build_date_range)
  end

  def URL
    "http://www.google.com/calendar/feeds" +
                "/japanese@holiday.calendar.google.com/public/full?"
  end

  def PARAM(sd, ed)
    "start-min=#{sd}&start-max=#{ed}"
  end

  def build_date_range
    st, ed = @month ? [format("%02d", @month)] * 2 : ["01", "12"]
    return "#{@year}-#{st}-01", "#{@year}-#{ed}-31"
  end

  def parse_xml_to_hash(xml)
    data = Nokogiri::HTML(xml)
    h = {}
    data.css("entry").each do |node|
      date = node.css("gd", "when").attr("starttime").value
      h[Time.parse date] = node.css("title").text
    end
    h
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