require 'pry'
class DogManager
  SHELTER_URL = "https://www.shelterluv.com/available_pets/5937?species=Dog".freeze

  PREFERRED_BREEDS = [
    'australian shepherd',
    'border collie',
    'catahoula',
    'retriever',
    'shepherd'
  ].freeze

  DOG_DATA_JSON = "dogs_list.json".freeze

  def initialize
    @dogs = get_dogs_json
    @new_dogs = filter_new_dogs
  end

  def run
    send_new_dog_listings_text
    write_dogs_list_to_file
  end

  def write_dogs_list_to_file
    File.open(DOG_DATA_JSON, "w") do |f|
      f.write(@dogs)
    end
  end

  private

  def filter_new_dogs
    new_dogs = JSON.parse(@dogs)
    existing_dogs = File.read(DOG_DATA_JSON)

    return new_dogs if existing_dogs.empty?

    new_dogs - JSON.parse(existing_dogs)
  end


  def send_new_dog_listings_text
    account_sid = ENV['TWILIO_ACCOUNT_SID']
    auth_token = ENV['TWILIO_AUTH_TOKEN']
    client = Twilio::REST::Client.new(account_sid, auth_token)

    from = ENV['FROM_PHONE_NUMBER'] # Your Twilio number
    to = ENV['TO_PHONE_NUMBER'] # Your mobile phone number

    client.messages.create(
      from: from,
      to: to,
      body: create_dog_listings_text
    )
  end

  def get_dogs_json
    dogs = []
    doc = Nokogiri::HTML(URI.open(SHELTER_URL))
    dog_divs = doc.css('div[data-groups="[\"Dogs\"]"]')
    puts "Scraping #{dog_divs.count} dog(s)..."

    dog_divs.each do |dog_div|
      profile_url = dog_div.at_css('a.profile_link')['href']
      dog_profile = Nokogiri::HTML(URI.open(profile_url))
      name = dog_profile.at_css('div.col-lg-6.col-md-6 div.price').text.strip
      dog_data = dog_profile.at_css('div.col-lg-6.col-md-6 div.row')
      parsed_dog_data = parse_dog_data(dog_data)

      parsed_dog_data.merge! name: name
      dogs << parsed_dog_data
    end

    dogs.to_json
  end

  def create_dog_listings_text
    return "No dogs found!" unless @dogs.size > 0

    return "No new dogs found!" unless @new_dogs.size > 0

    dog_listings_text = "Found #{@new_dogs.size} dogs...\n\n"

    @new_dogs.each do |dog|
      dog_listings_text += "Name: #{dog["name"]}\n"
      dog_listings_text += "Breed: #{dog["breed"]}\n"
      dog_listings_text += "Age: #{dog["age"]}\n"
      dog_listings_text += "Weight: #{dog["weight"]}\n"
      dog_listings_text += "Sex: #{dog["sex"]}\n"
      dog_listings_text += "\n"
    end

    dog_listings_text += SHELTER_URL
  end

  def scrape_dogs
    dogs = []
    doc = Nokogiri::HTML(URI.open(SHELTER_URL))
    dog_divs = doc.css('div[data-groups="[\"Dogs\"]"]')
    puts "Scraping #{dog_divs.count} dog(s)..."

    dog_divs.each do |dog_div|
      profile_url = dog_div.at_css('a.profile_link')['href']
      dog_profile = Nokogiri::HTML(URI.open(profile_url))
      name = dog_profile.at_css('div.col-lg-6.col-md-6 div.price').text.strip
      dog_data = dog_profile.at_css('div.col-lg-6.col-md-6 div.row')
      parsed_dog_data = parse_dog_data(dog_data)

      parsed_dog_data.merge! name: name
      dogs << parsed_dog_data.to_json
    end

    dogs
  end

  def parse_dog_data(dog_data)
    parsed_dog_data = {}

    return parsed_dog_data unless dog_data

    dog_data.css('a').each do |data_point|
      data_text = data_point.text.strip

      parsed_dog_data[:breed] = data_text.split(" - ").last if data_text.start_with?("Dog")
      parsed_dog_data[:sex] = data_text.split(" : ").last if data_text.start_with?("Sex")
      parsed_dog_data[:age] = data_text.split(" : ").last if data_text.start_with?("Age")
      parsed_dog_data[:weight] = data_text.split(" : ").last if data_text.start_with?("Weight")
    end

    parsed_dog_data[:preferred_breed] = PREFERRED_BREEDS.any? { |breed| parsed_dog_data[:breed].downcase.include? breed }

    parsed_dog_data
  end
end
