require 'cryptoexchange'
require 'sinatra'
require 'redis'
require 'json'

class PriceFetcher


  def initialize
    @client = Cryptoexchange::Client.new
    @exchanges = ['coinjar','acx']
    @prices={}
    @exchanges.each do |ex|
      @prices[ex]={}
    end

  end


  def do_fetch
    @exchanges.each do |ex|
      pairs = @client.pairs(ex)
      pairs.each do |_pair|
        pair = @client.order_book(_pair)
        umine_key = "#{pair.base}_#{pair.target}"
        puts "processing #{ex} #{umine_key}"
        @prices[ex][umine_key]={}
        begin
          bids = pair.bids.sort!{|x,y| y.price.to_f <=>x.price.to_f }
          @prices[ex][umine_key]["best_bid"] = bids.first.price.to_f

          asks = pair.asks.sort{|x,y| x.price.to_f <=>y.price.to_f }
          @prices[ex][umine_key]["best_ask"] = asks.first.price.to_f

          mid = (bids.first.price.to_f + asks.first.price.to_f) /2
          @prices[ex][umine_key]["mid"]=mid
          @prices[ex][umine_key]["_ts"]=Time.now
        rescue
          #do nothing now
        end

      end
    end
  end

  def calculate_umine_price
    ex_key = "umine"
    @prices[ex_key]={}
    @prices[ex_key]["BTC_AUD"]={}

    @prices[ex_key]["ETH_AUD"]={}

    @prices[ex_key]["BTC_AUD"]["bid"] = @prices['coinjar']['BTC_AUD']['best_bid']*0.98
    @prices[ex_key]["BTC_AUD"]["ask"] = @prices['coinjar']['BTC_AUD']['best_ask']*1.02
    @prices[ex_key]["ETH_AUD"]["bid"] = @prices['coinjar']['ETH_AUD']['best_bid']*0.98
    @prices[ex_key]["ETH_AUD"]["ask"] = @prices['coinjar']['ETH_AUD']['best_ask']*1.02

  end



  def to_json
    @prices.to_json
  end

  def pretty_print
    puts JSON.pretty_generate(@prices)
  end

  def always_fetch
    while true
      begin
        do_fetch
        calculate_umine_price
        pretty_print
        sleep 30
      rescue
        sleep 1
        #just retry
      end
    end
  end

end

$pf=nil

t0=Thread.new{

  class SinatraServer < Sinatra::Application

    puts "Sinatra running in thread: #{Thread.current}"

    class << self
      attr_reader :sinatra_thread
    end

    get '/' do
      $pf.to_json
    end

    get '/test' do
      "test"
    end

    run!
  end

}

t1=Thread.new {

  $pf= PriceFetcher.new
  $pf.always_fetch
}


t0.join
t1.join