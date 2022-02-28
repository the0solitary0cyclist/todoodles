require "sinatra"
require "http"
require 'securerandom'
# require 'dotenv/load'

$code = nil
$state= nil
$token = nil
$refresh_token = nil

class Toodledo
  attr_accessor :client_id, :client_secret, :state, :scope, :auth_url


  def initialize(client_id=nil, client_secret=nil, state=nil, scope=nil)


    @client_id =  ENV['client_id'] || $client_id
    @client_secret = ENV['client_secret'] || $client_secret
    envstate = ENV['state'] || $state
    @state =  envstate || SecureRandom.alphanumeric(13)
    @scope = scope || "basic%20tasks%20write"

    pp @cl

    authorization_url = "https://api.toodledo.com/3/account/authorize.php"
    @auth_url = authorization_url + "?response_type=code&client_id=" + @client_id + "&state=" + @state + "&scope=" + @scope

    time = Time.now
    @duedate = Time.new(time.year, time.month, time.day, 12, 0, 0, "+00:00").to_i # tasks from the server always have 12pm GMT timestamp

  end

  def client_params

    params = {
      :site => @auth_url,
      :authorize_url => @auth_url,
      :token_url => "https://api.toodledo.com/3/account/token.php"
    }

  end

  def token_get_url

    "https://api.toodledo.com/3/account/token.php"

  end
    
  def account_get_url

    "https://api.toodledo.com/3/account/get.php?"

  end

  def task_get_url

    "https://api.toodledo.com/3/tasks/get.php?"

  end

  def task_post_url

    "http://api.toodledo.com/3/tasks/add.php"

  end
  
#   def task_put_url
    "http://api.toodledo.com/3/tasks/edit.php"
# 	access_token=yourtoken
# 	tasks=[{"id"%3A"1234"%2C"title"%3A"My Task"}%2C{"id"%3A"1235"%2C"title"%3A"Another Task"%2C"star"%3A"1"}
# %2C{"id"%3A"5678"%2C"title"%3A"Invalid"}]
# 	fields=folder,star
#   end

  def get_task_pages(url, page, start, alltasks, total)

    if total > 1000
      res = HTTP.get(url + "&start=#{start}")
      start = start + 1000
      total -= 1000
      next_page = JSON.parse(res)
      next_array = next_page.drop(1)
      pp alltasks.count
      alltasks += next_array
      pp alltasks.count
      self.get_task_pages(url, next_page, start, alltasks, total)
    else
      return alltasks
    end

  end

  def today_tasks_all(arr)

    results = []
    arr.each do |hash|
      results << hash if hash["duedate"] == @duedate
    end
    return results

  end
  
  def tasks_to_update(arr)
     array.find {|x| x["title"].includes? "move me"}
  end

  def today_tasks_sorted(arr)

    completed = []
    todo = []
    arr.each do |task|
      completed << task if task["completed"] == @duedate
      todo << task if task["completed"] == 0
    end
    return {:completed => completed, :todo => todo}
  end

end

enable :sessions

toodledo = Toodledo.new

# $code = false
# $token = false
# $state = false
# $refresh_token = false



# use this as expired example?
# $token="ad8708449f8592bf26df4e5ee62654989d19af11"

$tz = ENV['TZ'] || 'America/New_York'
$test = ENV['test'] || false


get "/" do

  if $code
    redirect "/profile"
  else
    erb "<h1><a id='auth' href='#{toodledo.auth_url}'>Authorize</a></h1>"
  end

end

get "/callback" do

  if !$token
    # session[:access_token] = token
    $code = params[:code]
    $state = params[:state]
    response = HTTP.post(toodledo.token_get_url,
                form: {
                    grant_type: 'authorization_code',
                    client_id: toodledo.client_id,
                    client_secret: toodledo.client_secret,
                    code: params[:code]
                })
    # Reponse looks like:
    # {"access_token"=>"828c48b4fc549fbb42ebb9fc0a3cd3f8af45d46c",
    #     "expires_in"=>7200,
    #     "token_type"=>"Bearer",
    #     "scope"=>"basic tasks write folders",
    #     "refresh_token"=>"a36254e42bc41296f2fec0cc5db16ba4e2e8df12"}

    # session[:access_token] = response.parse["access_token"]
    # token = session[:access_token]

    $token = response.parse["access_token"]
    $refresh_token = response.parse["refresh_token"]

  end
  redirect to "/profile"

end

get "/refresh" do

  # refresh_auth = HTTP.headers("Authorization" => "Basic #{$code}")
  # .get(toodledo.task_get_url)
  #   Authorization: Basic czZCaGRSa3F0Mzo3RmpmcDBaQnIxS3REUmJuZlZkbUl3

  # https://api.toodledo.com/3/account/token.php
  # 	grant_type=refresh_token
  # 	refresh_token=389d276132d7d256e48e9056dd5d6d6f313be246

  # new_auth = HTTP.headers("Authorization" => "Basic #{$code}")
  new_auth = HTTP.post(toodledo.token_get_url,
                  form: {
                    grant_type: 'refresh_token',
                    refresh_token: $refresh_token,
                    client_id: toodledo.client_id,
                    client_secret: toodledo.client_secret,
                    code: $code
                  })

  $token = new_auth.parse["access_token"]
  $refresh_token = new_auth.parse["refresh_token"]

  pp 'new auth'
  pp JSON.parse(new_auth)
  # success
  # {"access_token"=>"03eb3b0b08fda042e5ebaa751d51ec5d69117c92",
  #   "expires_in"=>7200,
  #   "token_type"=>"Bearer",
  #   "scope"=>"basic tasks write folders",
  #   "refresh_token"=>"92242e214195d53e4ca35a4b64bf81a9f06c941a"}

  # error
  # {"errorCode"=>102,
  #   "errorDesc"=>"Missing parameter: \"refresh_token\" is required"}
  # redirect "/"

  if new_auth.status.success?
    redirect "/"
  end

  # 127.0.0.1 - - [25/Sep/2021:19:54:07 -0400] "GET /refresh HTTP/1.1" 200 - 0.1812
# 2021-09-25 19:54:07 -0400 Read: #<NoMethodError: undefined method `bytesize' for ["access_token", "03eb3b0b08fda042e5ebaa751d51ec5d69117c92"]:Array>
end

get "/profile" do

  @url = toodledo.task_get_url + "access_token=#{$token}&fields=folder,duedate"
#   @taskUpdateUrl = toodle.task_put_url
  # @url = "http://api.toodledo.com/3/tasks/get.php?access_token=#{session[:access_token]}&fields=folder,star,priority"
  
  #response = HTTP
  #     .headers("Authorization" => "token #{session[:access_token]}") # the should probably be "Bearer"
  #     .get(toodledo.task_get_url)
  response = HTTP.get(@url)

   #these don't give you back a real array
  # response.parse
  # response.body

  # example error string
  # "{\"errorCode\":1,\"errorDesc\":\"No access_token given\"}"

  if response.status.client_error?
    $token = false

    redirect "/refresh"
  else
    first_page = JSON.parse(response)
    total = first_page[0]['total']
    first_array = first_page.drop(1)
    start = 1001

    alltasks = toodledo.get_task_pages(@url, first_page, start, first_array, total)

    @today_tasks = toodledo.today_tasks_all(alltasks)
    completed = toodledo.today_tasks_sorted(@today_tasks)[:completed]
    todo = toodledo.today_tasks_sorted(@today_tasks)[:todo]
    
#     @move_tasks = tasks_to_update(@today_tasks)

    @reward = completed.count >=1 && todo.count == 0

    puts "reward: #{@reward}"
    puts "test: #{$test}"
    puts "combo: #{@reward || $test}"

    if @reward || $test
      require 'net/http'
      require 'uri'

      task_title = URI.encode_www_form_component(Time.now.strftime("%F %T"))

      # uri = URI.parse("http://api.toodledo.com/3/tasks/add.php")
      uri = URI.parse(toodledo.task_post_url)
      request = Net::HTTP::Post.new(uri)
      request.body = "access_token=#{$token}&tasks=%5B%7B%22title%22%3A%22#{task_title}%22%2C%22star%22%3A%221%22%2C%22folder%22%3A9484459%7D%5D%0D%0A"
      # request.body = "access_token=#{session[:token]}&tasks=%5B%7B%22title%22%3A%22#{task_title}%22%2C%22star%22%3A%221%22%2C%22folder%22%3A9484459%7D%5D%0D%0A"

      req_options = {
        use_ssl: uri.scheme == "https",
      }

      response = Net::HTTP.start(uri.hostname, uri.port, req_options) do |http|
        http.request(request)
      end

      # rescue Exception => e
      #   pp e
      #   $token = false

      #   redirect "/refresh"
      # end
      @newtask = JSON.parse(response.body)

    end
  
  end

  @mycode = $code
  @mystate = $state
  @mytoken = $token
  @myrefreshtoken = $refresh_token
  @data = alltasks.count
  # erb '<p>$code="<%= @mycode %>"</p>
  #       <p>$state="<%= @mystate %>"</p>
  #       <p>$token="<%= @mytoken %>"</p>
  #       <p>$refresh_token="<%= @myrefreshtoken %>"</p>
  #       <p>Dispatch? <%= @newtask %></p>
  #       <p>Reward? <%= @reward %></p>
  #       <p>Today: <%= @today_tasks %>
  #       <p>Total task Count: <%= @data %></p>
  #       <p>Url:<%= @url %></p>'
  erb '<p>Total task Count: <%= @data %></p>
        <p>Today: <%= @today_tasks %>
        <p>Reward? <%= @reward %></p>
        <p>Dispatch? <%= @newtask ? @newtask : "none"%></p>'

end
