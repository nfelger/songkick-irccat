#!/usr/bin/env ruby

require 'rubygems'
require 'redis'
require 'open-uri'
require 'json'
require 'cgi'

class Store
  class << self
    def incr(name)
      counter_key = key(name)
      r.incr(counter_key)
    end

    def get(name)
      counter_key = key(name)
      r.get(counter_key)
    end

    def add_to_list(name, additions)
      list_key = key(name)
      additions.each do |addition|
        r.rpush(list_key, addition)
      end
    end
    
    def get_list(name)
      list_key = key(name)
      r.lrange(list_key, 0, -1)      
    end

    private
    
    def r
      @r ||= begin
        redis = Redis.new
        redis.select(1)
        redis
      end
    end

    def key(name)
      name + '-' + today
    end

    def today
      Date.today.strftime('%F')
    end
  end
end

class Counter
  def initialize(name)
    @name = name
  end

  def run
    Store.incr(@name)
    puts "#{Store.get(@name)} #{@name}(s) today"  
  end
end

class ListAdd
  def initialize(name, additions)
    @name = name
    @additions = additions
  end

  def run
    Store.add_to_list(@name, @additions)
    puts "#{@name}: #{Store.get_list(@name).join(', ')}"
  end
end

class ListGet
  def initialize(name)
    @name = name
  end

  def run
    puts "#{@name}: #{Store.get_list(@name).join(', ')}"
  end
end

class ApiCurl
  def initialize(url_pattern, query, &parse)
    @url_pattern = url_pattern
    @query       = query
    @parse       = parse
  end

  def run
    puts parse
  end

  private

  def parse
    @parse.call(get)
  end

  def get
    open(interpolated_url) { |io| io.read }
  end

  def interpolated_url
    @url_pattern.sub('_-#QUERY#-_', CGI.escape(@query))
  end
end

class RandomAnswer
  def run
    puts answers.shuffle.first
  end
  
  private

  def answers
    ['huh?', 
     "maybe later",
     "i'm sorry dave. sod off.",
     "WHAT IS YOUR CREATORS NAME",
     "Do you want me to remember that?",
     "everything is uncertain except for five facts",
     "that's what she said",
     "so is your face",
     "your point?",
    ]
  end
end

COUNTERS = ['wtf','lol','voot','sigh']
LISTS    = ['lunch']

raw_args = ARGV[0].split
user = raw_args.first
args = raw_args[3..-1]

command = 
  if ['img', 'image', 'pic', 'picture'].include?(args.first.downcase)
    ApiCurl.new('http://www.google.com/uds/GimageSearch?q=_-#QUERY#-_&v=1.0', args[1..-1].join(' ')) { |response| JSON.parse(response)["responseData"]["results"].first["url"] }
  
  elsif COUNTERS.include?(args.first.downcase)
    Counter.new(args.first)
  
  elsif LISTS.include?(args.first.downcase)
    ListAdd.new(args.first.downcase, [user] + args[1..-1])

  elsif LISTS.any?{ |list| list + '-who?' == args.first.downcase }
    list = LISTS.detect{ |l| l + '-who?' == args.first.downcase }
    ListGet.new(list)

  elsif args.any?{ |arg| arg =~ /\bcats?\b/ }
    ApiCurl.new('http://gdata.youtube.com/feeds/api/videos?q=_-#QUERY#-_&orderby=relevance&max-results=1&alt=json', args.join(' ')) { |response| JSON.parse(response)["feed"]["entry"][0]["link"][0]["href"] }

  else
    RandomAnswer.new
  end

command.run
