
require 'net/http'
require 'net/https'
require 'rubygems'
require 'xmlsimple'
require 'json'


c = read_config

API_KEY = c["apiKey"]
HOST_NAME = c["grubhubHostname"]

def fetch_url(urlstring)
  puts "Fetching url: #{urlstring}"
  url = URI.parse(urlstring)
  http = Net::HTTP.new(url.host, url.port)

  http.use_ssl = true

  response = http.start { |h| h.post(url.request_uri, "") }
  data = XmlSimple.xml_in(response.body)


  if data['messages']
    data['messages'][0]['message'].each do|message|

      puts "#{message['type']}:: #{message['message'][0]}"
    end
  end
  data

end

def fetch_restaurants_serving(location, item)
  urlstring = "https://#{HOST_NAME}/services/search/lite/results?format=xml&apiKey=#{API_KEY}&lat=#{location[:lat]}&lng=#{location[:lng]}&menuSearchTerm=#{item}"

  data = fetch_url(urlstring)

end


def fetch_menu(restaurant_id)
  urlstring = "https://#{HOST_NAME}/services/restaurant/menu?format=xml&apiKey=#{API_KEY}&restaurantId=#{restaurant_id}"

  fetch_url(urlstring)
end


def extract_matching_item(menu, query_name)

  items = []
  menu['menu-sections'][0]['section'].each do|section|
    section['items'][0]['item'].each do|item|
      name = item['name'][0]
      if name.downcase.include? query_name.downcase
        items << item
      end
    end
  end
  items
end

def start_order_with_item(credentials, location, restaurant_id,pickup, generation_date, item, selections)
  urlstring = "https://#{HOST_NAME}/services/order/new?format=xml&apiKey=#{API_KEY}&restaurantId=#{restaurant_id}"
  urlstring += "&menuItemId=#{item['id']}"
  urlstring += "&email=#{credentials[:email]}&password=#{credentials[:password]}"
  if selections
    urlstring += "&choiceOptions=" + selections.join(',')
  end
  urlstring += "&quantity=1"
  urlstring += "&generationDate=#{URI::encode(generation_date)}"
  if pickup
    urlstring += "&pickup=Y"
  end

  #todo
  urlstring += "&crossstreet=Madison"
  #todo: other location bits




  order_check = fetch_url(urlstring)

  #protected String address1;
  #protected String address2;
  #protected String city;
  #protected String state;
  #protected String zip;
  #protected String lat;
  #protected String lng;
  #protected String phone;


end

def apply_freegrub(credentials, order_check, freegrub_string)

  urlstring = "https://#{HOST_NAME}/services/order/giftcard/apply?format=xml&apiKey=#{API_KEY}"
  urlstring += "&email=#{credentials[:email]}&password=#{credentials[:password]}"
  urlstring += "&giftCardCode=#{freegrub_string}"
  urlstring += "&orderId=#{order_check['order'][0]['id'][0]}"

  fetch_url(urlstring)
end

def finalize(credentials, order_check)
  urlstring = "https://#{HOST_NAME}/services/order/finalize?format=xml&apiKey=#{API_KEY}"
  urlstring += "&email=#{credentials[:email]}&password=#{credentials[:password]}"
  urlstring += "&orderId=#{order_check['order'][0]['id'][0]}"
  #todo
  urlstring += "&payment=creditcard"
  #todo
  urlstring += "&phone=3129521502"

  urlstring += "&total=" + get_total(order_check)

  fetch_url(urlstring)
end


def get_total(order_check)
  order_check['order'][0]['check'][0]['line-item'].each do|line_item|
    if "total" == line_item['type']
      return line_item['value'][0]
    end
  end
end

def display_check(order_check)
  check = order_check['order'][0]

  puts "\n=== ORDER SUMMARY ==="
  puts "Order Id    : #{check['id'][0]}"
  puts "Order method: #{check['order-method'][0]}"
  puts "\n=== ITEMS ==="
  check['order-items'][0]['order-item'].each do|order_item|
    desc = "(#{order_item['quantity'][0]}) #{order_item['name'][0]}"
    puts desc + (" " * [2, (20 - desc.length)].max ) + " $ #{order_item['price'][0]}"
  end

  puts "\n=== MATH ==="
  check['check'][0]['line-item'].each do|line_item|

    item_type = line_item['type'] + ":"
    puts item_type + (" " * [2, (20 - item_type.length)].max )+ " $ #{line_item['value'][0]}"
  end
end

def read_config
  JSON.parse(File.read("config.json"))
end

if __FILE__==$0

  #http://www.grubhub.com/services/utility/geocode?apiKey=&version=1&format=xml&combinedAddress=111+W+Washington+Chicago+IL
  #location = HOLLAND_MI
  search_term = 'Taco'

  puts "Searching for #{search_term} at #{location}"

  search_response = fetch_restaurants_serving(location, search_term)

  matching_restaurants = data['restaurants'][0]['restaurant']

  unless matching_restaurants
    puts "No matching restaurants found"
    exit
  end

  puts "... Found #{matching_restaurants.length} restaurants"

  matching_restaurants.each do|restaurant|

    menu = fetch_menu(restaurant['id'])
    matching_items = extract_matching_item(menu, search_term)

    matching_items.each do|item|
      puts "...found item: #{item['name']}"
      #menu['generation-date'][0]]
    end

  end

#  todo: yaml for
#     - locations
#     - payment options
#     - login credentials
#     - maximum amount to spend
#  todo: command line input for
#     - which location to use
#     - an item to search for
#     - how much interactivity...approve particular items? only approve total? no approval??
#     - pickup vs delivery??? (would have to add something about tip and delivery minimum)
#  todo: general
#     - loop to keep trying order
#     - build an item with randomly selection (required only?) options

end