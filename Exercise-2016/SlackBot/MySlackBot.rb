# coding: utf-8
$LOAD_PATH.unshift(File.dirname(__FILE__))

require 'sinatra'
require 'SlackBot'
require 'net/http'
require 'uri'
require 'json'

class MySlackBot < SlackBot

  def get_json(get_url)
    url = URI.parse(get_url)
    req = Net::HTTP::Get.new(url.request_uri)
    res = Net::HTTP.start(url.host, url.port) do |http|
      http.request(req)
    end

    return res.body
  end

  def say_respond(params, options = {})
    return nil if params[:user_name] == "slackbot" || params[:user_id] == "USLACKBOT"
    options[:text] = ""
    /[｢「](.*)[｣」]と言って/ =~params[:text]

    options[:text] = $1
    p options.to_json
    return options.to_json
  end

  def get_weather(params, options = {})
    key = params[:text].sub(/^\s*say\s*/,'')
    json = get_json("http://weather.livedoor.com/forecast/webservice/json/v1?city=330010")

    obj = JSON.parse(json, {symbolize_names: true})
    
    options[:text] = "<#{obj[:link]}|岡山の天気>\n#{obj[:description][:text]}"
    options[:attachments] = [
      {
        color: "#439FE0",
        title: "#{obj[:forecasts][0][:date]}",
        text: "#{obj[:forecasts][0][:telop]}"
      },
      {
        color: "#9FE043",
        title: "#{obj[:forecasts][1][:date]}",
        text: "#{obj[:forecasts][1][:telop]},最高気温:#{obj[:forecasts][1][:temperature][:max][:celsius]}, 最低気温:#{obj[:forecasts][1][:temperature][:min][:celsius]}"
      }
    ]
    if (!obj[:forecasts][0][:temperature][:max].nil?)
      options[:attachments][0][:text] << ",最高気温:#{obj[:forecasts][0][:temperature][:max][:celsius]}"
    end
    if obj[:forecasts].length == 3
      options[:attachments].push(
      {
        color: "#E0439F",
        title: "#{obj[:forecasts][2][:date]}",
        text: "#{obj[:forecasts][2][:telop]}"
      }
      )
    end
    p options
    
    return options.to_json
  end
  
  def exec_command(params)
    options = {username: "T-Bot", icon_emoji: "chipmunk"}
    if /[｢「](.*)[｣」]と言って/ =~ params[:text]
      say_respond(params, options)
    elsif /^\s*weather/ =~ params[:text]
      get_weather(params, options)
    else
      naive_respond(params, options)
    end
  end
  
end

slackbot = MySlackBot.new

set :environment, :production

get '/' do
  "SlackBot Server"
end

post '/slack' do
  content_type :json
  if params[:token] == "Bse1xTFrAVM7OeQJTJGBzIL9"
    params[:text].sub!(/^@T-Bot\s/, '')
    slackbot.exec_command(params)
  else
    p "ERROR: POST is delivered by wrong whooks"
    ""
  end
end

post '/git' do

  content_type :json

  body =  JSON.parse(request.body.read, {symbolize_names: true})
  
  string = "#{body[:pusher][:name]} pushed : <#{body[:repository][:html_url]}|#{body[:repository][:full_name]}>\n"
  
  options = {
    username: "T-Bot",
    icon_emoji: "chipmunk",
    attachments: [
      {
        color: "#439FE0",
        title: "commit",
        text: "user : #{body[:head_commit][:committer][:username]}\nmessage : #{body[:head_commit][:message]}\n"
      }
    ]
  }

  if (!body[:head_commit][:added].empty?)
    options[:attachments][0][:text] << "add: "
    body[:head_commit][:added].each do |file|
      options[:attachments][0][:text] << "#{file}\t"
    end
    options[:attachments][0][:text] << "\n"
  end

  if (!body[:head_commit][:removed].empty?)
    options[:attachments][0][:text] << "removed: "
    body[:head_commit][:removed].each do |file|
      options[:attachments][0][:text] << "#{file}\t"
    end
    options[:attachments][0][:text] << "\n"
  end

  if (!body[:head_commit][:modified].empty?)
    options[:attachments][0][:text] << "modified: "
    body[:head_commit][:modified].each do |file|
      options[:attachments][0][:text] << "#{file}\t"
    end
    options[:attachments][0][:text] << "\n"
  end

  slackbot.post_message(string, options)
end
