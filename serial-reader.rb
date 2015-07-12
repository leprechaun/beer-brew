#!/usr/bin/env ruby

require 'serialport'
require 'json'
require 'aws-sdk'
require 'time'

kinesis = Aws::Kinesis::Client.new(
	region: "ap-southeast-2"
)

build_number = 0
stage = 0
time_elapsed = 10
temperature = 0.1
relay_state = true

sp = SerialPort.new("/dev/ttyUSB0", 9600, 8, 1, SerialPort::NONE )

file_out = File.new("/app/raw-serial-out.log", "a+")

build_number = 1

start_time = Time.now

begin
	while true do
		while(i = sp.gets.chomp) do
			begin
				puts i
				splitted = i.split(" ")
				puts splitted.inspect
				stage = splitted[0].to_i
				current_time = splitted[1]
				elapsed = splitted[2].to_i
				temperature = splitted[3].to_f
				relay_state = splitted[4] == "On" ? 1 : 0

				current = Time.now
				time_elapsed = current - start_time
				
				file_out.write(i + "\n")
				msg = {
					"source.project": "tw-rea-brewing",
					"source.application": "arduino-beer-brew",
					"source.build-number": build_number,
					"type": "brew_log",
					"brew":{
						"stage": stage,
						"time.stage": time_elapsed,
						"time.total": elapsed,
						"temperature": temperature,
						"relay_state": relay_state
					}
				}
				kinesis.put_records({
					stream_name: ENV['STREAM_NAME'],
					records: [
						data: msg.to_json,
						partition_key: "beer_brew"
					]
				})
				puts msg.to_json

			rescue StandardError => e
				puts e
			end
		end
	end
rescue StandardError => e
	puts e
end

sp.close
