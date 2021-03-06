# encoding: utf-8
require 'redd'
require 'sqlite3'
require 'logger'
require 'json'

config = File.read("config.json")
config = JSON.parse(config)
$pass = config["pass"]

$log = Logger.new('ryanall.log', 'daily')

$log.formatter = proc do |severity, datetime, progname, msg|
	"#{datetime}: #{msg}\n"
end

$db = SQLite3::Database.new( "ryan.db" )

$db.execute("CREATE TABLE IF NOT EXISTS ryan ( id VARCHAR(255) PRIMARY KEY);")
$db.execute("CREATE TABLE IF NOT EXISTS tip_total ( id VARCHAR(255) PRIMARY KEY, balance);")

ryan = Redd::Client::Unauthenticated.new.login "ryantipbot", $pass, nil, {:user_agent => "RYANBOT3 for /r/all by /u/hansolo669"}
$log.info "logged in"
$log.info "#{ryan.inspect}"

begin
	ryan.comment_stream "all" do |comment|
		unless comment.attributes[:subreddit] == "CrispyPops"
			if /\/u\/ryantipbot/i.match(comment.body)
				puts "potential tipper: " << comment.author
				$log.info "potential tipper #{comment.author.dump}"
				id = comment.id
				findid = $db.execute("SELECT * FROM ryan WHERE id = ?", id)
				if findid.empty?
					tipper = comment.author
					tippet = comment.attributes[:link_author]
					unless comment.root?
						parent_comment = ryan.get_info({:id => parent_id})
						tippet = parent_comment.things[0].author
					end
					amount = comment.body
					amount = /\d+ ryan/i.match(amount)
					unless amount == nil
						amount = amount[0].match(/\d+/)
						puts "replying and PMing"
						$log.info "reply and PMing"
						comment.reply "[✓] Accepted: #{tipper} → #{amount[0]} ryan (R#{amount[0]} ryan ryancoins) → #{tippet}"
						ryan.compose_message tippet, "YOU GOT TIPPED #{amount} RYAN COINS!", "YAY FOR YOU!"
						begin
							$db.execute("INSERT INTO ryan (id) VALUES (?)", id)
						rescue => e
							puts e
							$log.error "DB error #{e}"
						end
					end
				else
					puts "skip!"
					$log.info "skip"
				end
			end
		end
	end
rescue Redd::Error::RateLimited => e
	puts "rate limited"
	$log.error "rate limited"
	time_left = e.time
	sleep(time_left)
rescue Redd::Error => e
	status = e.code
	$log.error e
	raise e unless (500...600).include?(status)
end