
require 'net/http'
require 'net/https'
require 'rubygems'
require 'xmlsimple'
require 'json'
require 'optparse'

def fetch_url(urlstring, args)
  puts "Fetching url: #{urlstring}" if $options[:debug]
  url = URI.parse(urlstring)
  http = Net::HTTP.new(url.host, url.port)

  http.use_ssl = true
  http.verify_mode = OpenSSL::SSL::VERIFY_NONE

  response = http.start { |h| h.post(url.request_uri, "") }
  data = XmlSimple.xml_in(response.body)

  if data['messages']
    data['messages'][0]['message'].each do|message|
      puts "#{message['type']}:: #{message['message'][0]}"
    end
  end
  data
end

def fetch_geocode(location)

  #"address": "111 W Washington ",
  #    "address2": "Suite 2100",
  #    "city"  : "Chicago",
  #    "state"  : "IL",
  #    "zip"   : "60604"

  combined_address = [location["address"],location["address2"],location["city"], location["state"], location["zip"]]
  combined_address.delete_if{|x| x == nil}
  combined_address_string = combined_address.join(" ")

  puts "Geocoding '#{combined_address_string}'"  if $options[:debug]

  #http://www.grubhub.com/services/utility/geocode?apiKey=&version=1&format=xml&combinedAddress=111+W+Washington+Chicago+IL

  urlstring = "https://#{HOST_NAME}/services/utility/geocode?format=xml&version=1&apiKey=#{API_KEY}&combinedAddress=#{URI.encode(combined_address_string)}"

  fetch_url(urlstring, {})

end

def fetch_restaurants_serving(location, item)

  urlstring = "https://#{HOST_NAME}/services/search/lite/results?format=xml&apiKey=#{API_KEY}&lat=#{location['lat']}&lng=#{location['lng']}&menuSearchTerm=#{URI::encode(item)}"

  fetch_url(urlstring, {})
end


def fetch_menu(restaurant_id)
  urlstring = "https://#{HOST_NAME}/services/restaurant/menu?format=xml&apiKey=#{API_KEY}&restaurantId=#{restaurant_id}"

  fetch_url(urlstring, {})
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
  urlstring += "&email=#{credentials['email']}&password=#{credentials['password']}"
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

  order_check = fetch_url(urlstring, {})

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
  urlstring += "&email=#{credentials['email']}&password=#{credentials['password']}"
  urlstring += "&giftCardCode=#{freegrub_string}"
  urlstring += "&orderId=#{order_check['order'][0]['id'][0]}"

  fetch_url(urlstring, {})
end

def finalize(credentials, order_check)
  urlstring = "https://#{HOST_NAME}/services/order/finalize?format=xml&apiKey=#{API_KEY}"
  urlstring += "&email=#{credentials['email']}&password=#{credentials['password']}"
  urlstring += "&orderId=#{order_check['order'][0]['id'][0]}"
  #todo
  urlstring += "&payment=creditcard"
  #todo
  urlstring += "&phone=3129521502"

  urlstring += "&total=" + get_total(order_check)

  fetch_url(urlstring, {})
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

def read_config()
  JSON.parse(File.read("config.json"))
end

if __FILE__==$0
  optparse = OptionParser.new do|opts|

    $options = {}
    $options[:config] = read_config()
    API_KEY = $options[:config]["apiKey"]
    HOST_NAME = $options[:config]["grubhubHostname"]

    # This displays the help screen, all programs are
    # assumed to have this option.
    opts.on( '-l', '--location LOCATION_NAME', 'Select location from config file' ) do |location_name|
      $options[:location]= $options[:config]["locations"][location_name]

      unless $options[:location]
        print "Could not find location: #{$options[:location]}"
        exit
      end
    end
    opts.on( '-t', '--term SEARCH_TERM', 'What do you want to eat?' ) do |search_term|
      $options[:search_term]= search_term

      unless $options[:search_term]
        print "Enter a search term"
        exit
      end
    end

    opts.on('-d', '', "Debug") do
      $options[:debug] = true
    end

    $options[:sort_mode] = 'DISTANCE'
    opts.on('-s', '--sortmode SORT_MODE', "Which restaurants should appear first?") do |sort_mode|
      #STAR_RATING, AGE
      $options[:sort_mode] = sort_mode
    end

  end

  optparse.parse!

  #########################################################################################################
  #
  # Validate user input
  #
  #########################################################################################################

  if $options[:location] == nil
    print "No location specified. Exiting"
    exit
  end


  #########################################################################################################
  #
  # Geocode...if the user selected a location without lat/lng
  #
  #########################################################################################################

  if $options[:location]["lat"]==nil|| $options[:location]["lng"]==nil
    geocode_response = fetch_geocode($options[:location])


    if geocode_response['geocode'].length == 1
      lat = geocode_response['geocode'][0]["lat"][0]
      lng = geocode_response['geocode'][0]["lng"][0]
      puts "**** Had to geocode. You can skip this by adding ...\"lat\":\"#{lat}\", \"lng\":\"#{lng}\" to your config for this address*****"

      $options[:location]["lat"] = lat
      $options[:location]["lng"] = lng
    else
      puts "Uh oh! Found #{geocode_response['geocode'].length} geocodes for this address. Fix your config with a distinct address. Can't proceed'"
      exit
    end
  end

  #########################################################################################################
  #
  # Search
  #
  #########################################################################################################

  print "Searching for #{$options[:search_term]} at #{$options[:location]["address"]}.... "

  search_response = fetch_restaurants_serving($options[:location], $options[:search_term])

  matching_restaurants = search_response['restaurants'][0]['restaurant']

  unless matching_restaurants
    puts "No matching restaurants found."
    exit
  end

  puts "found #{matching_restaurants.length} restaurants"
  sleep(1)

  #########################################################################################################
  #
  # Poke through matching restaurants looking for matching items
  #  ... there is a service in the works that would do this for us...
  #
  #########################################################################################################


  matching_restaurants.each do|restaurant|

    puts "... Trying to match items at #{restaurant['name']} " if $options[:debug]

    menu = fetch_menu(restaurant['id'])
    matching_items = extract_matching_item(menu, $options[:search_term])

    puts ""
    puts "#############################"
    puts "#  #{restaurant['name']}"
    puts "#  #{restaurant['streetAddress']}"
    puts "#  %2.2f miles" % restaurant['distance-miles']
    puts "#  #{restaurant['cuisines'][0]['cuisine'].join(', ')}"
    puts "#  #{matching_items.length} matching items"
    puts "#############################"


    continue if ! matching_items

    puts "How about..."
    matching_items.each do|item|
      print "- '#{item['name']}'. Ok? [y/N/Skiprestaurant]: "

      input = gets

      if input.strip.downcase == 's'
        break
      elsif input.strip.downcase == 'y'
        puts "Adding item to order..."
        order_check = start_order_with_item($options[:config]["credentials"], $options[:location], restaurant['id'], true, menu['generation-date'][0], item, [])
        display_check(order_check)

        if $options[:config]["freegrubs"].length > 0
          puts "Applying freegrub to order..."
          order_check = apply_freegrub($options[:config]["credentials"],order_check, $options[:config]["freegrubs"][0])

          display_check(order_check)
        end

        print "...place order? This will send money! [y/N]: "
        input = gets
        if input.strip.downcase == 'y'
          order_check = finalize($options[:config]["credentials"], order_check)

          puts "Final order check"
          display_check(order_check)
          exit
        else
          puts "Cold feet, eh? I'm outta here!"
          exit
        end
      else
        #  trying with the next item
      end
    end
  end
end
puts "No more restaurants. Start over"


#  todo: start using saved...
#     - locations
#     - payment options
#     - login credentials
#  todo: command line input for
#     - which location to use
#     - an item to search for
#     - how much interactivity...approve particular items? only approve total? no approval??
#     - pickup vs delivery??? (would have to add something about tip and delivery minimum)
#  todo: general
#     - loop to keep trying order
#     - build an item with randomly selection (required only?) options
#     - maximum amount to spend

