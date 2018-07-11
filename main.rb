require 'cryptoexchange'
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


  def to_json
    @prices.to_json
  end

  def print
    puts JSON.pretty_generate(@prices)
  end
end



pf= PriceFetcher.new

pf.do_fetch
puts pf.print
