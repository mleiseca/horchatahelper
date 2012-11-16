
require 'net/http'
require 'net/https'
require 'rubygems'
require 'xmlsimple'


HOST_NAME = 'qa1.grubhub.com'
HOLLAND_MI = {
    :lat=> 42.788227,
    :lng=>-86.106622
}

#http://www.grubhub.com/services/utility/geocode?apiKey=ghnipa&version=1&format=xml&combinedAddress=111+W+Washington+Chicago+IL
location = HOLLAND_MI
search_term = 'Taco'

def fetch_url(urlstring)
  puts "Fetching url: #{urlstring}"
  url = URI.parse(urlstring)
  http = Net::HTTP.new(url.host, url.port)

  http.use_ssl = true

  #print "Requesting: #{url.path}"
  #request = Net::HTTP::Get.new(url.path)
  http.start { |h| h.post(url.request_uri, "") }
end

def fetch_restaurants_serving(location, item)
  urlstring = "https://#{HOST_NAME}/services/search/lite/results?format=xml&apiKey=#{API_KEY}&lat=#{location[:lat]}&lng=#{location[:lng]}&menuSearchTerm=#{item}"

  response = fetch_url(urlstring)

  data = XmlSimple.xml_in(response.body)

  if data['restaurants'][0]['restaurant']
    data['restaurants'][0]['restaurant']
  else
    []
  end
end


def fetch_menu(restaurant_id)
  urlstring = "https://#{HOST_NAME}/services/restaurant/menu?format=xml&apiKey=#{API_KEY}&restaurantId=#{restaurant_id}"

  response = fetch_url(urlstring)

  data = XmlSimple.xml_in(response.body)
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

puts "Searching for #{search_term} at #{location}"

matching_restaurants = fetch_restaurants_serving(location, search_term)

if ! matching_restaurants
  puts "No matching restaurants found"
  exit
end

puts "... Found #{matching_restaurants.length} restaurants"

matching_restaurants.each do|restaurant|

  menu = fetch_menu(restaurant['id'])
  matching_items = extract_matching_item(menu, search_term)

  matching_items.each do|item|
    puts "...found item: #{item['name']}"
  end

end

#
#print data
#data['Result'].each do |item|
#  item.sort.each do |k, v|
#    if ["Title", "Url"].include? k
#      print "#{v[0]}" if k=="Title"
#      print " => #{v[0]}\n" if k=="Url"
#    end
#  end
#end
