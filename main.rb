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

  def do_fetch_binance
    puts "processing binance"
    ex='binance'
    pairs = @client.pairs(ex)
    @prices["umine"]={}
    pairs.each do |pair|
      if(pair.base=="ZEC" and pair.target == "BTC")
        @prices["umine"]["ZEC_BTC"]={}
        @prices["umine"]["ZEC_BTC"]["bid"]=@client.order_book(pair).bids.sort!{|x,y| y.price.to_f <=>x.price.to_f }.first.price.to_f
        @prices["umine"]["ZEC_BTC"]["ask"]=@client.order_book(pair).asks.sort!{|x,y| y.price.to_f <=>x.price.to_f }.first.price.to_f
      end
      if(pair.base=="XMR" and pair.target == "BTC")
        @prices["umine"]["XMR_BTC"]={}
        @prices["umine"]["XMR_BTC"]["bid"]=@client.order_book(pair).bids.sort!{|x,y| y.price.to_f <=>x.price.to_f }.first.price.to_f
        @prices["umine"]["XMR_BTC"]["ask"]=@client.order_book(pair).asks.sort!{|x,y| y.price.to_f <=>x.price.to_f }.first.price.to_f
      end
    end
    puts @prices["umine"]
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
    @prices[ex_key]["BTC_AUD"]={}

    @prices[ex_key]["ETH_AUD"]={}
    @prices[ex_key]["ZEC_AUD"]={}
    @prices[ex_key]["XMR_AUD"]={}

    @prices[ex_key]["BTC_AUD"]["bid"] = @prices['coinjar']['BTC_AUD']['best_bid']*0.98
    @prices[ex_key]["BTC_AUD"]["ask"] = @prices['coinjar']['BTC_AUD']['best_ask']*1.02
    @prices[ex_key]["ETH_AUD"]["bid"] = @prices['coinjar']['ETH_AUD']['best_bid']*0.98
    @prices[ex_key]["ETH_AUD"]["ask"] = @prices['coinjar']['ETH_AUD']['best_ask']*1.02

    puts @prices
    @prices[ex_key]["ZEC_AUD"]["bid"] = @prices['coinjar']['BTC_AUD']['best_ask']*1.01*@prices["umine"]["ZEC_BTC"]["bid"]
    @prices[ex_key]["XMR_AUD"]["bid"] = @prices['coinjar']['BTC_AUD']['best_bid']*0.99*@prices["umine"]["XMR_BTC"]["bid"]
    @prices[ex_key]["ZEC_AUD"]["ask"] = @prices['coinjar']['BTC_AUD']['best_ask']*1.01*@prices["umine"]["ZEC_BTC"]["ask"]
    @prices[ex_key]["XMR_AUD"]["ask"] = @prices['coinjar']['BTC_AUD']['best_bid']*0.99*@prices["umine"]["XMR_BTC"]["ask"]


    puts @prices
  end

  def to_umine_json
    out = @prices.dup
    out.delete("acx")
    out.delete("coinjar")
    out.to_json
  end

  def _to_json
    @prices.to_json
  end

  def pretty_print
    puts JSON.pretty_generate(@prices)
  end

  def always_fetch
    while true
      begin
        do_fetch_binance
        do_fetch
        calculate_umine_price
        pretty_print
        sleep 30
      rescue=> exception
        puts exception
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

    set :bind, '0.0.0.0'

    class << self
      attr_reader :sinatra_thread
    end

    get '/' do
      $pf.to_umine_json
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
