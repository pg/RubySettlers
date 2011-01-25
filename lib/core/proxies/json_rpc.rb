#  Copyright (C) 2007 John J Kennedy III
#
#  This program is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation; either version 3 of the License, or
#  (at your option) any later version.
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with this program.  If not, see <http://www.gnu.org/licenses/>.

require 'json'
require 'logger'
require 'socket'

# This file defines all the generic code for JSON communication
# These connections add more than just the sending and recieving of JSON-RPC commands, 
# They create proxy classes that send and recieve the appropriate messages.
# These connections should be able to handle the sending and recieving of any Ruby 
# objects.  Communication is asyncronous.
# The only ruby construct that it does not support is blocks.  But blocks should 
# not be sent over JSON anyways.

def write_now(st)
  puts st
  STDOUT.flush
end

#A Representation of a JSON-RPC request
#This class keeps track of the request id and the response that comes back.
class JSONRequest
  attr_reader :req_id
  attr_accessor :response, :has_response

  def initialize(id)
    @req_id = id
    @has_response = false
    @response = nil
  end

  def to_s
    "<request #{@req_id} />"
  end
end




#Local classes that include this will be remotely accessible, and ONLY these classes.
#This ensures that a remote connection cannot access unintended objects
module RemotelyAccessible

  @@proxy_objects = {}
  @@remotely_accessible_methods = [:==, :to_s]

  #Send the given method to the remote (original) object
  def allow_remote_method(method_name)
	@@remotely_accessible_methods << method_name.to_sym
  end
  
  def allow_remote_methods(*method_names)
	@@remotely_accessible_methods += method_names
  end
  
  def is_method_allowed(method_name)
	@@remotely_accessible_methods.include?(method_name.to_sym)
  end

  def from_json(json_hash, json_connection)
	remote_id = json_hash['remote_id']
	class_name = json_hash['class_name']
	if class_name.nil? or class_name == ''
		raise 'Bad response, Proxy Objects require a "class_name" value.  hash:'+json_hash.to_s
	end
	if @@proxy_objects.has_key?(remote_id)
		return @@proxy_objects[remote_id]
	end
    obj = ProxyObject.new(remote_id, json_connection, class_name)
	@@proxy_objects[remote_id] = obj
	obj
  end
  
 # include RemotelyAccessibleInstance
end


  

# This class defines a proxy object that is to be used on the other side of the wire
# Use this object when you want to send an object over the wire, but you want to send the 
# internal data of the object.  
#
class ProxyObject
  PROXY_REFERENCE_STRING = 'ProxyReference'

  def initialize(remote_id, json_connection, class_name)
    @remote_id = remote_id
    @json_connection = json_connection
	@class_name = class_name
  end

  def to_json(*a)
    {PROXY_REFERENCE_STRING => @remote_id}.to_json(*a)
  end  
  
  def method_missing(method_name, *args)
	@json_connection.json_request(@remote_id, method_name, *args)
  end
  
  def ==(o)
	@json_connection.json_request(@remote_id, '==', o)
  end  

  def to_s
	"<ProxyObject originalClass=\"#{@class_name}\" remoteId=\"#{@remote_id}\" />"
	#@json_connection.json_request(@remote_id, 'color').to_s
  end  
  
end
 


class Class
  def to_json(*a)
    {'class_name' => 'Class',
     'name' => self.name}.to_json(*a)
  end

  def self.from_json(hash, json_connection)
    const_get(hash['name'])
  end
end


# A Connection that communicates to other JSONConnections through a socket
# This is used for both server and client side.
class JSONConnection
  attr_accessor :log
  
  def initialize(socket, log=nil)
    @sock = socket
    @currentRequestID = 0
    @requests = []
    @log = log
  end

  # Creates and returns the next request ID
  def nextID
    @currentRequestID += 1
    @currentRequestID
  end
  
  def parse(hash)
	get_real_object(hash)
  end
  
  # If the given object is a proxy object or Object reference,
  # This gets that proxy or reference, otherwise, it returns o
  def get_real_object(a)
    if a.is_a?(Hash) and a['class_name']
      @log.debug("Building object from json: #{a['class_name']}") if @log
      klass = Kernel.const_get(a['class_name'].to_sym)
      klass.from_json(a, self)
    elsif a.is_a?(Array)
      a.map{|o| get_real_object(o)}
    elsif a.is_a?(Hash) and a[ProxyObject::PROXY_REFERENCE_STRING]
	  obj = ObjectSpace._id2ref(a[ProxyObject::PROXY_REFERENCE_STRING].to_i)
	  return obj if obj.class.is_a?(RemotelyAccessible)
	  raise "Remote system is attempting to access a non-remotelyAccessible object"
    elsif a.is_a?(Hash)
      new_hash = {}
      new_hash.default = a.default
      a.keys.each{|key| 
        new_hash[get_real_object(key)] = get_real_object(a[key])
      }
      new_hash
    else
      a
    end
  end

  # Send a RPC call over the connection to the targeted remote object
  # [target_id] The id on the remote system of the intended object
  # [method] the method symbol to run
  # [args] the arguments to the rpc call (These are actual Ruby objects)
  def json_request(target_id, method, *args)
    req_id = nextID
    data = { 'method' => method.to_s,
            'params' => args,
            'target_object_id' => target_id, #The object id of the remote object
            'id' => req_id}.to_json
    @log.debug("Sending request #{req_id}: #{data}") if @log
    req = JSONRequest.new(req_id)
    @requests << req
    @sock.write(data)
    @sock.flush
    until req.has_response
			sleep(0.01)
    end
    #@log.debug("Returning response '#{req.response}'")
    response = req.response
    @requests.delete(req)
    return response
  end


  #This method listens for all incomming request and response messages
  def listen
    t = Thread.new{
			begin
				while should_listen
					msg = get_next_message
					if msg
						Thread.new {
							json_msg = JSON.parse(msg)
							if json_msg.has_key?('id') and json_msg.has_key?('method')
								handle_json_request(json_msg)
							else
								#We have a response
								#            @log.debug("Received response '#{msg}'")
								if json_msg.has_key?('error') and json_msg['error'] != nil
									parts = json_msg['error'].split('$$')
									if @log
										@log.error(parts[0])
										@log.error(parts[1..-1])
									end
									raise parts[0]
								else
									original_request = @requests.find{|req| 
										req.req_id.to_i == json_msg['id'].to_i
									}
									raise "Could not find matching request: #{json_msg['id']} in #{@requests}" unless original_request
									response = get_real_object(json_msg['result'])
									original_request.response = response
									original_request.has_response = true
								end
								
							end
						}.abort_on_exception = false
					end
				end
			rescue Interrupt, SystemExit
				raise $! #this is the only error that should break the thread
			rescue
				puts $!
				puts $!.backtrace.join("\n")
			end
    }
	t.abort_on_exception = false
  end

  def should_listen
    true
  end

  #Blocks and waits for the next json-rpc message in the buffer
  def get_next_message
    begin
      buffer = @sock.read(1)
      depth = 1
      while depth > 0
        buffer += @sock.read(1)
        depth -= 1 if buffer[-1..-1] == '}'
        depth += 1 if buffer[-1..-1] == '{'
      end    
    rescue
      if should_listen
        raise 'Connection closed'
      else
        return nil
      end
    end
    buffer
  end
  
  #Handle an incomming json request
  def handle_json_request(json_msg)
    @log.debug("Received request :#{json_msg}") if @log
    args = json_msg['params']
    error = nil
    response = nil
    begin
      target_id = json_msg['target_object_id']
      method = json_msg['method']

      #Iterate through all the json_args
      #If we have a reference to our object, get that object
      #If we have a reference to a proxy, try to get that proxy or create a new one.
      args.map!{|a| get_real_object(a) }
	  
      response = handle_ruby_request(target_id, method, *args)    
    rescue
      error = "#{$!}$$#{$!.backtrace.join('$$')}"
    end
    response_json = {'result' => response,
                     'error' => error,
                     'id' => json_msg['id'] }.to_json
    @log.debug('Sending response: '+response_json)
    @sock.write(response_json)
    @sock.flush
  end
  
  #Make an actual call to a real Ruby object on the local system.
  def handle_ruby_request(target_id, method, *args)
    #Find the real object
	target = ObjectSpace._id2ref(target_id.to_i)
	if (!target.class.is_a?(RemotelyAccessible))
		raise "Remote system is attempting to access a non-RemotelyAccessible object"
	end
	if (target.class.is_method_allowed(method))
		target.send(method, *args)
	else
		raise "Remote syste is attempting to run an inaccessible method: #{method}"
	end
  end
end

class ServerConnection < JSONConnection
  attr_reader :initial_object
  
  def send_initial_object(o)
    json_request(nil, 'set_initial_object', o)
    @initial_object = o
  end
end

class JSON_RPC_Server 
  attr_reader :initial_object
  attr_accessor :connectionClass
  
  include Socket::Constants

  #Create a JsonConnection with an initial object.
  #A Proxy object will be created 
  def initialize(admin, port, log=nil)
    @admin = admin
    @port = port
    @initial_object = admin
    @connections = []
    @server = nil
    unless log
      log_file = file = open('server.log', File::WRONLY | File::CREAT)
      log  = Logger.new(log_file)
    end
    @logger = log
    @is_serving = false
  end
  
  #When a new connection is established, this method creates a new JSON connection
  def create_new_connection(socket, log)
    ServerConnection.new(socket, log)
  end

  def ready?
    @server != nil
  end

  def is_game_done?
    @admin.is_game_done
  end

  def serve
    @is_serving = true
    begin
      @server = TCPServer.new(@port)
#      @server.setsockopt( Socket::SOL_SOCKET, Socket::SO_REUSEADDR, true)
#      @server.setsockopt( Socket::SOL_SOCKET, AI_PASSIVE, false)
    rescue Exception
      unless @server.nil?
        @server.close
      end

      puts $! 
      puts $!.backtrace.join("\n")
      return unless @is_serving
      retry
    end
    
    while @is_serving
			begin
				sock, client_sockaddr = @server.accept_nonblock
			rescue Interrupt, SystemExit
				exit(0);
			rescue Errno::EAGAIN, Errno::ECONNABORTED,  Errno::EINTR, Exception
				return if !@is_serving or @admin.is_game_in_progress ##Once the game is started, don't accept any more connections.
				#IO.select([@server])
				sleep(0.5)
				retry
			end
			STDOUT.flush
			begin
				connection = create_new_connection(sock, @logger)
				@connections << connection
				@logger.info("Accepted Connection to #{connection}")
				connection.listen
				connection.send_initial_object(@initial_object)
			rescue Interrupt, SystemExit
				exit(0)
			rescue Exception
				@logger.error($!)
				@logger.error($!.backtrace.join('\n'))
				puts $!
				#          puts $!.backtrace.join('\n')
				retry
			end
		end
  end


  def close
    @is_serving = false
    raise 'Server Socket is nil' if @server.nil?
    begin
      @server.close
    rescue Exception
      puts 'Exception while closing server'
      puts $!
      puts $!.backtrace.join('\n')
      #Stream already closed, don't do anything
    end
  end

end


class JSON_RPC_Client < JSONConnection
  attr_reader :initial_object
  
  def initialize(host, port, log=nil)
    @should_listen = true
    @sock = TCPSocket.new(host, port)
    super(@sock)
    initial_json_object = JSON.parse(get_next_message)
    @sock.write(nil_response(initial_json_object['id']))
    @sock.flush
    
    a = initial_json_object['params'][0]
    remote_id = a['remote_id']
    klass = Kernel.const_get(a['class_name'])
    @initial_object = klass.from_json(a, self)
    unless log
      log_file = File.open('client.log', File::WRONLY | File::CREAT)
      log = Logger.new(log_file)    
    end
    @log = log
    listen
  end

  def should_listen
    @should_listen
  end
  
  def nil_response(req_id)
    {'result' => nil,
     'error' => nil,
     'id' => req_id}.to_json
  end

  def close
    raise 'Socket is nil' if @sock.nil?
    begin
      @should_listen = false
      @sock.close
      until @sock.closed?
        sleep(1)
        puts 'waiting for the server to close'
      end
      puts 'closed player'
    rescue Exception
      puts $!
      puts $!.backtrace.join('\n')
      #Stream already closed, don't do anything
    end
  end
end



