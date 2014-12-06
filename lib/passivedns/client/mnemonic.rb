# DESCRIPTION: Module to query Mnemonic's passive DNS repository
# CONTRIBUTOR: Drew Hunt (pinowudi@yahoo.com)
require 'net/http'
require 'net/https'
require 'openssl'

module PassiveDNS
	class Mnemonic
		attr_accessor :debug
		def initialize(config="#{ENV['HOME']}/.mnemonic")
			if File.exist?(config)
				@apikey = File.open(config).read.split(/\n/)[0]
				$stderr.puts "DEBUG: Mnemonic#initialize(#{@apikey})" if @debug
			else
				raise "Configuration file for Mnemonic is required for intialization\nFormat of configuration file (default: #{ENV['HOME']}/.mnemonic) is the 40 character apikey on one line."
			end
		end

		def parse_json(page,query,response_time=0)
			res = []
			# need to remove the json_class tag or the parser will crap itself trying to find a class to align it to
			data = JSON.parse(page)
			if data['result']
				data['result'].each do |row|
					if row['query']
						res << PDNSResult.new('Mnemonic',response_time,row['query'],row['answer'],row['type'].upcase,row['ttl'],row['first'],row['last'])
					end
				end
			end
			res
		rescue Exception => e
			$stderr.puts "Mnemonic Exception: #{e}"
			raise e
		end

		def lookup(label, limit=nil)
			$stderr.puts "DEBUG: Mnemonic.lookup(#{label})" if @debug
			Timeout::timeout(240) {
				url = "https://passivedns.mnemonic.no/api1/?apikey=#{@apikey}&query=#{label}&method=exact"
				$stderr.puts "DEBUG: Mnemonic url = #{url}" if @debug
				url = URI.parse url
				http = Net::HTTP.new(url.host, url.port)
				http.use_ssl = (url.scheme == 'https')
				http.verify_mode = OpenSSL::SSL::VERIFY_NONE
				http.verify_depth = 5
				request = Net::HTTP::Get.new(url.path+"?"+url.query)
				request.add_field("User-Agent", "Ruby/#{RUBY_VERSION} passivedns-client rubygem v#{PassiveDNS::Client::VERSION}")
				t1 = Time.now
				response = http.request(request)
				t2 = Time.now
				recs = parse_json(response.body, label, t2-t1)
				if limit
					recs[0,limit]
				else
					recs
				end
			}
		rescue Timeout::Error => e
			$stderr.puts "Mnemonic lookup timed out: #{label}"
		end
	end
end