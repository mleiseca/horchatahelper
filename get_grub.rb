
require 'net/http'
require 'net/https'
require 'rubygems'
require 'xmlsimple'
require 'json'
require 'optparse'

class String
  # colorization
  def colorize(color_code)
    "\e[#{color_code}m#{self}\e[0m"
  end

  def red
    colorize(31)
  end

  def green
    colorize(32)
  end

  def yellow
    colorize(33)
  end

  def pink
    colorize(35)
  end

  def blink
    "\e[5m#{self}\e[25m"
  end
end


def fetch_url(urlstring, args)
  puts "Fetching url: #{urlstring}" if $options[:debug]
  url = URI.parse(urlstring)
  http = Net::HTTP.new(url.host, url.port)

  http.use_ssl = true
  http.verify_mode = OpenSSL::SSL::VERIFY_NONE

  response = http.start { |h| h.post(url.request_uri, URI.escape(args.collect{|k,v| "#{k}=#{v}"}.join('&'))) }
  data = XmlSimple.xml_in(response.body)

  if data['messages']
    data['messages'][0]['message'].each do|message|
      puts "#{message['type']}:: #{message['message'][0]}"
    end
    exit
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

  urlstring = "https://#{HOST_NAME}/services/utility/geocode?format=xml&version=1&apiKey=#{API_KEY}"

  fetch_url(urlstring, {:combinedAddress => combined_address_string})

end

def fetch_restaurants_serving(location, item)

  urlstring = "https://#{HOST_NAME}/services/search/lite/results?format=xml&apiKey=#{API_KEY}"

  fetch_url(urlstring, {
      :open     => true,
      :restaurantType   => "PICKUP",
      :sortMode => $options[:sort_mode],
      :lat      => location['lat'],
      :lng      => location['lng'],
      :menuSearchTerm => item
  })
end


def fetch_menu(restaurant_id)
  urlstring = "https://#{HOST_NAME}/services/restaurant/menu?format=xml&apiKey=#{API_KEY}&restaurantId=#{restaurant_id}"

  fetch_url(urlstring, {})
end


def extract_matching_item(menu, query_name, active_timeperiod)

  items = []
  menu['menu-sections'][0]['section'].each do|section|
    section['items'][0]['item'].each do|item|
      name = item['name'][0]
      if (name.downcase.include? query_name.downcase) &&
          (item['availability'] == nil ||
              item['availability'].inject(false){|result, x| result || (active_timeperiod != nil && (x['time-period-ref'][0]['id'] == active_timeperiod))})
        items << item
      end
    end
  end
  items
end

def start_order_with_item(credentials, location, restaurant_id,pickup, generation_date, item, selections)
  urlstring = "https://#{HOST_NAME}/services/order/new?format=xml&apiKey=#{API_KEY}&restaurantId=#{restaurant_id}"
  urlstring += "&menuItemId=#{item['id']}"

  data = {
      :email    => credentials['email'],
      :password => credentials['password'],
      :generationDate=> generation_date,
      :quantity =>1
  }
  if selections
    data[:choiceOptions] = selections.join(',')
  end

  if pickup
    data[:pickup] = "Y"
  end


  #todo
  urlstring += "&crossstreet=Madison"
  #todo: other location bits

  order_check = fetch_url(urlstring, data)

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

  fetch_url(urlstring, {
      :email        => credentials['email'],
      :password     => credentials['password'],
      :giftCardCode => freegrub_string,
      :orderId      => order_check['order'][0]['id'][0]
  })
end

def finalize(credentials, order_check)
  urlstring = "https://#{HOST_NAME}/services/order/finalize?format=xml&apiKey=#{API_KEY}"

  #todo
  urlstring += "&phone=3129521502"

  fetch_url(urlstring, {
      :email        => credentials['email'],
      :password     => credentials['password'],
      :orderId      => order_check['order'][0]['id'][0],
      :payment=>"creditcard",
      :total=> get_total(order_check)
  })


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

  puts ""
  puts "#############################"
  puts "####### " + "ORDER SUMMARY".yellow + " #######"
  puts "#############################"
  puts "Order Id    : #{check['id'][0]}"
  puts "Order method: #{check['order-method'][0]}"
  puts "\n======= ITEMS ======="
  check['order-items'][0]['order-item'].each do|order_item|
    desc = "(#{order_item['quantity'][0]}) #{order_item['name'][0]} " + (order_item['description'].nil? ? "" : order_item['description'][0])
    puts desc + (" " * [2, (20 - desc.length)].max ) + " $ #{order_item['price'][0]}"
  end

  puts "\n======= MATH ======="
  check['check'][0]['line-item'].each do|line_item|

    item_type = line_item['type'] + ":"
    puts item_type + (" " * [2, (20 - item_type.length)].max )+ " $ #{line_item['value'][0]}"
  end
end

def read_config()
  JSON.parse(File.read("config.json"))
end

def build_valid_selections_for(item, menu)

  selections = []

  choice_by_id = {}
  menu['item-choices'][0]['choice'].each do|choice|
    choice_by_id[choice['id']] = choice
  end

  item['choices'][0]['choice-ref'].each do|c_ref|
    choice = choice_by_id[c_ref['id']]
    puts "checking out item choice: #{c_ref['id']}. min is #{choice['min']}" if $options[:debug]
    min = choice['min'].to_i
    if min > 0
      choice['options'][0]['option'].shuffle().take(min).each do|o_ref|
        puts "adding option #{o_ref['id']}"
        selections << o_ref['id']
      end
    end
  end

  selections
end

def determine_active_timeperiod(menu)
  if menu['time-periods'][0]['time-period']
    menu['time-periods'][0]['time-period'].each do |x|
      if x['active']
        return x['id']
      end
    end
  end

  nil
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

  count_str = matching_restaurants.length.to_s.yellow
  puts "found #{count_str} restaurants"
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
    active_timeperiod = determine_active_timeperiod(menu)
    matching_items = extract_matching_item(menu, $options[:search_term], active_timeperiod)

    puts ""
    puts "#############################"
    puts "#  #{restaurant['name']}"
    puts "#  #{restaurant['streetAddress']}"
    dist = ("%2.2f" % restaurant['distance-miles']).yellow
    puts "#  #{dist} miles"
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

        selections = item['choices'][0].empty? ? [] : build_valid_selections_for(item, menu)

        order_check = start_order_with_item($options[:config]["credentials"], $options[:location], restaurant['id'], true, menu['generation-date'][0], item, selections)
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
  puts "No more restaurants. Start over"
end


#  todo: start using saved...
#     - payment options
#  todo: command line input for
#     - how much interactivity...approve particular items? only approve total? no approval??
#     - pickup vs delivery??? (would have to add something about tip and delivery minimum)
#  todo: general
#     - build an item with randomly selection (required only?) options
#     - maximum amount to spend
#     - how to print in color?
