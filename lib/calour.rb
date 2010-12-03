#-*-encoding: utf-8-*-
%w(tempfile termcolor open-uri nokogiri cgi).each { |lib| require lib }

class Calour
  WD = %w(January February March April May June July August September October November December)
  attr_accessor :colors, :holiday_opt

  def initialize(opts={})
    @holiday_opt = {country: false, verbose: false}
    if hopt = opts.delete(:holiday_opt)
      holiday_opt.update(hopt)
    end
    @colors = {title: [:green,:yellow], today: :green, saturday: :cyan, sunday: :magenta, holiday: :red}
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
    if COUNTRY_ID(holiday_opt[:country])
      colorize_specific_days(ho=holidays)
      print_holiday_titles(ho) if holiday_opt[:verbose]
    end
    @calendar.termcolor
  end

  def title?
    /#{WD.join("|")}/
  end
  
  def year?
    /\d{4}/
  end

  def dates?
    /^\s*\d{1,2}\D/
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
      colorize_year_calendar(targets, color, on)
    else
      colorize_month_calendar(targets, color, on)
    end
    @calendar
  end

  def colorize_year_calendar(targets, color, on)
    targets.each do |date, name|
      next if name == :today && @year != date.year
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
  end

  def colorize_month_calendar(targets, color, on)
    targets.each do |date, name|
      next unless date.mon == @month
      day = date.day
      pos = @calendar.index(/(?<=\D)#{day}\D/)
      @calendar[pos, day.to_s.size] = "<#{on}#{color}>#{day}</#{on}#{color}>"
    end
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

  def print_holiday_titles(ho)
    ho.sort_by { |date, _| date }
      .each_with_object(@calendar).with_index do |((date, name), mem), i|
          d = date.strftime("%b%e")
          c1, c2 = colors[:title]
          mem << "<#{c2}>#{d}</#{c2}>: <#{c1}>#{name}</#{c1}> "
          mem << "\n" if (i.next%3).zero? || !@month.nil?
       end
  end

  # use Google Calendar Data API
  def get_holidays #TODO: use local db for keeping data
    open URL(holiday_opt[:country]) + PARAM(*build_date_range)
  rescue => e
    STDERR.puts "Failed to retrieve Holiday data by Google Calendar Data API. #{e}"
  end

  def URL(country)
    "http://www.google.com/calendar/feeds/" +
            CGI.escape("#{COUNTRY_ID(country)}") + "/public/full-noattendees?"
  end

  def COUNTRY_ID(country)
    base1 = "@holiday.calendar.google.com"
    base2 = "#holiday@group.v.calendar.google.com"
    {
      ja: "japanese#{base1}",
      us: "usa__en#{base1}",
      au: "australian__en#{base1}",
      ja_ja: "ja.japanese#{base2}",
      cn: "en.china#{base2}",
      fr: "en.french#{base2}",
      de: "en.german#{base2}",
      it: "en.italian#{base2}",
      kr: "en.south_korea#{base2}",
      tw: "en.taiwan#{base2}",
      gb: "en.uk#{base2}"
     }[country]
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
